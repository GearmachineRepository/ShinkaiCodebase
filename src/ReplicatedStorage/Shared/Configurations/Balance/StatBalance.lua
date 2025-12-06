--!strict

local StatBalance = {
	Defaults = {
		Health = 100,
		MaxHealth = 100,
		Stamina = 75,
		MaxStamina = 75,
		Posture = 0,
		MaxPosture = 100,
		CarryWeight = 0,
		MaxCarryWeight = 100,
		Armor = 0,
		PhysicalResistance = 0,
		BodyFatigue = 0,
		MaxBodyFatigue = 100,
		Hunger = 45,
		MaxHunger = 75,
		Fat = 0,
		Muscle = 0,
		Durability = 0,
		RunSpeed = 0,
		StrikingPower = 0,
		StrikeSpeed = 0,
	},

	Caps = {
		SOFT_CAP_STARS = 20,
		PER_STAT_MAX_STARS = 5,
		POINTS_PER_STAR = 5,
	},

	StarBonuses = {
		MaxStamina = 15,
		Durability = 8,
		RunSpeed = 2,
		StrikingPower = 10,
		StrikeSpeed = 0.08,
		Muscle = 12,
	},

	XPThresholds = {
		MaxStamina = 1000,
		Durability = 1200,
		RunSpeed = 800,
		StrikingPower = 1500,
		StrikeSpeed = 1300,
		Muscle = 900,
	},

	XPCaps = {
		MaxStamina = 5000,
		Durability = 6000,
		RunSpeed = 4000,
		StrikingPower = 7500,
		StrikeSpeed = 6500,
		Muscle = 4500,
	},

	StarTiers = {
		{Min = 0, Max = 4, Name = "Bronze", Color = Color3.fromRGB(205, 127, 50)},
		{Min = 5, Max = 9, Name = "Silver", Color = Color3.fromRGB(192, 192, 192)},
		{Min = 10, Max = 14, Name = "Gold", Color = Color3.fromRGB(224, 198, 79)},
		{Min = 15, Max = 19, Name = "Platinum", Color = Color3.fromRGB(113, 153, 172)},
		{Min = 20, Max = 24, Name = "Emerald", Color = Color3.fromRGB(80, 200, 120)},
		{Min = 25, Max = 29, Name = "Diamond", Color = Color3.fromRGB(116, 245, 250)},
		{Min = 30, Max = math.huge, Name = "Champion", Color = Color3.fromRGB(207, 63, 171)},
	},
}

return StatBalance