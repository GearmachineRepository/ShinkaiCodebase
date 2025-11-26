--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatsModule = require(Shared.Configurations.Stats)
local StaminaConfig = require(Shared.Configurations.StaminaConfig)
local Stats = StatsModule.Stats
local Defaults = StatsModule.Defaults

export type StaminaController = {
	Controller: any,
	IsExhausted: boolean,
	LastStaminaUse: number,

	StartRegen: (self: StaminaController) -> (),
	StopRegen: (self: StaminaController) -> (),
	ConsumeStamina: (self: StaminaController, Amount: number) -> boolean,
	CanSprint: (self: StaminaController) -> boolean,
	CanJog: (self: StaminaController) -> boolean,
	GetStaminaPercent: (self: StaminaController) -> number,
	HandleSprint: (self: StaminaController, DeltaTime: number) -> boolean,
	HandleJog: (self: StaminaController, DeltaTime: number) -> boolean,
	RestoreStamina: (self: StaminaController, Amount: number) -> (),
	Destroy: (self: StaminaController) -> (),
}

local StaminaController = {}
StaminaController.__index = StaminaController

function StaminaController.new(CharacterController: any): StaminaController
	local self = setmetatable({
		Controller = CharacterController,
		IsExhausted = false,
		LastStaminaUse = 0,
		BodyFatigueController = CharacterController.BodyFatigueController,
	}, StaminaController)

	local Character = CharacterController.Character

	if Character then
		local MaxStamina = CharacterController.StateManager:GetStat(Stats.MAX_STAMINA)
		Character:SetAttribute(Stats.STAMINA, MaxStamina)
		Character:SetAttribute(Stats.MAX_STAMINA, MaxStamina)
		Character:SetAttribute("Drained", false)
		Character:SetAttribute("Exhausted", false)
	end

	return (self :: any) :: StaminaController
end

function StaminaController:StartRegen()
	local RegenConnection = RunService.Heartbeat:Connect(function(DeltaTime)
		local CurrentTime = tick()
		local StateManager = self.Controller.StateManager
		local Character = self.Controller.Character

		if CurrentTime - self.LastStaminaUse < StaminaConfig.STAMINA_REGEN_DELAY then
			return
		end

		local CurrentStamina = StateManager:GetStat(Stats.STAMINA)
		local MaxStamina = StateManager:GetStat(Stats.MAX_STAMINA)

		if CurrentStamina >= MaxStamina then
			self:StopRegen()
			return
		end

		local BaseRegen = StaminaConfig.STAMINA_REGEN_RATE
		local RegenMultiplier = MaxStamina / Defaults[Stats.MAX_STAMINA]
		local RegenRate = BaseRegen * RegenMultiplier

		if self.IsExhausted then
			RegenRate *= StaminaConfig.EXHAUSTED_REGEN_MULTIPLIER
		end

		local StaminaGain = RegenRate * DeltaTime
		local NewStamina = math.min(MaxStamina, CurrentStamina + StaminaGain)
		StateManager:SetStat(Stats.STAMINA, NewStamina)

		if Character then
			Character:SetAttribute(Stats.STAMINA, NewStamina)

			local StaminaPercent = (NewStamina / MaxStamina) * 100
			Character:SetAttribute("Drained", StaminaPercent <= StaminaConfig.DRAINED_THRESHOLD)

			if self.IsExhausted and StaminaPercent >= StaminaConfig.EXHAUSTED_REMOVAL_THRESHOLD then
				self.IsExhausted = false
				Character:SetAttribute("Exhausted", false)
			end
		end

		if self.Controller.HungerController then
			self.Controller.HungerController:ConsumeHungerForStamina(StaminaGain)
		end
	end)

	self.Controller.Maid:Set("StaminaRegen", RegenConnection)
end

function StaminaController:StopRegen()
	self.Controller.Maid:Set("StaminaRegen", nil)
end

function StaminaController:ConsumeStamina(Amount: number): boolean
	local StateManager = self.Controller.StateManager
	local Character = self.Controller.Character
	local CurrentStamina = StateManager:GetStat(Stats.STAMINA)

	if CurrentStamina >= Amount then
		local NewStamina = CurrentStamina - Amount
		local MaxStamina = StateManager:GetStat(Stats.MAX_STAMINA)
		StateManager:SetStat(Stats.STAMINA, NewStamina)

		if Character then
			Character:SetAttribute(Stats.STAMINA, NewStamina)

			local StaminaPercent = (NewStamina / MaxStamina) * 100
			Character:SetAttribute("Drained", StaminaPercent <= StaminaConfig.DRAINED_THRESHOLD)
		end

		self.LastStaminaUse = tick()

		if NewStamina <= 0 then
			self.IsExhausted = true
			if Character then
				Character:SetAttribute("Exhausted", true)
			end
		end

		self:StartRegen()
		return true
	end

	return false
end

function StaminaController:CanSprint(): boolean
	local CurrentStamina = self.Controller.StateManager:GetStat(Stats.STAMINA)
	return CurrentStamina > 0 and not self.IsExhausted
end

function StaminaController:CanJog(): boolean
	local CurrentStamina = self.Controller.StateManager:GetStat(Stats.STAMINA)
	return CurrentStamina > 0 and not self.IsExhausted
end

function StaminaController:GetStaminaPercent(): number
	local StateManager = self.Controller.StateManager
	local CurrentStamina = StateManager:GetStat(Stats.STAMINA)
	local MaxStamina = StateManager:GetStat(Stats.MAX_STAMINA)

	return (CurrentStamina / MaxStamina) * 100
end

function StaminaController:HandleSprint(DeltaTime: number): boolean
	if not self:CanSprint() then
		return false
	end

	local DrainMultiplier = 1
	if self.BodyFatigueController then
		DrainMultiplier = self.BodyFatigueController:GetStaminaDrainMultiplier()
	end

	local StaminaCost = StaminaConfig.SPRINT_STAMINA_COST_PER_SECOND * DeltaTime * DrainMultiplier
	return self:ConsumeStamina(StaminaCost)
end

function StaminaController:HandleJog(DeltaTime: number): boolean
	if not self:CanJog() then
		return false
	end

	local DrainMultiplier = 1
	if self.BodyFatigueController then
		DrainMultiplier = self.BodyFatigueController:GetStaminaDrainMultiplier()
	end

	local StaminaCost = StaminaConfig.JOG_STAMINA_COST_PER_SECOND * DeltaTime * DrainMultiplier
	return self:ConsumeStamina(StaminaCost)
end

function StaminaController:RestoreStamina(Amount: number)
	local StateManager = self.Controller.StateManager
	local Character = self.Controller.Character

	local CurrentStamina = StateManager:GetStat(Stats.STAMINA)
	local MaxStamina = StateManager:GetStat(Stats.MAX_STAMINA)
	local NewStamina = math.min(MaxStamina, CurrentStamina + Amount)

	StateManager:SetStat(Stats.STAMINA, NewStamina)

	if Character then
		Character:SetAttribute(Stats.STAMINA, NewStamina)

		local StaminaPercent = (NewStamina / MaxStamina) * 100
		Character:SetAttribute("Drained", StaminaPercent <= StaminaConfig.DRAINED_THRESHOLD)

		if self.IsExhausted and StaminaPercent >= StaminaConfig.EXHAUSTED_REMOVAL_THRESHOLD then
			self.IsExhausted = false
			Character:SetAttribute("Exhausted", false)
		end
	end

	self:StartRegen()
end

function StaminaController:Destroy()
	self:StopRegen()

	for Key in pairs(self) do
		self[Key] = nil
	end

	setmetatable(self, nil)
end

return StaminaController