--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatsModule = require(Shared.Configurations.Stats)
local StatesModule = require(Shared.Configurations.States)

local Stats = StatsModule.Stats

local PASSIVE_HUNGER_DRAIN_RATE = 0.05
local PASSIVE_HUNGER_DRAIN_INTERVAL = 1
local STAMINA_TO_HUNGER_RATIO = 0.065

local HUNGER_CRITICAL_THRESHOLD = 20
local HUNGER_FULL_THRESHOLD = 73

local MUSCLE_LOSS_RATE = 0.25
local MUSCLE_LOSS_INTERVAL = 1.5

local FAT_GAIN_RATE = 0.015
local FAT_GAIN_INTERVAL = 0.75

local FAT_LOSS_RATE = 0.05
local FAT_LOSS_INTERVAL = 0.75

export type HungerController = {
	Controller: any,
	LastHungerDrain: number,
	LastMuscleLoss: number,
	LastFatGain: number,
	LastFatLoss: number,

	Feed: (self: HungerController, Amount: number) -> (),
	GetHungerPercent: (self: HungerController) -> number,
	IsStarving: (self: HungerController) -> boolean,
	IsFull: (self: HungerController) -> boolean,
	GetStatGainMultiplier: (self: HungerController) -> number,
	ConsumeHungerForStamina: (self: HungerController, StaminaUsed: number) -> (),
	Destroy: (self: HungerController) -> (),
}

local HungerController = {}
HungerController.__index = HungerController

function HungerController.new(CharacterController: any): HungerController
	local self = setmetatable({
		Controller = CharacterController,
		LastHungerDrain = tick(),
		LastMuscleLoss = tick(),
		LastFatGain = tick(),
		LastFatLoss = tick(),
	}, HungerController)

	local Character = CharacterController.Character

	Character:SetAttribute("HungerThreshold", (100 - HUNGER_FULL_THRESHOLD) / 100)

	if Character then
		local MaxHunger = CharacterController.StateManager:GetStat(Stats.MAX_HUNGER)
		Character:SetAttribute(Stats.HUNGER, MaxHunger)
		Character:SetAttribute(Stats.MAX_HUNGER, MaxHunger)
	end

	local HungerConnection = RunService.Heartbeat:Connect(function()
		local CurrentTime = tick()
		local StateManager = self.Controller.StateManager

		if CurrentTime - self.LastHungerDrain >= PASSIVE_HUNGER_DRAIN_INTERVAL then
			local CurrentHunger = StateManager:GetStat(Stats.HUNGER)
			local NewHunger = math.max(0, CurrentHunger - PASSIVE_HUNGER_DRAIN_RATE)

			StateManager:SetStat(Stats.HUNGER, NewHunger)

			if Character then
				Character:SetAttribute(Stats.HUNGER, NewHunger)
			end

			self.LastHungerDrain = CurrentTime
		end

		if self:IsStarving() and CurrentTime - self.LastMuscleLoss >= MUSCLE_LOSS_INTERVAL then
			local CurrentMuscle = StateManager:GetStat(Stats.MUSCLE)

			if CurrentMuscle > 0 then
				local NewMuscle = math.max(0, CurrentMuscle - MUSCLE_LOSS_RATE)
				StateManager:SetStat(Stats.MUSCLE, NewMuscle)
				self.LastMuscleLoss = CurrentTime
			end

			StateManager:FireEvent(StatesModule.Events.HUNGER_CRITICAL, {})
		end

		if self:IsFull() and CurrentTime - self.LastFatGain >= FAT_GAIN_INTERVAL then
			local CurrentFat = StateManager:GetStat(Stats.FAT) or 0
			local Multiplier = self:GetFatGainMultiplier()
			local NewFat = CurrentFat + FAT_GAIN_RATE * Multiplier

			StateManager:SetStat(Stats.FAT, NewFat)
			self.LastFatGain = CurrentTime
		end

		local HungerPercent = self:GetHungerPercent()
		if HungerPercent < HUNGER_FULL_THRESHOLD and CurrentTime - self.LastFatLoss >= FAT_LOSS_INTERVAL then
			local CurrentFat = StateManager:GetStat(Stats.FAT) or 0
			local LossMultiplier = self:GetFatLossMultiplier(HungerPercent)

			local NewFat = math.max(0, CurrentFat - FAT_LOSS_RATE * LossMultiplier)
			StateManager:SetStat(Stats.FAT, NewFat)

			self.LastFatLoss = CurrentTime
		end
	end)

	CharacterController.Maid:Set("HungerUpdate", HungerConnection)

	return (self :: any) :: HungerController
