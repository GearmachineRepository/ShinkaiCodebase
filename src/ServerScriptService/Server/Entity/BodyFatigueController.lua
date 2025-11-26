--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatsModule = require(Shared.Configurations.Stats)
local BodyFatigueConfig = require(Shared.Configurations.BodyFatigueConfig)
local Stats = StatsModule.Stats

export type BodyFatigueController = {
	Controller: any,
	CurrentFatigue: number,
	LastSweatTime: number,
	RestMultiplier: number,
	HasFortitude: boolean,

	Update: (self: BodyFatigueController, DeltaTime: number) -> (),
	AddFatigueFromStatGain: (self: BodyFatigueController, BaseAmount: number) -> (),
	SetRestMultiplier: (self: BodyFatigueController, Multiplier: number) -> (),
	SetFortitude: (self: BodyFatigueController, HasFortitude: boolean) -> (),
	GetStaminaDrainMultiplier: (self: BodyFatigueController) -> number,
	IsOverSoftCap: (self: BodyFatigueController) -> boolean,
	CanGainStats: (self: BodyFatigueController) -> boolean,
	GetFatiguePercent: (self: BodyFatigueController) -> number,
	GetEffectiveCap: (self: BodyFatigueController) -> number,
	Destroy: (self: BodyFatigueController) -> (),
}

local BodyFatigueController = {}
BodyFatigueController.__index = BodyFatigueController

function BodyFatigueController.new(CharacterController: any, DataTable: any?): BodyFatigueController
	local SavedFatigue = 0
	if DataTable and DataTable.Stats then
		SavedFatigue = DataTable.Stats[Stats.BODY_FATIGUE] or 0
	end

	local self = setmetatable({
		Controller = CharacterController,
		CurrentFatigue = SavedFatigue,
		LastSweatTime = -math.huge,
		RestMultiplier = 1,
		HasFortitude = false,
	}, BodyFatigueController)

	local Character = CharacterController.Character
	if Character then
		Character:SetAttribute("BodyFatigue", SavedFatigue)
		Character:SetAttribute("Sweating", false)
	end

	return (self :: any) :: BodyFatigueController
end

function BodyFatigueController:AddFatigueFromStatGain(BaseAmount: number)
	if BaseAmount <= 0 then
		return
	end

	local Character = self.Controller.Character
	if not Character then
		return
	end

	self.LastSweatTime = tick()
	Character:SetAttribute("Sweating", true)

	local FatiguePercent = self:GetFatiguePercent()
	local FinalAmount = BaseAmount

	if FatiguePercent >= BodyFatigueConfig.SOFT_CAP_PERCENT then
		FinalAmount *= BodyFatigueConfig.HIGH_FATIGUE_GAIN_MULTIPLIER
	end

	self.CurrentFatigue = math.clamp(self.CurrentFatigue + FinalAmount, 0, BodyFatigueConfig.BODY_FATIGUE_MAX)
	Character:SetAttribute("BodyFatigue", self.CurrentFatigue)

	self.Controller.StateManager:SetStat(Stats.BODY_FATIGUE, self.CurrentFatigue)
end

function BodyFatigueController:Update(DeltaTime: number)
	local Character = self.Controller.Character
	if not Character then
		return
	end

	local Now = tick()
	local TimeSinceSweat = Now - self.LastSweatTime

	if TimeSinceSweat >= BodyFatigueConfig.NO_SWEAT_DECAY_DELAY then
		if self.CurrentFatigue > 0 then
			local DecayRate = BodyFatigueConfig.BASE_DECAY_RATE * self.RestMultiplier
			self.CurrentFatigue = math.max(0, self.CurrentFatigue - DecayRate * DeltaTime)
			Character:SetAttribute("BodyFatigue", self.CurrentFatigue)

			self.Controller.StateManager:SetStat(Stats.BODY_FATIGUE, self.CurrentFatigue)
		end

		if Character:GetAttribute("Sweating") == true then
			Character:SetAttribute("Sweating", false)
		end
	end
end

function BodyFatigueController:SetRestMultiplier(Multiplier: number)
	self.RestMultiplier = math.max(Multiplier, 0)
end

function BodyFatigueController:SetFortitude(HasFortitude: boolean)
	self.HasFortitude = HasFortitude
end

function BodyFatigueController:GetStaminaDrainMultiplier(): number
	local FatiguePercent = self:GetFatiguePercent()

	if FatiguePercent >= BodyFatigueConfig.SOFT_CAP_PERCENT then
		return BodyFatigueConfig.HIGH_FATIGUE_STAMINA_DRAIN_MULTIPLIER
	end

	return 1
end

function BodyFatigueController:IsOverSoftCap(): boolean
	return self:GetFatiguePercent() >= BodyFatigueConfig.SOFT_CAP_PERCENT
end

function BodyFatigueController:CanGainStats(): boolean
	local EffectiveCap = self:GetEffectiveCap()
	return self:GetFatiguePercent() < EffectiveCap
end

function BodyFatigueController:GetEffectiveCap(): number
	if self.HasFortitude then
		return BodyFatigueConfig.FORTITUDE_CAP_PERCENT
	end
	return BodyFatigueConfig.SOFT_CAP_PERCENT
end

function BodyFatigueController:GetFatiguePercent(): number
	return (self.CurrentFatigue / BodyFatigueConfig.BODY_FATIGUE_MAX) * 100
end

function BodyFatigueController:Destroy()
	for Key in pairs(self) do
		self[Key] = nil
	end

	setmetatable(self, nil)
end

return BodyFatigueController