--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("Configurations")
local StatsModule = require(Configs:WaitForChild("Stats"))
local Network = Shared:WaitForChild("Networking")
local Packet = require(Network:WaitForChild("Packets"))
local TrainableStats = StatsModule.TrainableStats

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Hud = PlayerGui:WaitForChild("Hud")
local Frames = Hud:WaitForChild("Frames")
local StatsFrame = Frames:WaitForChild("Stats")
local StatsList = StatsFrame:WaitForChild("StatList")
local StatTemplate = StatsList:WaitForChild("StatTemplate")

local Character = script.Parent

local StatFrames = {}

for _, Stat in pairs(TrainableStats) do
	local NewTemplate = StatTemplate:Clone()
	NewTemplate.Name = Stat
	NewTemplate.StatName.Text = Stat
	NewTemplate.Visible = true
	NewTemplate.Parent = StatTemplate.Parent

	local AllocateButton = NewTemplate:FindFirstChild("Allocate")
	local PointsLabel = NewTemplate:FindFirstChild("Points")

	if PointsLabel then
		PointsLabel.Text = "Points: 0"
	end
	if AllocateButton then
		AllocateButton.Visible = false

		AllocateButton.MouseButton1Click:Connect(function()
			local AllocatablePoints = Character:GetAttribute(Stat .. "_AvailablePoints") or 0
			if AllocatablePoints <= 0 then
				return
			end

			local TotalStars = 0
			for _, StatName in TrainableStats do
				TotalStars += Character:GetAttribute(StatName .. "_Stars") or 0
			end

			if TotalStars >= StatsModule.HARD_CAP_THRESHOLD then
				warn("Hard cap reached! Cannot allocate more stars.")
				return
			end

			Packet.AllocateStatPoint:Fire(Stat)
		end)
	end

	table.insert(StatFrames, NewTemplate)
end

local MAX_STARS_PER_ROW = 5
local DIM_COLOR = Color3.fromRGB(50, 50, 50)

local function GetTotalAllocatedStars(): number
	local TotalStars = 0
	for _, StatName in TrainableStats do
		TotalStars += Character:GetAttribute(StatName .. "_Stars") or 0
	end
	return TotalStars
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
			local TotalStars = GetTotalAllocatedStars()

			local CanAllocate = AllocatablePoints > 0 and TotalStars < StatsModule.HARD_CAP_THRESHOLD

			AllocateButton.Visible = CanAllocate
			PointsLabel.Text = "Points: " .. tostring(AllocatablePoints)

			if TotalStars >= StatsModule.HARD_CAP_THRESHOLD then
				PointsLabel.Text = "MAXED"
			end
		end
	end
end)