--!strict

local Stats = {
	STRENGTH = "Strength",
	AGILITY = "Agility",
	VITALITY = "Vitality",
	FAITH = "Faith",
	HERESY = "Heresy",
	INTELLIGENCE = "Intelligence",
	RESOLVE = "Resolve",

	PIETY = "Piety",
	PRIDE = "Pride",
	SUPERSTITION = "Superstition",
	DESPAIR = "Despair",
	AMBITION = "Ambition",
	ROT = "Rot",

	HEALTH = "Health",
	MAX_HEALTH = "MaxHealth",
	POSTURE = "Posture",
	MAX_POSTURE = "MaxPosture",
	STAMINA = "Stamina",
	MAX_STAMINA = "MaxStamina",
	CARRY_WEIGHT = "CarryWeight",
	MAX_CARRY_WEIGHT = "MaxCarryWeight",
	ARMOR = "Armor",
	PHYSICAL_RESISTANCE = "PhysicalResistance",

	BODY_FATIGUE = "BodyFatigue",
	MAX_BODY_FATIGUE = "MaxBodyFatigue",

	HUNGER = "Hunger",
	MAX_HUNGER = "MaxHunger",
	MUSCLE = "Muscle",
	FAT = "Fat",
	DURABILITY = "Durability",
	RUN_SPEED = "RunSpeed",
	STRIKING_POWER = "StrikingPower",
	STRIKE_SPEED = "StrikeSpeed",
}

local MAX_STAR_VALUE = 5
local TOTAL_STAR_CAP = 15

local Defaults = {
	[Stats.STRENGTH] = 10,
	[Stats.AGILITY] = 10,
	[Stats.VITALITY] = 10,
	[Stats.FAITH] = 0,
	[Stats.HERESY] = 0,
	[Stats.INTELLIGENCE] = 10,
	[Stats.RESOLVE] = 10,

	[Stats.PIETY] = 0,
	[Stats.PRIDE] = 0,
	[Stats.SUPERSTITION] = 0,
	[Stats.DESPAIR] = 0,
	[Stats.AMBITION] = 0,
	[Stats.ROT] = 0,

	[Stats.HEALTH] = 100,
	[Stats.MAX_HEALTH] = 100,
	[Stats.POSTURE] = 0,
	[Stats.MAX_POSTURE] = 100,
	[Stats.STAMINA] = 100,
	[Stats.MAX_STAMINA] = 100,
	[Stats.CARRY_WEIGHT] = 0,
	[Stats.MAX_CARRY_WEIGHT] = 100,
	[Stats.ARMOR] = 0,
	[Stats.PHYSICAL_RESISTANCE] = 0,

	[Stats.BODY_FATIGUE] = 0,
	[Stats.MAX_BODY_FATIGUE] = 100,

	[Stats.HUNGER] = 45,
	[Stats.MAX_HUNGER] = 75,
	[Stats.MUSCLE] = 0,
	[Stats.FAT] = 0,
	[Stats.DURABILITY] = 1,
	[Stats.RUN_SPEED] = 1,
	[Stats.STRIKING_POWER] = 1,
	[Stats.STRIKE_SPEED] = 1,
}

local StarRatings = {
	[0] = {Min = 0, Max = 0},
	[1] = {Min = 1, Max = 20},
	[2] = {Min = 21, Max = 40},
	[3] = {Min = 41, Max = 60},
	[4] = {Min = 61, Max = 80},
	[5] = {Min = 81, Max = 100},
}

local function GetStarRating(StatValue: number): number
	for Star = MAX_STAR_VALUE, 0, -1 do
		local Range = StarRatings[Star]
		if StatValue >= Range.Min then
			return Star
		end
	end
	return 0
end

local function CalculateTotalStars(StatsTable: {[string]: number}): number
	local TotalStars = 0

	local TrainableStats = {
		Stats.DURABILITY,
		Stats.RUN_SPEED,
		Stats.STRIKING_POWER,
		Stats.STRIKE_SPEED,
		Stats.MUSCLE,
	}

	for _, StatName in TrainableStats do
		local StatValue = StatsTable[StatName] or 0
		TotalStars += GetStarRating(StatValue)
	end

	return TotalStars
end

return {
	Stats = Stats,
	Defaults = Defaults,
	MAX_STAR_VALUE = MAX_STAR_VALUE,
	TOTAL_STAR_CAP = TOTAL_STAR_CAP,
	StarRatings = StarRatings,
	GetStarRating = GetStarRating,
	CalculateTotalStars = CalculateTotalStars,
}