--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatsModule = require(Shared.Configurations.Stats)
local StatesModule = require(Shared.Configurations.States)
local HungerConfig = require(Shared.Configurations.HungerConfig)

local Stats = StatsModule.Stats

export type HungerController = {
	Controller: any,
	LastHungerDrain: number,
	LastFatGain: number,
	LastFatLoss: number,

	Update: (self: HungerController) -> (),
	Feed: (self: HungerController, Amount: number) -> (),
	GetHungerPercent: (self: HungerController) -> number,
	IsStarving: (self: HungerController) -> boolean,
	IsFull: (self: HungerController) -> boolean,
	GetStatGainMultiplier: (self: HungerController) -> number,
	GetFatGainMultiplier: (self: HungerController) -> number,
	GetFatLossMultiplier: (self: HungerController, HungerPercent: number) -> number,
	ConsumeHungerForStamina: (self: HungerController, StaminaUsed: number) -> (),
	Destroy: (self: HungerController) -> (),
}

local HungerController = {}
HungerController.__index = HungerController

function HungerController.new(CharacterController: any): HungerController
	local self = setmetatable({
		Controller = CharacterController,
		LastHungerDrain = tick(),
		LastFatGain = tick(),
		LastFatLoss = tick(),
	}, HungerController)

	local Character = CharacterController.Character

	Character:SetAttribute("HungerThreshold", (100 - HungerConfig.HUNGER_FULL_THRESHOLD) / 100)

	if Character then
		local MaxHunger = CharacterController.StateManager:GetStat(Stats.MAX_HUNGER)
		Character:SetAttribute(Stats.HUNGER, MaxHunger)
		Character:SetAttribute(Stats.MAX_HUNGER, MaxHunger)
	end

	return (self :: any) :: HungerController
end

function HungerController:Update()
	local CurrentTime = tick()
	local StateManager = self.Controller.StateManager
	local Character = self.Controller.Character

	if CurrentTime - self.LastHungerDrain >= HungerConfig.PASSIVE_HUNGER_DRAIN_INTERVAL then
		local CurrentHunger = StateManager:GetStat(Stats.HUNGER)
		local NewHunger = math.max(0, CurrentHunger - HungerConfig.PASSIVE_HUNGER_DRAIN_RATE)

		StateManager:SetStat(Stats.HUNGER, NewHunger)

		if Character then
			Character:SetAttribute(Stats.HUNGER, NewHunger)
		end

		self.LastHungerDrain = CurrentTime
	end

	if self:IsStarving() then
		StateManager:FireEvent(StatesModule.Events.HUNGER_CRITICAL, {})
	end

	if self:IsFull() and CurrentTime - self.LastFatGain >= HungerConfig.FAT_GAIN_INTERVAL then
		local CurrentFat = StateManager:GetStat(Stats.FAT) or 0

		if CurrentFat >= HungerConfig.FAT_HARD_CAP then
			return
		end

		local Multiplier = self:GetFatGainMultiplier()
		local NewFat = math.min(HungerConfig.FAT_HARD_CAP, CurrentFat + HungerConfig.FAT_GAIN_RATE * Multiplier)

		StateManager:SetStat(Stats.FAT, NewFat)
		self.LastFatGain = CurrentTime
	end

	local HungerPercent = self:GetHungerPercent()
	if HungerPercent < HungerConfig.HUNGER_FULL_THRESHOLD and CurrentTime - self.LastFatLoss >= HungerConfig.FAT_LOSS_INTERVAL then
		local CurrentFat = StateManager:GetStat(Stats.FAT) or 0
		local LossMultiplier = self:GetFatLossMultiplier(HungerPercent)

		local NewFat = math.max(0, CurrentFat - HungerConfig.FAT_LOSS_RATE * LossMultiplier)
		StateManager:SetStat(Stats.FAT, NewFat)

		self.LastFatLoss = CurrentTime
	end
end

function HungerController:GetFatGainMultiplier(): number
	local HungerPercent = self:GetHungerPercent()

	if HungerPercent < HungerConfig.HUNGER_FULL_THRESHOLD then
		return 0
	end

	local MinHungerPercent = HungerConfig.HUNGER_FULL_THRESHOLD
	local MaxHungerPercent = 100

	return math.clamp((HungerPercent - MinHungerPercent) / (MaxHungerPercent - MinHungerPercent), 0, 1)
end

function HungerController:GetFatLossMultiplier(HungerPercent: number): number
	if HungerPercent >= HungerConfig.HUNGER_FULL_THRESHOLD then
		return 0
	end

	local DeficitScale = 1 - (HungerPercent / HungerConfig.HUNGER_FULL_THRESHOLD)

	local StarvationBoost = 1
	if HungerPercent < HungerConfig.HUNGER_CRITICAL_THRESHOLD then
		StarvationBoost = 1 + (1.5 * (1 - HungerPercent / HungerConfig.HUNGER_CRITICAL_THRESHOLD))
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

	local HungerCost = StaminaUsed * HungerConfig.STAMINA_TO_HUNGER_RATIO
	local CurrentHunger = StateManager:GetStat(Stats.HUNGER)
	local NewHunger = math.max(0, CurrentHunger - HungerCost)

	StateManager:SetStat(Stats.HUNGER, NewHunger)

	if Character then
		Character:SetAttribute(Stats.HUNGER, NewHunger)
	end
end

function HungerController:IsStarving(): boolean
	return self:GetHungerPercent() < HungerConfig.HUNGER_CRITICAL_THRESHOLD
end

function HungerController:IsFull(): boolean
	return self:GetHungerPercent() >= HungerConfig.HUNGER_FULL_THRESHOLD
end

function HungerController:GetStatGainMultiplier(): number
	local HungerPercent = self:GetHungerPercent()

	if HungerPercent >= HungerConfig.STAT_GAIN_THRESHOLD then
		return HungerConfig.STAT_GAIN_MULTIPLIER_NORMAL
	else
		return HungerConfig.STAT_GAIN_MULTIPLIER_STARVING
	end
end

function HungerController:Destroy()
	for Key in pairs(self) do
		self[Key] = nil
	end

	setmetatable(self, nil)
end

return HungerController