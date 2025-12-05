--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)
local StatsModule = require(Shared.Configurations.Stats)

local CharacterController = require(script.Parent.Server.Entity.CharacterController)

local function HandleAllocateStatPoint(Player: Player, StatName: string)
	if not StatsModule.IsTrainableStat(StatName) then
		warn("Player attempted to allocate invalid stat:", Player.Name, StatName)
		return
	end

	local Character = Player.Character
	if not Character then
		warn("Player has no character:", Player.Name)
		return
	end

	local Controller = CharacterController.Get(Character)
	if not Controller then
		warn("Player character has no controller:", Player.Name)
		return
	end

	local TrainingController = Controller.TrainingController
	if not TrainingController then
		warn("Player has no training controller:", Player.Name)
		return
	end

	local Success = TrainingController:AllocateStatPoint(StatName)
	if not Success then
		warn("Player failed to allocate stat point:", Player.Name, StatName)
	end
end

Packets.AllocateStatPoint.OnServerEvent:Connect(HandleAllocateStatPoint)