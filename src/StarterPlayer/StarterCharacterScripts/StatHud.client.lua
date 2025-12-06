--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatUtils = require(Shared.Utils.StatUtils)
local Packets = require(Shared.Networking.Packets)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Hud = PlayerGui:WaitForChild("Hud")
local Frames = Hud:WaitForChild("Frames")
local StatsFrame = Frames:WaitForChild("Stats")
local StatsList = StatsFrame:WaitForChild("StatList")
local StatTemplate = StatsList:WaitForChild("StatTemplate")

local Character = script.Parent

local POINT_TEXT = "Points: "
local BUFF_TEXT = "+"
local MAX_STARS_PER_ROW = 5
local DIM_COLOR = Color3.fromRGB(50, 50, 50)

local StatFrames = {}

for _, Stat in StatUtils.TRAINABLE_STATS do
	local NewTemplate = StatTemplate:Clone()
	NewTemplate.Name = Stat
	NewTemplate.StatName.Text = Stat
	NewTemplate.Visible = true
	NewTemplate.Parent = StatTemplate.Parent

	if not NewTemplate.StatName.TextFits then
		NewTemplate.StatName.TextFits = true
	end

	local AllocateButton = NewTemplate:FindFirstChild("Allocate")
	local PointsLabel = NewTemplate:FindFirstChild("Points")
	local TotalStatBuffLabel = NewTemplate:FindFirstChild("TotalBuff")

	if PointsLabel then
		PointsLabel.Text = POINT_TEXT .. "0"
	end

	if TotalStatBuffLabel then
		TotalStatBuffLabel.Text = BUFF_TEXT .. "0"
	end

	if AllocateButton then
		AllocateButton.Visible = false

		AllocateButton.MouseButton1Click:Connect(function()
			local AllocatablePoints = Character:GetAttribute(Stat .. "_AvailablePoints") or 0
			if AllocatablePoints <= 0 then
				return
			end

			local CurrentStars = Character:GetAttribute(Stat .. "_Stars") or 0

			if CurrentStars >= StatUtils.HARD_CAP then
				warn("This stat is maxed at", StatUtils.HARD_CAP, "stars!")
				return
			end

			Packets.AllocateStatPoint:Fire(Stat)
		end)
	end

	table.insert(StatFrames, NewTemplate)
end

local function UpdateStatStars(BaseStatName: string)
	local AllocatedStars = Character:GetAttribute(BaseStatName .. "_Stars") or 0

	local StatFrame: Frame? = nil
	for _, Frame in StatFrames do
		if Frame.Name == BaseStatName then
			StatFrame = Frame
			break
		end
	end

	if not StatFrame then
		return
	end

	local StarsContainer = StatFrame:FindFirstChild("Stars")
	if not StarsContainer then
		return
	end

	local TotalRows = math.ceil(AllocatedStars / MAX_STARS_PER_ROW)
	local CurrentStarIndex = 1

	for RowIndex = 1, TotalRows do
		local RowFrame = StarsContainer:FindFirstChild("Row" .. RowIndex)
		if not RowFrame then
			break
		end

		for StarIndex = 1, MAX_STARS_PER_ROW do
			local Star = RowFrame:FindFirstChild("Star" .. StarIndex)
			if Star and Star:IsA("ImageLabel") then
				if CurrentStarIndex <= AllocatedStars then
					Star.ImageColor3 = Color3.new(1, 1, 1)
				else
					Star.ImageColor3 = DIM_COLOR
				end
				CurrentStarIndex += 1
			end
		end
	end
end

local function UpdateStatValue(BaseStatName: string)
	local AllocatedStars = Character:GetAttribute(BaseStatName .. "_Stars") or 0
	local StatValue = StatUtils.CalculateStatValue(BaseStatName, AllocatedStars)

	local StatFrame: Frame? = nil
	for _, Frame in StatFrames do
		if Frame.Name == BaseStatName then
			StatFrame = Frame
			break
		end
	end

	if not StatFrame then
		return
	end

	local TotalStatBuffLabel = StatFrame:FindFirstChild("TotalBuff")
	if TotalStatBuffLabel and TotalStatBuffLabel:IsA("TextLabel") then
		local BaseValue = StatUtils.GetBaseValue(BaseStatName)
		local BuffAmount = StatValue - BaseValue
		TotalStatBuffLabel.Text = BUFF_TEXT .. math.floor(BuffAmount)
	end
end

local function UpdateAvailablePoints(BaseStatName: string)
	local AvailablePoints = Character:GetAttribute(BaseStatName .. "_AvailablePoints") or 0

	local StatFrame: Frame? = nil
	for _, Frame in StatFrames do
		if Frame.Name == BaseStatName then
			StatFrame = Frame
			break
		end
	end

	if not StatFrame then
		return
	end

	local PointsLabel = StatFrame:FindFirstChild("Points")
	if PointsLabel and PointsLabel:IsA("TextLabel") then
		PointsLabel.Text = POINT_TEXT .. AvailablePoints
	end

	local AllocateButton = StatFrame:FindFirstChild("Allocate")
	if AllocateButton then
		AllocateButton.Visible = AvailablePoints > 0
	end
end

local function UpdateAllStats()
	for _, Stat in StatUtils.TRAINABLE_STATS do
		UpdateStatStars(Stat)
		UpdateStatValue(Stat)
		UpdateAvailablePoints(Stat)
	end
end

for _, Stat in StatUtils.TRAINABLE_STATS do
	Character:GetAttributeChangedSignal(Stat .. "_Stars"):Connect(function()
		UpdateStatStars(Stat)
		UpdateStatValue(Stat)
	end)

	Character:GetAttributeChangedSignal(Stat .. "_AvailablePoints"):Connect(function()
		UpdateAvailablePoints(Stat)
	end)
end

UpdateAllStats()