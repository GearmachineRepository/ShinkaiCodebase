--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local MovementConfig = require(Shared.Configurations.MovementConfig)

type PlayerData = {
	LastSprintStartTime: number,
}

local PlayerData: {[Player]: PlayerData} = {}

local function InitializePlayerData(Player: Player)
	if not PlayerData[Player] then
		PlayerData[Player] = {
			LastSprintStartTime = 0,
		}
	end
end

local function OnSprintStart(Player: Player)
	InitializePlayerData(Player)
	PlayerData[Player].LastSprintStartTime = tick()
end

local function GetStaminaMultiplier(Player: Player): number
	if not PlayerData[Player] then
		return 1.0
	end

	local TimeSinceSprintStart = tick() - PlayerData[Player].LastSprintStartTime

	if TimeSinceSprintStart < MovementConfig.StutterStep.ReductionWindow then
		return MovementConfig.StutterStep.StaminaReduction
	end

	return 1.0
end

game:GetService("Players").PlayerRemoving:Connect(function(Player)
	PlayerData[Player] = nil
end)

return {
	GetStaminaMultiplier = GetStaminaMultiplier,
	OnSprintStart = OnSprintStart,
}