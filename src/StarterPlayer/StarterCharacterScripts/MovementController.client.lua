local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")

local DOUBLE_TAP_TIME = 0.3
local WALK_SPEED = 9
local JOG_SPEED = 18
local SPRINT_SPEED = 28

local LastWPressTime = 0
local IsInSprintMode = false
local CurrentSprintType = "run"
local SavedSprintType = "run"

if not Humanoid:GetAttribute("MovementMode") then
	Humanoid:SetAttribute("MovementMode", "walk")
end

if not Humanoid:GetAttribute("PreferredSprintMode") then
	Humanoid:SetAttribute("PreferredSprintMode", "run")
else
	SavedSprintType = Humanoid:GetAttribute("PreferredSprintMode")
	CurrentSprintType = SavedSprintType
end

local function SetMovementMode(mode)
	if mode == "walk" then
		Humanoid.WalkSpeed = WALK_SPEED
		Humanoid:SetAttribute("MovementMode", "walk")
		IsInSprintMode = false
	elseif mode == "jog" then
		Humanoid.WalkSpeed = JOG_SPEED
		Humanoid:SetAttribute("MovementMode", "jog")
		IsInSprintMode = true
		CurrentSprintType = "jog"
		SavedSprintType = "jog"
		Humanoid:SetAttribute("PreferredSprintMode", "jog")
	elseif mode == "run" then
		Humanoid.WalkSpeed = SPRINT_SPEED
		Humanoid:SetAttribute("MovementMode", "run")
		IsInSprintMode = true
		CurrentSprintType = "run"
		SavedSprintType = "run"
		Humanoid:SetAttribute("PreferredSprintMode", "run")
	end
end

local function EnterSprintMode()
	if SavedSprintType == "jog" then
		SetMovementMode("jog")
	else
		SetMovementMode("run")
	end
end

local function ToggleSprintType()
	if not IsInSprintMode then
		return
	end

	if CurrentSprintType == "run" then
		SetMovementMode("jog")
	else
		SetMovementMode("run")
	end
end

local function OnInputBegan(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.W then
		local CurrentTime = tick()
		if CurrentTime - LastWPressTime <= DOUBLE_TAP_TIME then
			EnterSprintMode()
		end
		LastWPressTime = CurrentTime
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		EnterSprintMode()
	elseif input.KeyCode == Enum.KeyCode.R then
		ToggleSprintType()
	end
end

local function OnInputEnded(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end

	if (input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift) and IsInSprintMode then
		local WKeyPressed = UserInputService:IsKeyDown(Enum.KeyCode.W)
		local SKeyPressed = UserInputService:IsKeyDown(Enum.KeyCode.S)
		local AKeyPressed = UserInputService:IsKeyDown(Enum.KeyCode.A)
		local DKeyPressed = UserInputService:IsKeyDown(Enum.KeyCode.D)

		if not (WKeyPressed or SKeyPressed or AKeyPressed or DKeyPressed) then
			SetMovementMode("walk")
		end
	end
end

local function CheckMovementKeys()
	if not IsInSprintMode then
		return
	end

	local WKeyPressed = UserInputService:IsKeyDown(Enum.KeyCode.W)
	local SKeyPressed = UserInputService:IsKeyDown(Enum.KeyCode.S)
	local AKeyPressed = UserInputService:IsKeyDown(Enum.KeyCode.A)
	local DKeyPressed = UserInputService:IsKeyDown(Enum.KeyCode.D)
	local ShiftPressed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

	local AnyMovementKey = WKeyPressed or SKeyPressed or AKeyPressed or DKeyPressed

	if not AnyMovementKey and not ShiftPressed then
		SetMovementMode("walk")
	end
end

UserInputService.InputBegan:Connect(OnInputBegan)
UserInputService.InputEnded:Connect(OnInputEnded)

RunService.Heartbeat:Connect(function()
	if Humanoid.MoveDirection.Magnitude < 0.1 and IsInSprintMode then
		local ShiftPressed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		if not ShiftPressed then
			task.wait(0.1)
			if Humanoid.MoveDirection.Magnitude < 0.1 then
				SetMovementMode("walk")
			end
		end
	end
end)

Player.CharacterAdded:Connect(function(newCharacter)
	Character = newCharacter
	Humanoid = newCharacter:WaitForChild("Humanoid")

	if not Humanoid:GetAttribute("MovementMode") then
		Humanoid:SetAttribute("MovementMode", "walk")
	end

	if not Humanoid:GetAttribute("PreferredSprintMode") then
		Humanoid:SetAttribute("PreferredSprintMode", SavedSprintType)
	else
		SavedSprintType = Humanoid:GetAttribute("PreferredSprintMode")
		CurrentSprintType = SavedSprintType
	end

	SetMovementMode("walk")
end)

SetMovementMode("walk")