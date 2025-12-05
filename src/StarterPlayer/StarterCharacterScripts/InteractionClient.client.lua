--!strict
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Packets = require(ReplicatedStorage.Shared.Networking.Packets)

local INTERACTABLE_TAG = "Interactable"
local INTERACTION_DISTANCE = 10
local INPUT_KEY = Enum.KeyCode.E
local FADE_DURATION = 0.25

local Player = Players.LocalPlayer
local Character = script.Parent
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart") :: Part
local Head = Character:WaitForChild("Head") :: Part

local CurrentInteractable: Model? = nil
local CurrentHighlight: Highlight? = nil
local CurrentBillboard: BillboardGui? = nil
local ActiveTween: Tween? = nil
local ActiveTweenConnection: RBXScriptConnection? = nil

local RaycastParams = RaycastParams.new()
RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function UpdateRaycastFilter(InteractableObject: Model)
	local FilterList = {Character, InteractableObject}

	for _, TaggedCharacter in CollectionService:GetTagged("Character") do
		if TaggedCharacter ~= Character then
			table.insert(FilterList, TaggedCharacter)
		end
	end

	RaycastParams.FilterDescendantsInstances = FilterList
end

local function HasLineOfSight(InteractableObject: Model): boolean
	local PrimaryPart = InteractableObject.PrimaryPart
	if not PrimaryPart then
		return false
	end

	local Direction = (PrimaryPart.Position - Head.Position)
	local Distance = Direction.Magnitude
	Direction = Direction.Unit

	UpdateRaycastFilter(InteractableObject)

	local RaycastResult = workspace:Raycast(Head.Position, Direction * Distance, RaycastParams)

	return RaycastResult == nil
end

local function FadeHighlight(HighlightObject: Highlight, FadeIn: boolean)
	if ActiveTween then
		ActiveTween:Cancel()
	end

	if ActiveTweenConnection then
		ActiveTweenConnection:Disconnect()
		ActiveTweenConnection = nil
	end

	if FadeIn then
		HighlightObject.Enabled = true
	end

	local TargetFillTransparency = if FadeIn then 0.85 else 1
	local TargetOutlineTransparency = if FadeIn then 0 else 1

	local TweenInfo = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local Goal = {
		FillTransparency = TargetFillTransparency,
		OutlineTransparency = TargetOutlineTransparency
	}

	ActiveTween = TweenService:Create(HighlightObject, TweenInfo, Goal)
	ActiveTween:Play()

	if not FadeIn then
		ActiveTweenConnection = ActiveTween.Completed:Connect(function()
			if HighlightObject and HighlightObject.Parent then
				HighlightObject.Enabled = false
			end
		end)
	end
end

local function GetPromptText(InteractableObject: Model): string
	local IsActive = InteractableObject:GetAttribute("ActiveFor") == Player.UserId

	if IsActive then
		local StopPrompt = InteractableObject:GetAttribute("StopPrompt")
		return string.format("[E] - %s", StopPrompt or "Stop Interacting")
	else
		local ActionPrompt = InteractableObject:GetAttribute("ActionPrompt")
		return string.format("[E] - %s", ActionPrompt or "Interact")
	end
end

local function CreateHighlight(InteractableObject: Model): Highlight
	local ExistingHighlight = InteractableObject:FindFirstChildOfClass("Highlight")
	if ExistingHighlight then
		ExistingHighlight.Enabled = true
		ExistingHighlight.FillTransparency = 1
		ExistingHighlight.OutlineTransparency = 1
		FadeHighlight(ExistingHighlight, true)
		return ExistingHighlight
	end

	local NewHighlight = Instance.new("Highlight")
	NewHighlight.FillColor = Color3.fromRGB(255, 255, 255)
	NewHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	NewHighlight.FillTransparency = 1
	NewHighlight.OutlineTransparency = 1
	NewHighlight.Parent = InteractableObject

	FadeHighlight(NewHighlight, true)

	return NewHighlight
end

