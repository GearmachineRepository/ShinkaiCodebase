--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Shared.Networking.Packets)
local Maid = require(ReplicatedStorage.Shared.General.Maid)

local FootstepEngine = require(ReplicatedStorage.Shared.Footsteps.FootstepEngine)

local player = Players.LocalPlayer
local maid = Maid.new()

local function getMaterialName(character: Model)
	local mat = FootstepEngine.GetFloorMaterial(character)
	if mat == Enum.Material.Air then return nil end
	return mat.Name
end

local function setupCharacter(character: Model)
	maid:DoCleaning()

	local humanoid = character:WaitForChild("Humanoid", 5)
	local animator = humanoid:WaitForChild("Animator", 5) :: Animator

	-- LOCAL SOUND INIT
	FootstepEngine.InitializeCharacter(character)

	-- Animation detection
	local animConn = animator.AnimationPlayed:Connect(function(track)
		local markerConn = track:GetMarkerReachedSignal("Footplant"):Connect(function()

			local materialName = getMaterialName(character) :: string?
			if not materialName then return end

			-- Play sound locally
			FootstepEngine.PlayFootstep(character, materialName)

			-- Send to server
			local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart
			if hrp then
				local IsPlayer = game.Players:GetPlayerFromCharacter(character)
				local Id = if IsPlayer then IsPlayer.UserId else 0
				Packets.Footplanted:Fire(materialName, hrp.Position, Id)
			end
		end)

		maid:GiveTask(markerConn)
	end)

	maid:GiveTask(animConn)

	maid:GiveTask(character.Destroying:Connect(function()
		maid:DoCleaning()
	end))
end

Packets.Footplanted.OnClientEvent:Connect(function(materialName: string, position: Vector3, PlayerId: number)
	if not PlayerId then return end 
	if PlayerId == Players.LocalPlayer.UserId then
		return -- ignore our own footsteps
	end
	
	local IsPlayer = game.Players:GetPlayerByUserId(PlayerId) :: Player?
	local character = nil
	if IsPlayer then
		character = IsPlayer.Character
	end

	if not character then return end
	local hrp = character.PrimaryPart
	if not hrp then return end

	-- Ensure footsteps initialized
	FootstepEngine.InitializeCharacter(character)

	-- Play at the replicated character
	FootstepEngine.PlayFootstep(character, materialName)
end)


if player.Character then
	setupCharacter(player.Character)
end

player.CharacterAdded:Connect(setupCharacter)