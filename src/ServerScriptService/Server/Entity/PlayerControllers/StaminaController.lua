--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local Maid = require(Shared.General.Maid)

local SPRINT_STAMINA_COST = 8
local JOG_STAMINA_COST = 4
local REGEN_RATE = 5
local REGEN_DELAY = 1.5
local EXHAUSTED_THRESHOLD = 10

local StaminaController = {}
StaminaController.__index = StaminaController

export type StaminaController = typeof(setmetatable({} :: {
	Controller: any,
	LastStaminaUse: number,
	IsExhausted: boolean,
	Maid: Maid.MaidSelf,
}, StaminaController))

function StaminaController.new(CharacterController: any): StaminaController
	local self = setmetatable({
		Controller = CharacterController,
		LastStaminaUse = 0,
		IsExhausted = false,
		Maid = Maid.new(),
	}, StaminaController)

	self:StartRegen()

	return self
end

function StaminaController:GetMaxStamina(): number
	return self.Controller.StatManager:GetStat(StatTypes.MAX_STAMINA)
end

function StaminaController:StartRegen()
	self.Maid:Set("StaminaRegen", RunService.Heartbeat:Connect(function(DeltaTime)
		if tick() - self.LastStaminaUse < REGEN_DELAY then
			return
		end

		local CurrentStamina = self.Controller.StatManager:GetStat(StatTypes.STAMINA)
		local MaxStamina = self:GetMaxStamina()

		if CurrentStamina >= MaxStamina then
			return
		end

		local StaminaGain = REGEN_RATE * DeltaTime
		self:RestoreStamina(StaminaGain)

		if self.Controller.HungerController then
			self.Controller.HungerController:ConsumeHungerForStamina(StaminaGain)
		end
	end))
end

function StaminaController:ConsumeStamina(Amount: number): boolean
	local CurrentStamina = self.Controller.StatManager:GetStat(StatTypes.STAMINA)

	if CurrentStamina >= Amount then
		local NewStamina = CurrentStamina - Amount
		self.Controller.StatManager:SetStat(StatTypes.STAMINA, NewStamina)

		self.LastStaminaUse = tick()

		if NewStamina <= 0 then
			self.IsExhausted = true
			self.Controller.Character:SetAttribute("Exhausted", true)
		end

		return true
	end

	return false
end

function StaminaController:CanSprint(): boolean
	local CurrentStamina = self.Controller.StatManager:GetStat(StatTypes.STAMINA)
	return CurrentStamina > 0 and not self.IsExhausted
end

function StaminaController:CanJog(): boolean
	local CurrentStamina = self.Controller.StatManager:GetStat(StatTypes.STAMINA)
	return CurrentStamina > 0 and not self.IsExhausted
end

function StaminaController:HandleSprint(DeltaTime: number): boolean
	if not self:CanSprint() then
		return false
	end

	local DrainMultiplier = 1
	if self.Controller.BodyFatigueController then
		DrainMultiplier = self.Controller.BodyFatigueController:GetStaminaDrainMultiplier()
	end

	local StaminaCost = SPRINT_STAMINA_COST * DeltaTime * DrainMultiplier
	return self:ConsumeStamina(StaminaCost)
end

function StaminaController:HandleJog(DeltaTime: number): boolean
	if not self:CanJog() then
		return false
	end

	local DrainMultiplier = 1
	if self.Controller.BodyFatigueController then
		DrainMultiplier = self.Controller.BodyFatigueController:GetStaminaDrainMultiplier()
	end

	local StaminaCost = JOG_STAMINA_COST * DeltaTime * DrainMultiplier
	return self:ConsumeStamina(StaminaCost)
end

function StaminaController:RestoreStamina(Amount: number)
	local CurrentStamina = self.Controller.StatManager:GetStat(StatTypes.STAMINA)
	local MaxStamina = self:GetMaxStamina()
	local NewStamina = math.min(MaxStamina, CurrentStamina + Amount)

	self.Controller.StatManager:SetStat(StatTypes.STAMINA, NewStamina)

	if self.IsExhausted and NewStamina >= EXHAUSTED_THRESHOLD then
		self.IsExhausted = false
		self.Controller.Character:SetAttribute("Exhausted", false)
	end
end

function StaminaController:Destroy()
	self.Maid:DoCleaning()
end

return StaminaController