end

function HungerController:GetFatGainMultiplier()
	local HungerPercent = self:GetHungerPercent()

	if HungerPercent < HUNGER_FULL_THRESHOLD then
		return 0
	end

	local MinHungerPercent = HUNGER_FULL_THRESHOLD
	local MaxHungerPercent = 100

	return math.clamp((HungerPercent - MinHungerPercent) / (MaxHungerPercent - MinHungerPercent), 0, 1)
end

function HungerController:GetFatLossMultiplier(HungerPercent: number)
	if HungerPercent >= HUNGER_FULL_THRESHOLD then
		return 0
	end

	local DeficitScale = 1 - (HungerPercent / HUNGER_FULL_THRESHOLD)

	local StarvationBoost = 1
	if HungerPercent < HUNGER_CRITICAL_THRESHOLD then
		StarvationBoost = 1 + (1.5 * (1 - HungerPercent / HUNGER_CRITICAL_THRESHOLD))
	end

	return DeficitScale * StarvationBoost
end

function HungerController:Feed(Amount: number)
	local StateManager = self.Controller.StateManager
	local Character = self.Controller.Character

	local CurrentHunger = StateManager:GetStat(Stats.HUNGER)
	local MaxHunger = StateManager:GetStat(Stats.MAX_HUNGER)
	if CurrentHunger >= MaxHunger then
		return
	end
	local NewHunger = math.min(MaxHunger, CurrentHunger + Amount)

	StateManager:SetStat(Stats.HUNGER, NewHunger)

	if Character then
		Character:SetAttribute(Stats.HUNGER, NewHunger)
	end
end

function HungerController:GetHungerPercent(): number
	local StateManager = self.Controller.StateManager
	local CurrentHunger = StateManager:GetStat(Stats.HUNGER)
	local MaxHunger = StateManager:GetStat(Stats.MAX_HUNGER)

	if not CurrentHunger or not MaxHunger then
		return 0
	end

	return (CurrentHunger / MaxHunger) * 100
end

function HungerController:ConsumeHungerForStamina(StaminaUsed: number)
	local StateManager = self.Controller.StateManager
	local Character = self.Controller.Character

	local HungerCost = StaminaUsed * STAMINA_TO_HUNGER_RATIO
	local CurrentHunger = StateManager:GetStat(Stats.HUNGER)
	local NewHunger = math.max(0, CurrentHunger - HungerCost)

	StateManager:SetStat(Stats.HUNGER, NewHunger)

	if Character then
		Character:SetAttribute(Stats.HUNGER, NewHunger)
	end
end

function HungerController:IsStarving(): boolean
	return self:GetHungerPercent() < HUNGER_CRITICAL_THRESHOLD
end

function HungerController:IsFull(): boolean
	return self:GetHungerPercent() >= HUNGER_FULL_THRESHOLD
end

function HungerController:GetStatGainMultiplier(): number
	local HungerPercent = self:GetHungerPercent()

	if HungerPercent >= 5 then
		return 1.0
	else
		return 0.25
	end
end

function HungerController:Destroy()
	self.Controller.Maid:Set("HungerUpdate", nil)

	for Key in pairs(self) do
		self[Key] = nil
	end

	setmetatable(self, nil)
end

return HungerController