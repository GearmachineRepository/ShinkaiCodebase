--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatSystem = require(Server.Systems.StatSystem)
local ProgressionSystem = require(Server.Systems.ProgressionSystem)
local Maid = require(Shared.General.Maid)

local TrainingController = {}
TrainingController.__index = TrainingController

export type TrainingController = typeof(setmetatable({} :: {
	Controller: any,
	PlayerData: any,
	CurrentTraining: string?,
	Maid: Maid.MaidSelf,
}, TrainingController))

function TrainingController.new(CharacterController: any, PlayerData: any): TrainingController
	local self = setmetatable({
		Controller = CharacterController,
		PlayerData = PlayerData,
		CurrentTraining = nil,
		Maid = Maid.new(),
	}, TrainingController)

	return self
end

function TrainingController:StartTraining(TrainingType: string)
	self.CurrentTraining = TrainingType
end

function TrainingController:StopTraining()
	self.CurrentTraining = nil
end

function TrainingController:ProcessTraining(_: number) -- DeltaTime not used here
	if not self.CurrentTraining then
		return
	end
end

function TrainingController:GrantStatGain(StatName: string, Amount: number, _: number?) -- Custom fatigue rate not used here
	if Amount <= 0 then
		return
	end

	local IsPremium = false
	ProgressionSystem.AwardTrainingXP(self.PlayerData, StatName, Amount, IsPremium)

	self:UpdateAvailablePoints(StatName)

	local Character = self.Controller.Character
	if Character then
		local XPValue = self.PlayerData.Stats[StatName .. "_XP"]
		Character:SetAttribute(StatName .. "_XP", XPValue)

		local AvailablePoints = self.PlayerData.Stats[StatName .. "_AvailablePoints"]
		Character:SetAttribute(StatName .. "_AvailablePoints", AvailablePoints)
	end
end

function TrainingController:AllocateStatPoint(StatName: string): boolean
	local Success, ErrorMessage = StatSystem.AllocateStar(self.PlayerData, StatName)

	if not Success then
		warn("Failed to allocate star:", ErrorMessage)
		return false
	end

	local Character = self.Controller.Character
	if Character then
		local NewStars = self.PlayerData.Stats[StatName .. "_Stars"]
		Character:SetAttribute(StatName .. "_Stars", NewStars)

		local StatValue = StatSystem.CalculateStatValue(0, NewStars, StatName)
		Character:SetAttribute(StatName, StatValue)
	end

	return true
end

function TrainingController:UpdateAvailablePoints(StatName: string)
	local Character = self.Controller.Character
	if not Character then
		return
	end

	local XPValue = self.PlayerData.Stats[StatName .. "_XP"] or 0
	local AllocatedStars = self.PlayerData.Stats[StatName .. "_Stars"] or 0

	local AvailablePoints = ProgressionSystem.GetAvailablePointsFromXP(StatName, XPValue, AllocatedStars)

	self.PlayerData.Stats[StatName .. "_AvailablePoints"] = AvailablePoints
	Character:SetAttribute(StatName .. "_AvailablePoints", AvailablePoints)
end

function TrainingController:CanTrain(): boolean
	return self.Controller.BodyFatigueController:CanGainStats()
end

function TrainingController:GetTotalAllocatedStars(): number
	return StatSystem.GetTotalAllocatedStars(self.PlayerData)
end

function TrainingController:Destroy()
	self:StopTraining()
	self.Maid:DoCleaning()
end

return TrainingController