local function CreateBillboard(InteractableObject: Model): BillboardGui
	local Billboard = Instance.new("BillboardGui")
	Billboard.Name = "InteractionPrompt"
	Billboard.Size = UDim2.fromOffset(200, 30)
	Billboard.StudsOffset = Vector3.new(0, 3, 0)
	Billboard.AlwaysOnTop = true
	Billboard.Parent = InteractableObject

	local TextLabel = Instance.new("TextLabel")
	TextLabel.Name = "PromptText"
	TextLabel.Size = UDim2.fromScale(1, 1)
	TextLabel.BackgroundTransparency = 1
	TextLabel.Text = GetPromptText(InteractableObject)
	TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	TextLabel.TextStrokeTransparency = 0.25
	TextLabel.TextScaled = true
	TextLabel.Font = Enum.Font.SourceSansSemibold
	TextLabel.Parent = Billboard

	return Billboard
end

local function UpdateBillboardText()
	if CurrentBillboard and CurrentInteractable then
		local TextLabel = CurrentBillboard:FindFirstChild("PromptText") :: TextLabel
		if TextLabel then
			TextLabel.Text = GetPromptText(CurrentInteractable)
		end
	end
end

local function ClearCurrentInteraction()
	if CurrentHighlight then
		FadeHighlight(CurrentHighlight, false)
		CurrentHighlight = nil
	end

	if CurrentBillboard then
		CurrentBillboard:Destroy()
		CurrentBillboard = nil
	end

	CurrentInteractable = nil
end

local function GetClosestInteractable(): Model?
	local ClosestInteractable: Model? = nil
	local ClosestDistance = INTERACTION_DISTANCE

	for _, TaggedObject in CollectionService:GetTagged(INTERACTABLE_TAG) do
		if TaggedObject:IsA("Model") then
			local PrimaryPart = TaggedObject.PrimaryPart
			if PrimaryPart then
				local Distance = (HumanoidRootPart.Position - PrimaryPart.Position).Magnitude

				local IsActiveForPlayer = TaggedObject:GetAttribute("ActiveFor") == Player.UserId
				local MaxDistance = if IsActiveForPlayer then 15 else INTERACTION_DISTANCE

				if Distance < MaxDistance and Distance < ClosestDistance then
					if HasLineOfSight(TaggedObject) or IsActiveForPlayer then
						ClosestDistance = Distance
						ClosestInteractable = TaggedObject
					end
				end
			end
		end
	end

	return ClosestInteractable
end

local function UpdateInteraction()
	local ClosestInteractable = GetClosestInteractable()

	if ClosestInteractable ~= CurrentInteractable then
		ClearCurrentInteraction()

		if ClosestInteractable then
			local IsActiveForPlayer = ClosestInteractable:GetAttribute("ActiveFor") == Player.UserId

			CurrentInteractable = ClosestInteractable
			CurrentHighlight = CreateHighlight(ClosestInteractable)
			CurrentBillboard = CreateBillboard(ClosestInteractable)

			if IsActiveForPlayer then
				FadeHighlight(CurrentHighlight, false)
			end
		end
	else
		UpdateBillboardText()
	end
end

local function HandleInput(Input: InputObject, GameProcessed: boolean)
	if GameProcessed then
		return
	end

	if Input.KeyCode == INPUT_KEY and CurrentInteractable then
		local IsActive = CurrentInteractable:GetAttribute("ActiveFor") == Player.UserId
		Packets.InteractRequest:Fire(CurrentInteractable, IsActive)
	end
end

local function OnAttributeChanged(InteractableObject: Model)
	if InteractableObject == CurrentInteractable then
		UpdateBillboardText()

		if CurrentHighlight then
			local IsActiveForPlayer = InteractableObject:GetAttribute("ActiveFor") == Player.UserId
			FadeHighlight(CurrentHighlight, not IsActiveForPlayer)
		end
	end
end

for _, TaggedObject in CollectionService:GetTagged(INTERACTABLE_TAG) do
	if TaggedObject:IsA("Model") then
		TaggedObject:GetAttributeChangedSignal("ActiveFor"):Connect(function()
			OnAttributeChanged(TaggedObject)
		end)
	end
end

CollectionService:GetInstanceAddedSignal(INTERACTABLE_TAG):Connect(function(TaggedObject)
	if TaggedObject:IsA("Model") then
		TaggedObject:GetAttributeChangedSignal("ActiveFor"):Connect(function()
			OnAttributeChanged(TaggedObject)
		end)
	end
end)

UserInputService.InputBegan:Connect(HandleInput)

while Character.Parent do
	UpdateInteraction()
	task.wait(0.1)
end