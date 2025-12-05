--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local CharacterController = require(Server.Entity.CharacterController)

export type InteractableModule = {
	OnInteract: (Player: Player, BedModel: Model) -> (),
	OnStopInteract: (Player: Player, BedModel: Model) -> ()
}

local BedInteractable = {} :: InteractableModule

local ActiveSleepers: {[Player]: RBXScriptConnection} = {}

local function ExitBed(PlayerWhoSlept: Player, BedModel: Model)
	if not ActiveSleepers[PlayerWhoSlept] then
		return
	end

	local Character = PlayerWhoSlept.Character
	if Character then
		local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
		if HumanoidRootPart then
			local Weld = HumanoidRootPart:FindFirstChild("BedWeld")
			if Weld then
				Weld:Destroy()
			end
		end

		Character:SetAttribute("Sleeping", false)
	end

	local Controller = CharacterController.Get(Character)
	if Controller and Controller.BodyFatigueController then
		Controller.BodyFatigueController.LastSweatTime = tick()
	end

	if ActiveSleepers[PlayerWhoSlept] then
		ActiveSleepers[PlayerWhoSlept]:Disconnect()
		ActiveSleepers[PlayerWhoSlept] = nil
	end

	BedModel:SetAttribute("ActiveFor", nil)
end

function BedInteractable.OnInteract(Player: Player, BedModel: Model)
	local Character = Player.Character
	if not Character then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then
		return
	end

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart then
		return
	end

	local Controller = CharacterController.Get(Character)
	if not Controller or not Controller.BodyFatigueController then
		warn("No BodyFatigueController found for", Player.Name)
		return
	end

	local BodyFatigueController = Controller.BodyFatigueController
	local CurrentFatigue = BodyFatigueController:GetFatiguePercent()

	if CurrentFatigue <= 5 then
		warn(Player.Name, "has no fatigue to rest")
		return
	end

	if ActiveSleepers[Player] then
		warn(Player.Name, "is already sleeping")
		return
	end

	local CurrentSleeper = BedModel:GetAttribute("ActiveFor")
	if CurrentSleeper then
		warn("Bed is already occupied")
		return
	end

	local SleepLocation = BedModel:FindFirstChild("SleepLocation") :: BasePart
	if not SleepLocation then
		warn("No SleepLocation found in bed model")
		return
	end

	HumanoidRootPart.CFrame = SleepLocation.CFrame

	local BedWeld = Instance.new("WeldConstraint")
	BedWeld.Name = "BedWeld"
	BedWeld.Part0 = HumanoidRootPart
	BedWeld.Part1 = SleepLocation
	BedWeld.Parent = HumanoidRootPart

	Character:SetAttribute("Sleeping", true)

	local JumpConnection = Character:GetAttributeChangedSignal("Jumping"):Connect(function()
		local IsJumping = Character:GetAttribute("Jumping")
		if IsJumping then
			ExitBed(Player, BedModel)
		end
	end)

	ActiveSleepers[Player] = JumpConnection
	BedModel:SetAttribute("ActiveFor", Player.UserId)

	BodyFatigueController:ResetSweatTimer()
end

function BedInteractable.OnStopInteract(Player: Player, BedModel: Model)
	local CurrentSleeper = BedModel:GetAttribute("ActiveFor")
	if CurrentSleeper == Player.UserId then
		ExitBed(Player, BedModel)
	end
end

Players.PlayerRemoving:Connect(function(PlayerLeaving: Player)
	if ActiveSleepers[PlayerLeaving] then
		for _, BedModel in workspace:GetDescendants() do
			if BedModel:IsA("Model") and BedModel:GetAttribute("ActiveFor") == PlayerLeaving.UserId then
				ExitBed(PlayerLeaving, BedModel)
				break
			end
		end
	end
end)

return BedInteractable