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

local SOFT_CAP_THRESHOLD = 20
local HARD_CAP_THRESHOLD = 35
local POST_CAP_MULTIPLIER = 0.25
local MAX_STARS_DISPLAYED = 5

local MUSCLE_PENALTY_PER_POINT = 0.02
local STARVATION_MUSCLE_PENALTY = 0.5
local MUSCLE_OVERTRAIN_THRESHOLD = 200
local STRIKING_POWER_PENALTY_PER_POINT = 0.01

local TrainableStats = {
	Stats.MAX_STAMINA,
	Stats.DURABILITY,
	Stats.RUN_SPEED,
	Stats.STRIKING_POWER,
	Stats.STRIKE_SPEED,
	Stats.MUSCLE,
}

local StatBases = {
	[Stats.MAX_STAMINA] = 75,
	[Stats.DURABILITY] = 0,
	[Stats.RUN_SPEED] = 28,
	[Stats.STRIKING_POWER] = 0,
	[Stats.STRIKE_SPEED] = 0,
	[Stats.MUSCLE] = 0,
}

local StatXPCaps = {
	[Stats.MAX_STAMINA] = 150,
	[Stats.DURABILITY] = 100,
	[Stats.RUN_SPEED] = 7,
	[Stats.STRIKING_POWER] = 100,
	[Stats.STRIKE_SPEED] = 100,
	[Stats.MUSCLE] = 100,
}

local StarBonuses = {
	[Stats.MAX_STAMINA] = 15,
	[Stats.DURABILITY] = 10,
	[Stats.RUN_SPEED] = 0.142857,
	[Stats.STRIKING_POWER] = 10,
	[Stats.STRIKE_SPEED] = 10,
	[Stats.MUSCLE] = 10,
}

local StarTiers = {
	{Min = 0, Max = 4, Name = "Copper", Color = Color3.fromRGB(167, 108, 49)},
	{Min = 5, Max = 9, Name = "Silver", Color = Color3.fromRGB(192, 192, 192)},
	{Min = 10, Max = 14, Name = "Gold", Color = Color3.fromRGB(224, 198, 79)},
	{Min = 15, Max = 19, Name = "Platinum", Color = Color3.fromRGB(113, 153, 172)},
	{Min = 20, Max = 24, Name = "Emerald", Color = Color3.fromRGB(80, 200, 120)},
	{Min = 25, Max = 29, Name = "Diamond", Color = Color3.fromRGB(116, 245, 250)},
	{Min = 30, Max = math.huge, Name = "Champion", Color = Color3.fromRGB(207, 63, 171)},
}

local Defaults = {
	[Stats.HEALTH] = 100,
	[Stats.MAX_HEALTH] = 100,
	[Stats.POSTURE] = 0,
	[Stats.MAX_POSTURE] = 100,
	[Stats.STAMINA] = 75,
	[Stats.MAX_STAMINA] = 0,
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
	[Stats.RUN_SPEED] = 0,
	[Stats.STRIKING_POWER] = 0,
	[Stats.STRIKE_SPEED] = 0,
}

local function GetStarTierForIndex(StarIndex: number): {Min: number, Max: number, Name: string, Color: Color3}
	for _, Tier in StarTiers do
		if StarIndex >= Tier.Min and StarIndex <= Tier.Max then
			return Tier
		end
	end
	return StarTiers[1]
end

local function GetXPThresholdForPoint(StatName: string, PointNumber: number): number
	local XPCap = StatXPCaps[StatName]
	if not XPCap then
		return 0
	end

	local BaseXPPerPoint = XPCap / 5
	return BaseXPPerPoint * PointNumber
end

local function GetAvailablePointsFromXP(StatName: string, XPValue: number, AllocatedStars: number): number
	local XPCap = StatXPCaps[StatName]
	if not XPCap then
		return 0
	end

	local BaseXPPerPoint = XPCap / 5
	local TotalPointsEarned = math.floor(XPValue / BaseXPPerPoint)
	local AvailablePoints = TotalPointsEarned - AllocatedStars

	return math.max(0, AvailablePoints)
end

local function GetXPProgressToNextPoint(StatName: string, XPValue: number, AllocatedStars: number): number
	local XPCap = StatXPCaps[StatName]
	if not XPCap then
		return 1
	end

	local BaseXPPerPoint = XPCap / 5
	local TotalPointsEarned = math.floor(XPValue / BaseXPPerPoint)

	if TotalPointsEarned > AllocatedStars then
		return 1
	end

	local NextPointThreshold = GetXPThresholdForPoint(StatName, TotalPointsEarned + 1)
	local CurrentPointThreshold = GetXPThresholdForPoint(StatName, TotalPointsEarned)
	local Range = NextPointThreshold - CurrentPointThreshold

	if Range <= 0 then
		return 1
	end

	local Progress = (XPValue - CurrentPointThreshold) / Range
	return math.clamp(Progress, 0, 1)
end

local function GetStatValueFromStars(StatName: string, Stars: number): number
	local Base = StatBases[StatName] or 0
	local BonusPerStar = StarBonuses[StatName] or 0

	return Base + (BonusPerStar * Stars)
