--!strict

local TrainingBalance = {
	FatigueSystem = {
		MAX_FATIGUE = 100,
		TRAINING_LOCKOUT_PERCENT = 65,
		XP_TO_FATIGUE_RATIO = 0.1,
		RECOVERY_LOCATIONS = {"Apothecary", "Hospital"},
	},

	XPRates = {
		BASE_RATE = 1.0,
		AFTER_SOFT_CAP_MULTIPLIER = 0.2,
		PREMIUM_MULTIPLIER = 1.05,
	},

	HungerSystem = {
		MAX_HUNGER = 75,
		STARTING_HUNGER = 45,
		MUSCLE_LOSS_THRESHOLD = 20,
		MUSCLE_LOSS_RATE_PER_SECOND = 0.1,
		FAT_TO_MUSCLE_CONVERSION = 1.0,
	},

	MuscleTraining = {
		REQUIRES_FAT = true,
		FAT_CONSUMPTION_RATIO = 1.0,
		AFFECTS_RUN_SPEED = true,
		AFFECTS_STRIKE_SPEED = true,
	},

	TrainingTypes = {
		Stamina = {
			ActivityName = "Running",
			BaseXPPerSecond = 10,
			StaminaDrain = 5,
			NonmachineMultiplier = 0.75,
		},
		Durability = {
			ActivityName = "Conditioning",
			BaseXPPerSecond = 8,
			StaminaDrain = 3,
		},
		RunSpeed = {
			ActivityName = "Sprinting",
			BaseXPPerSecond = 55,
			StaminaDrain = 7,
			NonmachineMultiplier = 0.5,
		},
		StrikingPower = {
			ActivityName = "Heavy Bag",
			BaseXPPerSecond = 9,
			StaminaDrain = 6,
		},
		StrikeSpeed = {
			ActivityName = "Speed Bag",
			BaseXPPerSecond = 11,
			StaminaDrain = 4,
		},
		Muscle = {
			ActivityName = "Weight Training",
			BaseXPPerSecond = 7,
			StaminaDrain = 8,
			RequiresFat = true,
		},
	},
}

return TrainingBalance