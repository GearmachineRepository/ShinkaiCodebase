--!strict

local Stats = {
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

local MAX_STARS = 10
local TOTAL_STAR_CAP = 15
local POST_CAP_MULTIPLIER = 0.1

local TrainableStats = {
	Stats.MAX_STAMINA,
	Stats.DURABILITY,
	Stats.RUN_SPEED,
	Stats.STRIKING_POWER,
	Stats.STRIKE_SPEED,
	Stats.MUSCLE,
}

local StatCaps = {
	[Stats.MAX_STAMINA] = {Min = 75, Max = 225},
	[Stats.DURABILITY] = {Min = 0, Max = 100},
	[Stats.RUN_SPEED] = {Min = 28, Max = 35},
	[Stats.STRIKING_POWER] = {Min = 0, Max = 100},
	[Stats.STRIKE_SPEED] = {Min = 0, Max = 100},
	[Stats.MUSCLE] = {Min = 0, Max = 100},
}

local Defaults = {
	[Stats.HEALTH] = 100,
	[Stats.MAX_HEALTH] = 100,
	[Stats.POSTURE] = 0,
	[Stats.MAX_POSTURE] = 100,
	[Stats.STAMINA] = 75,
	[Stats.MAX_STAMINA] = 75,
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
	[Stats.DURABILITY] = 0,
	[Stats.RUN_SPEED] = 28,
	[Stats.STRIKING_POWER] = 0,
	[Stats.STRIKE_SPEED] = 0,
}

local function GetStarRating(StatName: string, StatValue: number): number
	local Cap = StatCaps[StatName]
	if not Cap then
		return 0
	end

	local Range = Cap.Max - Cap.Min
	if Range <= 0 then
		return 0
	end

	-- 0..1 progress between Min and Max
	local progress01 = math.clamp(StatValue - Cap.Min, 0, Range) / Range

	-- Scale to 0..MAX_STARS and floor
	local starsExact = progress01 * MAX_STARS
	local stars = math.floor(starsExact + 1e-6) -- tiny epsilon

	return math.clamp(stars, 0, MAX_STARS)
end

local function GetStarProgress(StatName: string, StatValue: number): number
	local Cap = StatCaps[StatName]
	if not Cap then
		return 1 -- treat as fully dim
	end

	local Range = Cap.Max - Cap.Min
	if Range <= 0 then
		return 1
	end

	-- 0..1 progress across the whole stat range
	local progress01 = math.clamp(StatValue - Cap.Min, 0, Range) / Range

	-- Exact star position (e.g. 4.3 = 4 full stars + 30% into 5th)
	local starsExact = progress01 * MAX_STARS
	local fullStars = math.floor(starsExact)

	if fullStars >= MAX_STARS then
		-- already at max stars; no "next star" to charge
		return 0
	end

	-- Fraction filled toward the NEXT star: 0..1
	local fracFilled = starsExact - fullStars

	-- You want: 1 at start (dim) → 0 at end (lit)
	local fracRemaining = 1 - fracFilled

	return fracRemaining
end

local function CalculateTotalStars(StatsTable: {[string]: number}): number
	local TotalStars = 0

	for _, StatName in TrainableStats do
		local StatValue = StatsTable[StatName] or 0
		TotalStars += GetStarRating(StatName, StatValue)
	end

	return TotalStars
end

local function IsTrainableStat(StatName: string): boolean
	for _, TrainableStat in TrainableStats do
		if TrainableStat == StatName then
			return true
		end
	end
	return false
end

local function GetStatCap(StatName: string): number?
	local Cap = StatCaps[StatName]
	if Cap then
		return Cap.Max
	end
	return nil
end

local function GetStatMin(StatName: string): number?
	local Cap = StatCaps[StatName]
	if Cap then
		return Cap.Min
	end
	return nil
end

return {
	Stats = Stats,
	Defaults = Defaults,
	TrainableStats = TrainableStats,
	StatCaps = StatCaps,
	MAX_STARS = MAX_STARS,
	TOTAL_STAR_CAP = TOTAL_STAR_CAP,
	POST_CAP_MULTIPLIER = POST_CAP_MULTIPLIER,
	GetStarRating = GetStarRating,
	GetStarProgress = GetStarProgress,
	CalculateTotalStars = CalculateTotalStars,
	IsTrainableStat = IsTrainableStat,
	GetStatCap = GetStatCap,
	GetStatMin = GetStatMin,
}