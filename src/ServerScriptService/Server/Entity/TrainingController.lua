--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrainingConfigModule = require(Shared.Configurations.TrainingConfig)
local StatsModule = require(Shared.Configurations.Stats)

local DEFAULT_FATIGUE_PER_STAT_GAIN = 0.5

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

	StartTraining: (self: TrainingController, TrainingType: TrainingType) -> boolean,
	StopTraining: (self: TrainingController) -> (),
	ProcessTraining: (self: TrainingController, DeltaTime: number) -> (),
	GrantStatGain: (self: TrainingController, StatName: string, Amount: number, CustomFatigueRate: number?) -> (),
	CanTrain: (self: TrainingController) -> boolean,
	GetTrainingMultiplier: (self: TrainingController) -> number,
	GetTotalStars: (self: TrainingController) -> number,
	Destroy: (self: TrainingController) -> (),
}

function TrainingController.new(CharacterController: any): TrainingController
	local self = setmetatable({
		Controller = CharacterController,
		CurrentTraining = nil,
		TrainingStartTime = 0,
	}, TrainingController)

	local Character = self.Controller.Character
	if Character then
		for StatName, _ in pairs(StatsModule.Defaults) do
			if not StatsModule.IsTrainableStat(StatName) then
				continue
			end

			local Value = self.Controller.StateManager:GetStat(StatName) or 0

			local Stars = StatsModule.GetStarRating(StatName, Value)
			Character:SetAttribute(StatName .. "_Stars", Stars)
			local Progress = StatsModule.GetStarProgress(StatName, Value)
			Character:SetAttribute(StatName .. "_Progress", Progress)
		end
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
	local Gain = Config.BaseExpGain * DeltaTime * Multiplier

	self:GrantStatGain(Config.StatName, Gain)
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

	if not BodyFatigueController:CanGainStats() then
		return
	end

	local HungerMultiplier = 1
	if HungerController then
		HungerMultiplier = HungerController:GetStatGainMultiplier()
	end

	local FinalGain = Amount * HungerMultiplier

	local TotalStars = self:GetTotalStars()

	if TotalStars >= StatsModule.TOTAL_STAR_CAP then
		FinalGain *= StatsModule.POST_CAP_MULTIPLIER
	end

	local CurrentStat = StateManager:GetStat(StatName) or 0
	local StatCap = StatsModule.GetStatCap(StatName)

	if not StatCap then
		warn("No cap defined for stat:", StatName)
		return
	end

	if CurrentStat >= StatCap then
		return
	end

	local NewStat = math.min(StatCap, CurrentStat + FinalGain)

	StateManager:SetStat(StatName, NewStat)

	local FatigueRate = CustomFatigueRate or DEFAULT_FATIGUE_PER_STAT_GAIN
	if self.CurrentTraining and TRAINING_CONFIGS[self.CurrentTraining] then
		FatigueRate = TRAINING_CONFIGS[self.CurrentTraining].FatigueGain
	end

	local FatigueGain = FatigueRate * FinalGain
	BodyFatigueController:AddFatigueFromStatGain(FatigueGain)

	local Character = self.Controller.Character
	if Character then
		Character:SetAttribute(StatName, NewStat)
		local Stars = StatsModule.GetStarRating(StatName, NewStat)
		Character:SetAttribute(StatName .. "_Stars", Stars)
		local Progress = StatsModule.GetStarProgress(StatName, NewStat)
		Character:SetAttribute(StatName .. "_Progress", Progress)
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

	local HungerController = self.Controller.HungerController
	if HungerController then
		Multiplier *= HungerController:GetStatGainMultiplier()
	end

	return Multiplier
end

function TrainingController:GetTotalStars(): number
	local StateManager = self.Controller.StateManager
	local StatsTable = {}

	for _, StatName in StatsModule.TrainableStats do
		StatsTable[StatName] = StateManager:GetStat(StatName) or 0
	end

	return StatsModule.CalculateTotalStars(StatsTable)
end

function TrainingController:Destroy()
	self:StopTraining()

	for Key in pairs(self) do
		self[Key] = nil
	end

	setmetatable(self, nil)
end

return TrainingController