local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("Configurations")
local StatsModule = require(Configs:WaitForChild("Stats"))
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
	table.insert(StatFrames, NewTemplate)
end

local MAX_STARS_PER_ROW = 5
local DIM_COLOR = Color3.fromRGB(0, 0, 0)
local LIT_COLOR = Color3.new(1, 1, 1)
local LIT_COLOR2 = Color3.new(0.807843, 0.796078, 0.517647)

local function SetRowStars(RowFrame: Frame, count: number)
	for i = 1, MAX_STARS_PER_ROW do
		local star = RowFrame:FindFirstChild(tostring(i))
		if star and star:IsA("ImageLabel") then
			if i <= count then
				star.ImageColor3 = (RowFrame.Name == "Stars2") and LIT_COLOR2 or LIT_COLOR
			else
				star.ImageColor3 = DIM_COLOR
			end
		end
	end
end

local function UpdateStatStars(baseStatName: string)
    local starsAttr = baseStatName .. "_Stars"
    local progAttr = baseStatName .. "_Progress"

    local totalStars = Character:GetAttribute(starsAttr) or 0

    -- rawProgress is usually between -1 and 0
    local rawProgress = Character:GetAttribute(progAttr)
    if rawProgress == nil then
        rawProgress = 1 -- default to fully dim if not present
    end

    -- Turn -1..0 into 0..1, where:
    -- 0 = fully lit, 1 = fully dim
    local normalized = math.clamp(math.abs(rawProgress), 0, 1)
    local fade = 1 - normalized  -- 0 = dim, 1 = lit for Lerp

	-- Find the frame for this stat
	local statFrame: Frame? = nil
	for _, frame in ipairs(StatFrames) do
		if frame.Name == baseStatName then
			statFrame = frame
			break
		end
	end
	if not statFrame then return end

	local Stars1 = statFrame:FindFirstChild("Stars1")
	local Stars2 = statFrame:FindFirstChild("Stars2")
	if not (Stars1 and Stars2) then return end

	-- Full stars
	local row1Count = math.clamp(totalStars, 0, MAX_STARS_PER_ROW)
	local row2Count = math.clamp(totalStars - MAX_STARS_PER_ROW, 0, MAX_STARS_PER_ROW)

	SetRowStars(Stars1, row1Count)
	SetRowStars(Stars2, row2Count)

	-- Partially fill the NEXT star based on progress (if there is a next star)
    local maxStarsTotal = MAX_STARS_PER_ROW * 2
    if totalStars < maxStarsTotal and fade > 0 then
        local nextIndex = totalStars + 1

        local rowFrame
        local litColor
        local localIndex

        if nextIndex <= MAX_STARS_PER_ROW then
            rowFrame = Stars1
            litColor = LIT_COLOR
            localIndex = nextIndex
        else
            rowFrame = Stars2
            litColor = LIT_COLOR2
            localIndex = nextIndex - MAX_STARS_PER_ROW
        end

        local nextStar = rowFrame:FindFirstChild(tostring(localIndex))
        if nextStar and nextStar:IsA("ImageLabel") then
            -- fade: 0 (dim) → 1 (lit)
            nextStar.ImageColor3 = DIM_COLOR:Lerp(litColor, fade)
        end
    end
end

local Attributes = Character:GetAttributes()
for AttributeName, _ in pairs(Attributes) do
    if AttributeName:match("_Stars$") then
        local baseStatName = AttributeName:gsub("_Stars$", "")
        UpdateStatStars(baseStatName)
    end
end

Character.AttributeChanged:Connect(function(attrName: string)
	-- Respond to both Stars and Progress changes
	if attrName:match("_Stars$") then
		local baseStatName = attrName:gsub("_Stars$", "")
		UpdateStatStars(baseStatName)
	elseif attrName:match("_Progress$") then
		local baseStatName = attrName:gsub("_Progress$", "")
		UpdateStatStars(baseStatName)
	end
end)
