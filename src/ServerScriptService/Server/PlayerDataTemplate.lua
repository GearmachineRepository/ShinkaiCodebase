--!strict
local StatsModule = require(game:GetService("ReplicatedStorage").Shared.Configurations.Stats)
local Stats = StatsModule.Stats
local Defaults = StatsModule.Defaults

return {
	Stats = {
		[Stats.BODY_FATIGUE] = Defaults[Stats.BODY_FATIGUE],
		[Stats.MAX_BODY_FATIGUE] = Defaults[Stats.MAX_BODY_FATIGUE],
		[Stats.MAX_STAMINA] = Defaults[Stats.MAX_STAMINA],
		[Stats.MAX_HEALTH] = Defaults[Stats.MAX_HEALTH],
		[Stats.MAX_HUNGER] = Defaults[Stats.MAX_HUNGER],
		[Stats.DURABILITY] = Defaults[Stats.DURABILITY],
		[Stats.RUN_SPEED] = Defaults[Stats.RUN_SPEED],
		[Stats.STRIKING_POWER] = Defaults[Stats.STRIKING_POWER],
		[Stats.STRIKE_SPEED] = Defaults[Stats.STRIKE_SPEED],
		[Stats.MUSCLE] = Defaults[Stats.MUSCLE],
		[Stats.HUNGER] = Defaults[Stats.HUNGER],
		[Stats.FAT] = Defaults[Stats.FAT],
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