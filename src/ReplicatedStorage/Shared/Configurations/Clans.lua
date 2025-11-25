--!strict

local Clans = {
	BROWN = "Brown",
	SMITH = "Smith",
	JONES = "Jones",
	MILLER = "Miller",
	CLARENCE = "Clarence",
	DONALDA = "Donalda",
	NICHOLAS = "Nicholas",
	SEBASTIAN = "Sebastian",
	TYSON = "Tyson",
	IMAI = "Imai",
	REINHOLD = "Reinhold",
	WONGSAWAT = "Wongsawat",
	KURE = "Kure",
	MIKAZUCHI = "Mikazuchi",
	GAOH = "Gaoh",
	OHMA = "Ohma",
	WU = "Wu",
}

local ClanData = {
	[Clans.BROWN] = {
		Name = "Brown",
		Rarity = 64,
		Passives = {},
		StatBonuses = {},
		UnlockedStyles = {},
		UnlockedMode = nil,
	},

	[Clans.SMITH] = {
		Name = "Smith",
		Rarity = 64,
		Passives = {},
		StatBonuses = {},
		UnlockedStyles = {},
		UnlockedMode = nil,
	},

	[Clans.JONES] = {
		Name = "Jones",
		Rarity = 64,
		Passives = {},
		StatBonuses = {},
		UnlockedStyles = {},
		UnlockedMode = nil,
	},

	[Clans.MILLER] = {
		Name = "Miller",
		Rarity = 64,
		Passives = {},
		StatBonuses = {},
		UnlockedStyles = {},
		UnlockedMode = nil,
	},

	[Clans.CLARENCE] = {
		Name = "Clarence",
		Rarity = 64,
		Passives = {},
		StatBonuses = {},
		UnlockedStyles = {},
		UnlockedMode = nil,
	},

	[Clans.DONALDA] = {
		Name = "Donalda",
		Rarity = 64,
		Passives = {},
		StatBonuses = {},
		UnlockedStyles = {},
		UnlockedMode = nil,
	},

	[Clans.NICHOLAS] = {
		Name = "Nicholas",
		Rarity = 64,
		Passives = {},
		StatBonuses = {},
		UnlockedStyles = {},
		UnlockedMode = nil,
	},

	[Clans.SEBASTIAN] = {
		Name = "Sebastian",
		Rarity = 64,
		Passives = {},
		StatBonuses = {},
		UnlockedStyles = {},
		UnlockedMode = nil,
	},

	[Clans.TYSON] = {
		Name = "Tyson",
		Rarity = 64,
		Passives = {},
		StatBonuses = {},
		UnlockedStyles = {},
		UnlockedMode = nil,
	},

	[Clans.IMAI] = {
		Name = "Imai",
		Rarity = 4,
		Passives = {},
		StatBonuses = {},
		UnlockedStyles = {},
		UnlockedMode = nil,
		Description = "Imai clan allows the player to learn Zōn.",
	},

	[Clans.REINHOLD] = {
		Name = "Reinhold",
		Rarity = 4,
		Passives = {"ReinHoldHeight"},
		StatBonuses = {
			Muscle = 20,
		},
		UnlockedStyles = {},
		UnlockedMode = nil,
		Description = "The reinhold clan gives the player an extra star worth of muscle, along with a slight height boost.",
	},

	[Clans.WONGSAWAT] = {
		Name = "Wongsawat",
		Rarity = 4,
		Passives = {"WongsawatMuayThaiBoost"},
		StatBonuses = {},
		UnlockedStyles = {"MuayThai"},
		UnlockedMode = nil,
		Description = "The wongsawat clan buffs Muay Thai's pure, giving it more damage. The player is also able to learn the skill God Glow.",
	},

	[Clans.KURE] = {
		Name = "Kure",
		Rarity = 1,
		Passives = {},
		StatBonuses = {},
		UnlockedStyles = {"Kure"},
		UnlockedMode = "Removal",
		RemovalStartPercent = 5,
		RemovalMaxPercent = 75,
		Description = "The kure clan utilizes Removal. Starting percentage is 5%, max for regular players is 75%. Gives access to the Kure style.",
	},

	[Clans.MIKAZUCHI] = {
		Name = "Mikazuchi",
		Rarity = 1,
		Passives = {"MikazuchiSpeed"},
		StatBonuses = {
			RunSpeed = 4,
		},
		UnlockedStyles = {"Raishin"},
		UnlockedMode = nil,
		Description = "The mikazuchi clan comes with a passive of extra 2% run speed and 1.5% passive speed increase on m1s. Gives access to the Raishin style.",
	},

	[Clans.GAOH] = {
		Name = "Gaoh",
		Rarity = 1,
		Passives = {},
		StatBonuses = {},
		UnlockedStyles = {"Gaoh"},
		UnlockedMode = nil,
		Description = "Gaoh clan gives access to the Gaoh style.",
	},

	[Clans.OHMA] = {
		Name = "Ohma",
		Rarity = 0.64,
		Passives = {},
		StatBonuses = {},
		UnlockedStyles = {"Niko"},
		UnlockedMode = "Advance",
		Description = "The Ohma clan gives the player access to the mode called Advance and the Niko style along with its skills.",
	},

	[Clans.WU] = {
		Name = "Wu",
		Rarity = 0.64,
		Passives = {},
		StatBonuses = {},
		UnlockedStyles = {"Kure", "Wu"},
		UnlockedMode = "Guihan",
		RemovalStartPercent = 5,
		RemovalMaxPercent = 100,
		Description = "The Wu clan gives access to the kure style and techniques along with extra wu-exclusive moves and the ability to unlock a higher cap of removal, otherwise called Guihan.",
	},
}

local function GetWeightedRandomClan(): string
	local TotalWeight = 0
	local WeightedClans = {}

	for ClanName, Data in ClanData do
		TotalWeight += Data.Rarity
		table.insert(WeightedClans, {
			Clan = ClanName,
			Weight = Data.Rarity,
		})
	end

	local Random = math.random() * TotalWeight
	local CurrentWeight = 0

	for _, Entry in WeightedClans do
		CurrentWeight += Entry.Weight
		if Random <= CurrentWeight then
			return Entry.Clan
		end
	end

	return Clans.BROWN
end

local function GetClanData(ClanName: string)
	return ClanData[ClanName]
end

return {
	Clans = Clans,
	ClanData = ClanData,
	GetWeightedRandomClan = GetWeightedRandomClan,
	GetClanData = GetClanData,
}