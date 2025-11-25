--!strict
local RunService = game:GetService("RunService")

local BODY_FATIGUE_MAX = 100
local SOFT_CAP_PERCENT = 65
local FORTITUDE_CAP_PERCENT = 85
local NO_SWEAT_DECAY_DELAY = 5 * 60
local BASE_DECAY_RATE = 2

local HIGH_FATIGUE_STAMINA_DRAIN_MULTIPLIER = 1.4
local HIGH_FATIGUE_GAIN_MULTIPLIER = 1.25

export type BodyFatigueController = {
	Controller: any,
	CurrentFatigue: number,
	LastSweatTime: number,
	RestMultiplier: number,
	HasFortitude: boolean,

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

function BodyFatigueController.new(CharacterController: any): BodyFatigueController
	local self = setmetatable({
		Controller = CharacterController,
		CurrentFatigue = 0,
		LastSweatTime = -math.huge,
		RestMultiplier = 1,
		HasFortitude = false,
	}, BodyFatigueController)

	local Character = CharacterController.Character
	if Character then
		Character:SetAttribute("BodyFatigue", 0)
		Character:SetAttribute("Sweating", false)
	end

	local UpdateConnection = RunService.Heartbeat:Connect(function(DeltaTime)
		self:Update(DeltaTime)
	end)

	CharacterController.Maid:Set("BodyFatigueUpdate", UpdateConnection)

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

	if FatiguePercent >= SOFT_CAP_PERCENT then
		FinalAmount *= HIGH_FATIGUE_GAIN_MULTIPLIER
	end

	self.CurrentFatigue = math.clamp(self.CurrentFatigue + FinalAmount, 0, BODY_FATIGUE_MAX)
	Character:SetAttribute("BodyFatigue", self.CurrentFatigue)
end

function BodyFatigueController:Update(DeltaTime: number)
	local Character = self.Controller.Character
	if not Character then
		return
	end

	local Now = tick()
	local TimeSinceSweat = Now - self.LastSweatTime

	if TimeSinceSweat >= NO_SWEAT_DECAY_DELAY then
		if self.CurrentFatigue > 0 then
			local DecayRate = BASE_DECAY_RATE * self.RestMultiplier
			self.CurrentFatigue = math.max(0, self.CurrentFatigue - DecayRate * DeltaTime)
			Character:SetAttribute("BodyFatigue", self.CurrentFatigue)
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

	if FatiguePercent >= SOFT_CAP_PERCENT then
		return HIGH_FATIGUE_STAMINA_DRAIN_MULTIPLIER
	end

	return 1
end

function BodyFatigueController:IsOverSoftCap(): boolean
	return self:GetFatiguePercent() >= SOFT_CAP_PERCENT
end

function BodyFatigueController:CanGainStats(): boolean
	local EffectiveCap = self:GetEffectiveCap()
	return self:GetFatiguePercent() < EffectiveCap
end

function BodyFatigueController:GetEffectiveCap(): number
	if self.HasFortitude then
		return FORTITUDE_CAP_PERCENT
	end
	return SOFT_CAP_PERCENT
end

function BodyFatigueController:GetFatiguePercent(): number
	return (self.CurrentFatigue / BODY_FATIGUE_MAX) * 100
end

function BodyFatigueController:Destroy()
	self.Controller.Maid:Set("BodyFatigueUpdate", nil)

	for Key in pairs(self) do
		self[Key] = nil
	end

	setmetatable(self, nil)
end

return BodyFatigueController