--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatsModule = require(Shared.Configurations.Stats)

local DEFAULT_FATIGUE_PER_STAT_GAIN = 0.5

local TRAINING_CONFIGS = require(Shared.Configurations.TrainingConfig)

export type TrainingController = {
	Controller: any,
	CurrentTraining: string?,
	IsTraining: boolean,

	StartTraining: (self: TrainingController, TrainingType: string) -> (),
	StopTraining: (self: TrainingController) -> (),
	ProcessTraining: (self: TrainingController, DeltaTime: number) -> (),
	GrantStatGain: (self: TrainingController, StatName: string, Amount: number, CustomFatigueRate: number?) -> (),
	AllocateStatPoint: (self: TrainingController, StatName: string) -> boolean,
	CanTrain: (self: TrainingController) -> boolean,
	GetTrainingMultiplier: (self: TrainingController) -> number,
	GetTotalAllocatedStars: (self: TrainingController) -> number,
	UpdateAvailablePoints: (self: TrainingController, StatName: string) -> (),
	Destroy: (self: TrainingController) -> (),
}

local TrainingController = {}
TrainingController.__index = TrainingController

function TrainingController.new(CharacterController: any): TrainingController
	local self = setmetatable({
		Controller = CharacterController,
		CurrentTraining = nil,
		IsTraining = false,
	}, TrainingController)

	local Character = self.Controller.Character
	if Character then
		for _, StatName in StatsModule.TrainableStats do
			local XPValue = self.Controller.StateManager:GetStat(StatName .. "_XP") or 0
			local AllocatedStars = self.Controller.StateManager:GetStat(StatName .. "_Stars") or 0

			Character:SetAttribute(StatName .. "_XP", XPValue)
			Character:SetAttribute(StatName .. "_Stars", AllocatedStars)

			self:UpdateAvailablePoints(StatName)

			local StatValue = StatsModule.GetStatValueFromStars(StatName, AllocatedStars)
			Character:SetAttribute(StatName, StatValue)
			self.Controller.StateManager:SetStat(StatName, StatValue, true)
		end
	end

	return self
end

function TrainingController:StartTraining(TrainingType: string)
	if not TRAINING_CONFIGS[TrainingType] then
		warn("Invalid training type:", TrainingType)
		return
	end

	self.CurrentTraining = TrainingType
	self.IsTraining = true
end

function TrainingController:StopTraining()
	self.CurrentTraining = nil
	self.IsTraining = false
end

function TrainingController:ProcessTraining(DeltaTime: number)
	if not self.CurrentTraining then
		return
	end

	if not self:CanTrain() then
		self:StopTraining()
		return
	end

	local Config = TRAINING_CONFIGS[self.CurrentTraining]
	if not Config then
		return
	end

	local Multiplier = self:GetTrainingMultiplier()
	local Gain = Config.BaseExpGain * DeltaTime * Multiplier

	self:GrantStatGain(Config.StatName, Gain, Config.FatigueGain)
end

function TrainingController:UpdateAvailablePoints(StatName: string)
	local StateManager = self.Controller.StateManager
	local Character = self.Controller.Character

	local XPValue = StateManager:GetStat(StatName .. "_XP") or 0
	local AllocatedStars = StateManager:GetStat(StatName .. "_Stars") or 0

	local AvailablePoints = StatsModule.GetAvailablePointsFromXP(StatName, XPValue, AllocatedStars)
	local Progress = StatsModule.GetXPProgressToNextPoint(StatName, XPValue, AllocatedStars)

	StateManager:SetStat(StatName .. "_AvailablePoints", AvailablePoints)

	if Character then
		Character:SetAttribute(StatName .. "_AvailablePoints", AvailablePoints)
		Character:SetAttribute(StatName .. "_Progress", Progress)
	end
end

