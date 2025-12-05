--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("Configurations")
local StatsModule = require(Configs:WaitForChild("Stats"))
local HungerConfig = require(Configs:WaitForChild("HungerConfig"))
local Network = Shared:WaitForChild("Networking")
local Packet = require(Network:WaitForChild("Packets"))
local Formulas = require(Shared.General.Formulas)
local TrainableStats = StatsModule.TrainableStats

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Hud = PlayerGui:WaitForChild("Hud")
local Frames = Hud:WaitForChild("Frames")
local StatsFrame = Frames:WaitForChild("Stats")
local StatsList = StatsFrame:WaitForChild("StatList")
local StatTemplate = StatsList:WaitForChild("StatTemplate")

local Character = script.Parent

local PointText = "Points: "
local BuffText = "+"

local StatFrames = {}

for _, Stat in pairs(TrainableStats) do
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
		PointsLabel.Text = PointText .. "0"
	end

	if TotalStatBuffLabel then
		TotalStatBuffLabel.Text = BuffText .. "0"
	end

	if AllocateButton then
		AllocateButton.Visible = false

		AllocateButton.MouseButton1Click:Connect(function()
			local AllocatablePoints = Character:GetAttribute(Stat .. "_AvailablePoints") or 0
			if AllocatablePoints <= 0 then
				return
			end

			local CurrentStars = Character:GetAttribute(Stat .. "_Stars") or 0

			if CurrentStars >= StatsModule.HARD_CAP_THRESHOLD then
				warn("This stat is maxed at 35 stars!")
				return
			end

			Packet.AllocateStatPoint:Fire(Stat)
		end)
	end

	table.insert(StatFrames, NewTemplate)
end

local MAX_STARS_PER_ROW = 5
local DIM_COLOR = Color3.fromRGB(50, 50, 50)

local function GetHungerPercent(): number
	local CurrentHunger = Character:GetAttribute(StatsModule.Stats.HUNGER) or 0
	local MaxHunger = Character:GetAttribute(StatsModule.Stats.MAX_HUNGER) or 1

	return (CurrentHunger / MaxHunger) * 100
end

local function IsStarving(): boolean
	return GetHungerPercent() < HungerConfig.HUNGER_CRITICAL_THRESHOLD
end

local function UpdateStatStars(BaseStatName: string)
	local AllocatedStars = Character:GetAttribute(BaseStatName .. "_Stars") or 0

	local StatFrame: Frame? = nil
	for _, Frame in ipairs(StatFrames) do
		if Frame.Name == BaseStatName then
			StatFrame = Frame
			break
		end
	end
	if not StatFrame then
		return
	end

	local Stars1 = StatFrame:FindFirstChild("Stars1")
	if not Stars1 then
		return
	end

	for Index = 1, MAX_STARS_PER_ROW do
		local Star = Stars1:FindFirstChild(tostring(Index))
		if Star and Star:IsA("ImageLabel") then
			local HighestTierForPosition = -1

			local CheckStar = Index - 1
			while CheckStar < AllocatedStars do
				HighestTierForPosition = CheckStar
				CheckStar += MAX_STARS_PER_ROW
			end

			if HighestTierForPosition >= 0 then
				local StarTier = StatsModule.GetStarTierForIndex(HighestTierForPosition)
				Star.ImageColor3 = StarTier.Color
			else
				Star.ImageColor3 = DIM_COLOR
			end
		end
	end

	local TotalStatBuffLabel = StatFrame:FindFirstChild("TotalBuff")
	if TotalStatBuffLabel then
		local MuscleValue = Character:GetAttribute(StatsModule.Stats.MUSCLE) or 0
		local Starving = IsStarving()

		local StatValue = StatsModule.GetStatValueFromStarsWithPenalties(BaseStatName, AllocatedStars, MuscleValue, Starving)
		local BaseValue = StatsModule.GetStatBase(BaseStatName) or 0
		local BuffAmount = Formulas.Round(StatValue - BaseValue, 2)
		TotalStatBuffLabel.Text = BuffText .. tostring(BuffAmount)
	end
end

local Attributes = Character:GetAttributes()
for AttributeName, _ in pairs(Attributes) do
	if AttributeName:match("_Stars$") then
		local BaseStatName = AttributeName:gsub("_Stars$", "")
		UpdateStatStars(BaseStatName)
	end
end

Character.AttributeChanged:Connect(function(AttrName: string)
	if AttrName:match("_Stars$") then
		local BaseStatName = AttrName:gsub("_Stars$", "")
		UpdateStatStars(BaseStatName)
	end

	if AttrName == StatsModule.Stats.MUSCLE or AttrName == StatsModule.Stats.HUNGER then
		for _, StatName in TrainableStats do
			UpdateStatStars(StatName)
		end
	end

	if AttrName:match("_AvailablePoints$") then
		local BaseStatName = AttrName:gsub("_AvailablePoints$", "")

		local StatFrame: Frame? = nil
		for _, Frame in ipairs(StatFrames) do
			if Frame.Name == BaseStatName then
				StatFrame = Frame
				break
			end
		end
		if not StatFrame then
			return
		end

		local AllocateButton = StatFrame:FindFirstChild("Allocate")
		local PointsLabel = StatFrame:FindFirstChild("Points")
		if AllocateButton and PointsLabel then
			local AllocatablePoints = Character:GetAttribute(BaseStatName .. "_AvailablePoints") or 0
			local CurrentStars = Character:GetAttribute(BaseStatName .. "_Stars") or 0

			local CanAllocate = AllocatablePoints > 0 and CurrentStars < StatsModule.HARD_CAP_THRESHOLD

			AllocateButton.Visible = CanAllocate
			PointsLabel.Text = PointText .. tostring(AllocatablePoints)

			if CurrentStars >= StatsModule.HARD_CAP_THRESHOLD then
				PointsLabel.Text = "MAXED"
			end
		end
	end
end)