end

local function GetMusclePenaltyMultiplier(_: number, IsStarving: boolean): number
	local Multiplier = 1.0

	if IsStarving then
		Multiplier = Multiplier * STARVATION_MUSCLE_PENALTY
	end

	return Multiplier
end

local function GetStatPenaltyFromMuscle(StatName: string, MuscleValue: number): number
	if StatName == Stats.RUN_SPEED or StatName == Stats.STRIKE_SPEED then
		local Penalty = 1.0 - (MuscleValue * MUSCLE_PENALTY_PER_POINT)
		return math.max(0.1, Penalty)
	elseif StatName == Stats.STRIKING_POWER then
		if MuscleValue > MUSCLE_OVERTRAIN_THRESHOLD then
			local ExcessMuscle = MuscleValue - MUSCLE_OVERTRAIN_THRESHOLD
			local Penalty = 1.0 - (ExcessMuscle * STRIKING_POWER_PENALTY_PER_POINT)
			return math.max(0.1, Penalty)
		end
		return 1.0
	end

	return 1.0
end

local function GetStatValueFromStarsWithPenalties(StatName: string, Stars: number, MuscleValue: number, IsStarving: boolean): number
	local Base = StatBases[StatName] or 0
	local BonusPerStar = StarBonuses[StatName] or 0
	local StarValue = BonusPerStar * Stars

	if StatName == Stats.MUSCLE then
		local MusclePenalty = GetMusclePenaltyMultiplier(MuscleValue, IsStarving)
		StarValue = StarValue * MusclePenalty
	elseif StatName == Stats.RUN_SPEED or StatName == Stats.STRIKE_SPEED or StatName == Stats.STRIKING_POWER then
		local MusclePenalty = GetStatPenaltyFromMuscle(StatName, MuscleValue)
		StarValue = StarValue * MusclePenalty
	end

	return Base + StarValue
end

local function CalculateTotalAllocatedStars(StarsTable: {[string]: number}): number
	local TotalStars = 0

	for _, StatName in TrainableStats do
		local Stars = StarsTable[StatName] or 0
		TotalStars += Stars
	end

	return TotalStars
end

local function GetDiminishingReturnsMultiplier(TotalAllocatedStars: number): number
	if TotalAllocatedStars < SOFT_CAP_THRESHOLD then
		return 1.0
	end

	return POST_CAP_MULTIPLIER
end

local function CanAllocateStatPoint(_: string, CurrentStars: number, _: number): boolean
	if CurrentStars >= HARD_CAP_THRESHOLD then
		return false
	end

	return true
end

local function IsTrainableStat(StatName: string): boolean
	for _, TrainableStat in TrainableStats do
		if TrainableStat == StatName then
			return true
		end
	end
	return false
end

local function GetXPCap(StatName: string): number?
	return StatXPCaps[StatName]
end

local function GetStatBase(StatName: string): number?
	return StatBases[StatName]
end

return {
	Stats = Stats,
	Defaults = Defaults,
	TrainableStats = TrainableStats,
	StatBases = StatBases,
	StatXPCaps = StatXPCaps,
	StarBonuses = StarBonuses,
	StarTiers = StarTiers,
	SOFT_CAP_THRESHOLD = SOFT_CAP_THRESHOLD,
	HARD_CAP_THRESHOLD = HARD_CAP_THRESHOLD,
	POST_CAP_MULTIPLIER = POST_CAP_MULTIPLIER,
	MAX_STARS_DISPLAYED = MAX_STARS_DISPLAYED,
	MUSCLE_PENALTY_PER_POINT = MUSCLE_PENALTY_PER_POINT,
	STARVATION_MUSCLE_PENALTY = STARVATION_MUSCLE_PENALTY,
	MUSCLE_OVERTRAIN_THRESHOLD = MUSCLE_OVERTRAIN_THRESHOLD,
	STRIKING_POWER_PENALTY_PER_POINT = STRIKING_POWER_PENALTY_PER_POINT,
	GetStarTierForIndex = GetStarTierForIndex,
	GetXPThresholdForPoint = GetXPThresholdForPoint,
	GetAvailablePointsFromXP = GetAvailablePointsFromXP,
	GetXPProgressToNextPoint = GetXPProgressToNextPoint,
	GetStatValueFromStars = GetStatValueFromStars,
	GetStatValueFromStarsWithPenalties = GetStatValueFromStarsWithPenalties,
	GetMusclePenaltyMultiplier = GetMusclePenaltyMultiplier,
	GetStatPenaltyFromMuscle = GetStatPenaltyFromMuscle,
	CalculateTotalAllocatedStars = CalculateTotalAllocatedStars,
	GetDiminishingReturnsMultiplier = GetDiminishingReturnsMultiplier,
	CanAllocateStatPoint = CanAllocateStatPoint,
	IsTrainableStat = IsTrainableStat,
	GetXPCap = GetXPCap,
	GetStatBase = GetStatBase,
}