function TrainingController:GrantStatGain(StatName: string, Amount: number, CustomFatigueRate: number?)
	if Amount <= 0 then
		return
	end

	if not StatsModule.IsTrainableStat(StatName) then
		warn("Attempting to train non-trainable stat:", StatName)
		return
	end

	local StateManager = self.Controller.StateManager
	local BodyFatigueController = self.Controller.BodyFatigueController
	local HungerController = self.Controller.HungerController

	local HungerMultiplier = 1
	if HungerController then
		HungerMultiplier = HungerController:GetStatGainMultiplier()
	end

	local FatigueMultiplier = 1
	if BodyFatigueController then
		FatigueMultiplier = BodyFatigueController:GetStatGainMultiplier()
	end

	local TotalAllocatedStars = self:GetTotalAllocatedStars()
	local DiminishingMultiplier = StatsModule.GetDiminishingReturnsMultiplier(TotalAllocatedStars)

	local FinalGain = Amount * HungerMultiplier * FatigueMultiplier * DiminishingMultiplier

	local CurrentXP = StateManager:GetStat(StatName .. "_XP") or 0
	local NewXP = CurrentXP + FinalGain

	StateManager:SetStat(StatName .. "_XP", NewXP)

	local FatigueRate = CustomFatigueRate or DEFAULT_FATIGUE_PER_STAT_GAIN
	if self.CurrentTraining and TRAINING_CONFIGS[self.CurrentTraining] then
		FatigueRate = TRAINING_CONFIGS[self.CurrentTraining].FatigueGain
	end

	local FatigueGain = FatigueRate * FinalGain
	BodyFatigueController:AddFatigueFromStatGain(FatigueGain)

	local Character = self.Controller.Character
	if Character then
		Character:SetAttribute(StatName .. "_XP", NewXP)
	end

	self:UpdateAvailablePoints(StatName)
end

function TrainingController:AllocateStatPoint(StatName: string): boolean
	if not StatsModule.IsTrainableStat(StatName) then
		warn("Cannot allocate point to non-trainable stat:", StatName)
		return false
	end

	local StateManager = self.Controller.StateManager

	local AvailablePoints = StateManager:GetStat(StatName .. "_AvailablePoints") or 0
	if AvailablePoints <= 0 then
		warn("No available points for stat:", StatName)
		return false
	end

	local AllocatedStars = StateManager:GetStat(StatName .. "_Stars") or 0
	local TotalAllocatedStars = self:GetTotalAllocatedStars()

	if not StatsModule.CanAllocateStatPoint(StatName, AllocatedStars, TotalAllocatedStars) then
		warn("Cannot allocate stat point - cap reached")
		return false
	end

	local NewStars = AllocatedStars + 1
	StateManager:SetStat(StatName .. "_Stars", NewStars)

	local Character = self.Controller.Character
	if Character then
		Character:SetAttribute(StatName .. "_Stars", NewStars)

		local StatValue = StatsModule.GetStatValueFromStars(StatName, NewStars)
		Character:SetAttribute(StatName, StatValue)
	end

	self:UpdateAvailablePoints(StatName)

	return true
end

function TrainingController:CanTrain(): boolean
	local BodyFatigueController = self.Controller.BodyFatigueController

	if not BodyFatigueController then
		return true
	end

	return BodyFatigueController:CanGainStats()
end

function TrainingController:GetTrainingMultiplier(): number
	local Multiplier = 1.0

	local HungerController = self.Controller.HungerController
	if HungerController then
		Multiplier *= HungerController:GetStatGainMultiplier()
	end

	return Multiplier
end

function TrainingController:GetTotalAllocatedStars(): number
	local StateManager = self.Controller.StateManager
	local StarsTable = {}

	for _, StatName in StatsModule.TrainableStats do
		StarsTable[StatName] = StateManager:GetStat(StatName .. "_Stars") or 0
	end

	return StatsModule.CalculateTotalAllocatedStars(StarsTable)
end

function TrainingController:Destroy()
	self:StopTraining()

	for Key in pairs(self) do
		self[Key] = nil
	end

	setmetatable(self, nil)
end

return TrainingController