--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Packets = require(Shared.Networking.Packets)
local CharacterController = require(Server.Entity.CharacterController)

Packets.ConsumeFood.OnServerEvent:Connect(function(Player: Player, HungerAmount: number)
	local Character = Player.Character
	if not Character then
		return
	end

	local Controller = CharacterController.Get(Character)
	if not Controller then
		warn("No controller found for", Player.Name)
		return
	end

	-- Check if player has HungerController
	if not Controller.HungerController then
		warn("No HungerController for", Player.Name)
		return
	end

	-- Feed the player
	Controller.HungerController:Feed(HungerAmount)

	print(Player.Name, "consumed food and restored", HungerAmount, "hunger")
end)
