--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local Maid = require(Shared.General.Maid)

local HUNGER_DECAY_RATE = 0.1
local STAMINA_TO_HUNGER_RATIO = 0.05
local HUNGER_CRITICAL_THRESHOLD = 20
local STAT_GAIN_THRESHOLD = 30
local STAT_GAIN_MULTIPLIER_NORMAL = 1.0
local STAT_GAIN_MULTIPLIER_STARVING = 0.5

local HungerController = {}
HungerController.__index = HungerController

export type HungerController = typeof(setmetatable({} :: {
	Controller: any,
	LastUpdate: number,
	Maid: Maid.MaidSelf,
}, HungerController))

function HungerController.new(CharacterController: any): HungerController
	local self = setmetatable({
		Controller = CharacterController,
		LastUpdate = tick(),
		Maid = Maid.new(),
	}, HungerController)

	return self
end

function HungerController:Update()
	local Now = tick()
	local DeltaTime = Now - self.LastUpdate
	self.LastUpdate = Now

	if DeltaTime > 5 then
		return
	end

	local CurrentHunger = self.Controller.StatManager:GetStat(StatTypes.HUNGER)
	local NewHunger = math.max(0, CurrentHunger - (HUNGER_DECAY_RATE * DeltaTime))

	self.Controller.StatManager:SetStat(StatTypes.HUNGER, NewHunger)

	if NewHunger < HUNGER_CRITICAL_THRESHOLD then
		self.Controller.StateManager:FireEvent("HungerCritical", {HungerPercent = self:GetHungerPercent()})
	end
end

function HungerController:ConsumeFood(Amount: number)
	local CurrentHunger = self.Controller.StatManager:GetStat(StatTypes.HUNGER)
	local MaxHunger = self.Controller.StatManager:GetStat(StatTypes.MAX_HUNGER)
	local NewHunger = math.min(MaxHunger, CurrentHunger + Amount)

	self.Controller.StatManager:SetStat(StatTypes.HUNGER, NewHunger)
end

function HungerController:GetHungerPercent(): number
	local CurrentHunger = self.Controller.StatManager:GetStat(StatTypes.HUNGER)
	local MaxHunger = self.Controller.StatManager:GetStat(StatTypes.MAX_HUNGER)

	if MaxHunger == 0 then
		return 0
	end

	return (CurrentHunger / MaxHunger) * 100
end

function HungerController:ConsumeHungerForStamina(StaminaUsed: number)
	local HungerCost = StaminaUsed * STAMINA_TO_HUNGER_RATIO
	local CurrentHunger = self.Controller.StatManager:GetStat(StatTypes.HUNGER)
	local NewHunger = math.max(0, CurrentHunger - HungerCost)

	self.Controller.StatManager:SetStat(StatTypes.HUNGER, NewHunger)
end

function HungerController:IsStarving(): boolean
	return self:GetHungerPercent() < HUNGER_CRITICAL_THRESHOLD
end

function HungerController:GetStatGainMultiplier(): number
	local HungerPercent = self:GetHungerPercent()

	if HungerPercent >= STAT_GAIN_THRESHOLD then
		return STAT_GAIN_MULTIPLIER_NORMAL
	else
		return STAT_GAIN_MULTIPLIER_STARVING
	end
end

function HungerController:Destroy()
	self.Maid:DoCleaning()
end

return HungerController