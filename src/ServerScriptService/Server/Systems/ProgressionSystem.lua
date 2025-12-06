--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local TrainingBalance = require(Shared.Configurations.Balance.TrainingBalance)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local StatSystem = require(script.Parent.StatSystem)

local ProgressionSystem = {}

function ProgressionSystem.CanTrain(PlayerData: any): (boolean, string?)
	local CurrentFatigue = PlayerData.Stats[StatTypes.BODY_FATIGUE] or 0
	local MaxFatigue = PlayerData.Stats[StatTypes.MAX_BODY_FATIGUE] or 100

	local FatiguePercent = (CurrentFatigue / MaxFatigue) * 100

	if FatiguePercent >= TrainingBalance.FatigueSystem.TRAINING_LOCKOUT_PERCENT then
		return false, "Too fatigued to train. Rest at an apothecary or hospital."
	end

	return true
end

function ProgressionSystem.AwardTrainingXP(
	PlayerData: any,
	StatType: string,
	BaseXP: number,
	IsPremium: boolean?
): number
	local CanTrainResult, ErrorMessage = ProgressionSystem.CanTrain(PlayerData)
	if not CanTrainResult then
		warn(ErrorMessage)
		return 0
	end

	local XPMultiplier = TrainingBalance.XPRates.BASE_RATE

	if IsPremium then
		XPMultiplier *= TrainingBalance.XPRates.PREMIUM_MULTIPLIER
	end

	if StatSystem.IsAboveSoftCap(PlayerData) then
		XPMultiplier *= TrainingBalance.XPRates.AFTER_SOFT_CAP_MULTIPLIER
	end

	local FinalXP = BaseXP * XPMultiplier

	PlayerData.Stats[StatType .. "_XP"] = (PlayerData.Stats[StatType .. "_XP"] or 0) + FinalXP

	local FatigueGain = FinalXP * TrainingBalance.FatigueSystem.XP_TO_FATIGUE_RATIO
	PlayerData.Stats[StatTypes.BODY_FATIGUE] = (PlayerData.Stats[StatTypes.BODY_FATIGUE] or 0) + FatigueGain

	StatSystem.UpdateAvailablePoints(PlayerData, StatType)

	return FinalXP
end

function ProgressionSystem.RestoreFatigue(PlayerData: any)
	PlayerData.Stats[StatTypes.BODY_FATIGUE] = 0
end

function ProgressionSystem.ProcessHunger(PlayerData: any, DeltaTime: number)
	local CurrentHunger = PlayerData.Stats[StatTypes.HUNGER] or 0
	local CurrentMuscle = PlayerData.Stats[StatTypes.MUSCLE] or 0

	if CurrentHunger < TrainingBalance.HungerSystem.MUSCLE_LOSS_THRESHOLD then
		local MuscleLoss = TrainingBalance.HungerSystem.MUSCLE_LOSS_RATE_PER_SECOND * DeltaTime
		PlayerData.Stats[StatTypes.MUSCLE] = math.max(0, CurrentMuscle - MuscleLoss)
	end
end

function ProgressionSystem.ConsumeFood(PlayerData: any, HungerRestoreAmount: number)
	local CurrentHunger = PlayerData.Stats[StatTypes.HUNGER] or 0
	local MaxHunger = PlayerData.Stats[StatTypes.MAX_HUNGER] or TrainingBalance.HungerSystem.MAX_HUNGER

	PlayerData.Stats[StatTypes.HUNGER] = math.min(MaxHunger, CurrentHunger + HungerRestoreAmount)
end

function ProgressionSystem.ProcessMuscleTraining(PlayerData: any, MuscleXP: number): boolean
	local CurrentFat = PlayerData.Stats[StatTypes.FAT] or 0

	if CurrentFat <= 0 then
		return false
	end

	local FatRequired = MuscleXP * TrainingBalance.HungerSystem.FAT_TO_MUSCLE_CONVERSION

	if CurrentFat < FatRequired then
		return false
	end

	PlayerData.Stats[StatTypes.FAT] = CurrentFat - FatRequired

	return true
end

return ProgressionSystem