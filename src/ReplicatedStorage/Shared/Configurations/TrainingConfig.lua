local Shared = game:GetService("ReplicatedStorage").Shared
local StatsModule = require(Shared.Configurations.Stats)
local Stats = StatsModule.Stats

local BASE_FATIGUE_PER_STAT_GAIN = 0.5

return {
	Running = {
		StatName = Stats.RUN_SPEED,
		BaseExpGain = 0.045,
		FatigueGain = BASE_FATIGUE_PER_STAT_GAIN * 0.7,
		RequiredMovement = true,
	},
	Jogging = {
		StatName = Stats.MAX_STAMINA,
		BaseExpGain = 15,
		FatigueGain = BASE_FATIGUE_PER_STAT_GAIN * 0.8,
		RequiredMovement = true,
	},
	WeightTraining = {
		StatName = Stats.MUSCLE,
		BaseExpGain = 0.25,
		FatigueGain = BASE_FATIGUE_PER_STAT_GAIN * 1.5,
		RequiredMovement = false,
	},
	Combat = {
		StatName = Stats.STRIKING_POWER,
		BaseExpGain = 1.0,
		FatigueGain = BASE_FATIGUE_PER_STAT_GAIN * 1.2,
		RequiredMovement = false,
	},
	Conditioning = {
		StatName = Stats.DURABILITY,
		BaseExpGain = 0.9,
		FatigueGain = BASE_FATIGUE_PER_STAT_GAIN,
		RequiredMovement = false,
	},
}