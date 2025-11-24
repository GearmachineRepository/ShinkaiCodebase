--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets = require(ReplicatedStorage.Shared.Networking.Packets)

Packets.Footplanted.OnServerEvent:Connect(function(Player, MaterialName, Position)
	local Players = game.Players:GetPlayers()
	if #Players <= 1 then return end
	
	for _, OtherPlayer in ipairs(Players) do
		if OtherPlayer ~= Player then
			Packets.Footplanted:FireClient(OtherPlayer, MaterialName, Position, Player.UserId)
        end
    end
end)