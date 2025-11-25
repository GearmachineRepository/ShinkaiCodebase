--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrainingConfigModule = require(Shared.Configurations.TrainingConfig)
local StatsModule = require(Shared.Configurations.Stats)
local Stats = StatsModule.Stats

local BASE_FATIGUE_PER_STAT_GAIN = 0.5

export type TrainingType = "Running" | "Jogging" | "WeightTraining" | "Combat" | "Conditioning"

export type TrainingConfig = {
	StatName: string,
	BaseExpGain: number,
	FatigueGain: number,
	RequiredMovement: boolean?,
	RequiredStamina: number?,
}

local TRAINING_CONFIGS: {[TrainingType]: TrainingConfig} = TrainingConfigModule

local TrainingController = {}
TrainingController.__index = TrainingController

export type TrainingController = {
	Controller: any,
	CurrentTraining: TrainingType?,
	TrainingStartTime: number,
	TotalExpGained: {[string]: number},

	StartTraining: (self: TrainingController, TrainingType: TrainingType) -> boolean,
	StopTraining: (self: TrainingController) -> (),
	ProcessTraining: (self: TrainingController, DeltaTime: number) -> (),
	GrantStatExp: (self: TrainingController, StatName: string, ExpAmount: number) -> (),
	CanTrain: (self: TrainingController) -> boolean,
	GetTrainingMultiplier: (self: TrainingController) -> number,
	Destroy: (self: TrainingController) -> (),
}

function TrainingController.new(CharacterController: any, DataTable: any?): TrainingController
    local StatsTable = DataTable and DataTable.Stats or {}

	local self = setmetatable({
		Controller = CharacterController,
		CurrentTraining = nil,
        StatsTable = StatsTable,
		TrainingStartTime = 0,
		TotalExpGained = {},
	}, TrainingController)

	for _, StatName in pairs(Stats) do
		self.TotalExpGained[StatName] = StatsTable[StatName] or 0
	end

	return (self :: any) :: TrainingController
end

function TrainingController:StartTraining(TrainingType: TrainingType): boolean
	if not self:CanTrain() then
		return false
	end

	if self.CurrentTraining then
		self:StopTraining()
	end

	self.CurrentTraining = TrainingType
	self.TrainingStartTime = tick()

	local Character = self.Controller.Character
	if Character then
		Character:SetAttribute("Training", TrainingType)
	end

	return true
end

function TrainingController:StopTraining()
	self.CurrentTraining = nil
	self.TrainingStartTime = 0

	local Character = self.Controller.Character
	if Character then
		Character:SetAttribute("Training", nil)
	end
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
	local ExpGain = Config.BaseExpGain * DeltaTime * Multiplier

	self:GrantStatExp(Config.StatName, ExpGain)
end

function TrainingController:GrantStatExp(StatName: string, ExpAmount: number)
	if ExpAmount <= 0 then
		return
	end

	local StateManager = self.Controller.StateManager
	local BodyFatigueController = self.Controller.BodyFatigueController
	local HungerController = self.Controller.HungerController

	if not BodyFatigueController:CanGainStats() then
		return
	end

	local HungerMultiplier = 1
	if HungerController then
		HungerMultiplier = HungerController:GetStatGainMultiplier()
	end

	local FinalExpGain = ExpAmount * HungerMultiplier

	local CurrentStat = StateManager:GetStat(StatName) or 0
	local NewStat = CurrentStat + FinalExpGain

	local TotalStars = StatsModule.CalculateTotalStars({
		[Stats.DURABILITY] = StateManager:GetStat(Stats.DURABILITY) or 0,
		[Stats.RUN_SPEED] = StateManager:GetStat(Stats.RUN_SPEED) or 0,
		[Stats.STRIKING_POWER] = StateManager:GetStat(Stats.STRIKING_POWER) or 0,
		[Stats.STRIKE_SPEED] = StateManager:GetStat(Stats.STRIKE_SPEED) or 0,
		[Stats.MUSCLE] = StateManager:GetStat(Stats.MUSCLE) or 0,
	})

	local SlowdownMultiplier = 1
	if TotalStars >= StatsModule.TOTAL_STAR_CAP then
		SlowdownMultiplier = 0.1
	end

	NewStat = CurrentStat + (FinalExpGain * SlowdownMultiplier)

	StateManager:SetStat(StatName, NewStat)

	local FatigueGain = BASE_FATIGUE_PER_STAT_GAIN * FinalExpGain * SlowdownMultiplier
	BodyFatigueController:AddFatigueFromStatGain(FatigueGain)

	self.TotalExpGained[StatName] = (self.TotalExpGained[StatName] or 0) + FinalExpGain

	local Character = self.Controller.Character
	if Character then
		Character:SetAttribute(StatName, NewStat)
	end
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

	local BodyFatigueController = self.Controller.BodyFatigueController
	if BodyFatigueController then
		local FatiguePercent = BodyFatigueController:GetFatiguePercent()

		if FatiguePercent >= 65 then
			Multiplier = 1.0
		end
	end

	local HungerController = self.Controller.HungerController
	if HungerController then
		Multiplier *= HungerController:GetStatGainMultiplier()
	end

	return Multiplier
end

function TrainingController:Destroy()
	self:StopTraining()

	for Key in pairs(self) do
		self[Key] = nil
	end

	setmetatable(self, nil)
end

return TrainingController