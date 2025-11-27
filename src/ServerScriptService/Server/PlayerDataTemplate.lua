--!strict
local StatsModule = require(game:GetService("ReplicatedStorage").Shared.Configurations.Stats)
local Stats = StatsModule.Stats
local Defaults = StatsModule.Defaults

return {
	Stats = {
		[Stats.BODY_FATIGUE] = Defaults[Stats.BODY_FATIGUE],
		[Stats.MAX_BODY_FATIGUE] = Defaults[Stats.MAX_BODY_FATIGUE],
		[Stats.MAX_HEALTH] = Defaults[Stats.MAX_HEALTH],
		[Stats.MAX_HUNGER] = Defaults[Stats.MAX_HUNGER],
		[Stats.HUNGER] = Defaults[Stats.HUNGER],
		[Stats.FAT] = Defaults[Stats.FAT],

		-- XP Values (raw training progress)
		[Stats.MAX_STAMINA .. "_XP"] = Defaults[Stats.MAX_STAMINA],
		[Stats.DURABILITY .. "_XP"] = Defaults[Stats.DURABILITY],
		[Stats.RUN_SPEED .. "_XP"] = Defaults[Stats.RUN_SPEED],
		[Stats.STRIKING_POWER .. "_XP"] = Defaults[Stats.STRIKING_POWER],
		[Stats.STRIKE_SPEED .. "_XP"] = Defaults[Stats.STRIKE_SPEED],
		[Stats.MUSCLE .. "_XP"] = Defaults[Stats.MUSCLE],

		-- Allocated Stars (player choices)
		[Stats.MAX_STAMINA .. "_Stars"] = 0,
		[Stats.DURABILITY .. "_Stars"] = 0,
		[Stats.RUN_SPEED .. "_Stars"] = 0,
		[Stats.STRIKING_POWER .. "_Stars"] = 0,
		[Stats.STRIKE_SPEED .. "_Stars"] = 0,
		[Stats.MUSCLE .. "_Stars"] = 0,

		-- Available Points (unallocated)
		[Stats.MAX_STAMINA .. "_AvailablePoints"] = 0,
		[Stats.DURABILITY .. "_AvailablePoints"] = 0,
		[Stats.RUN_SPEED .. "_AvailablePoints"] = 0,
		[Stats.STRIKING_POWER .. "_AvailablePoints"] = 0,
		[Stats.STRIKE_SPEED .. "_AvailablePoints"] = 0,
		[Stats.MUSCLE .. "_AvailablePoints"] = 0,
	},
	Backpack = {},
	Hotbar = {},
	Passives = {},
	Traits = {},
	Clan = {
		ClanName = "None",
		ClanRarity = 0,
	},
	Appearance = {
		Gender = "Male",
		HairColor = Color3.new(0, 0, 0),
		EyeColor = Color3.new(0, 0, 0),
		Face = "Default",
		Height = 1.0,
	},
	Skills = {},
	EquippedMode = "None",
}