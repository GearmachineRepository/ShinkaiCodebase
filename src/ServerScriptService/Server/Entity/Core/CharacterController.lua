--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")
local Entity = Server:WaitForChild("Entity")

local StateManager = require(Entity.Core.StateManager)
local StatManager = require(Entity.Core.StatManager)
local HookController = require(Entity.Specialized.HookController)
local StateHandlers = require(Entity.Handlers.StateHandlers)

local StaminaController = require(Entity.PlayerControllers.StaminaController)
local HungerController = require(Entity.PlayerControllers.HungerController)
local BodyFatigueController = require(Entity.PlayerControllers.BodyFatigueController)
local TrainingController = require(Entity.PlayerControllers.TrainingController)

local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local Maid = require(Shared.General.Maid)

local CharacterController = {}
CharacterController.__index = CharacterController

export type DamageModifier = (Damage: number, Data: {[string]: any}) -> number
export type HealingModifier = (HealAmount: number, Data: {[string]: any}) -> number
export type StaminaCostModifier = (Cost: number, Data: {[string]: any}) -> number
export type SpeedModifier = (Speed: number, Data: {[string]: any}) -> number

export type ControllerType = typeof(setmetatable({} :: {
	Character: Model,
	Humanoid: Humanoid,
	IsPlayer: boolean,
	Maid: Maid.MaidSelf,
	StateManager: StateManager.StateManager,
	StatManager: StatManager.StatManager,
	HookController: HookController.HookController,
	StaminaController: StaminaController.StaminaController?,
	HungerController: HungerController.HungerController?,
	BodyFatigueController: BodyFatigueController.BodyFatigueController?,
	TrainingController: TrainingController.TrainingController?,
	DamageModifiers: {{Priority: number, Modifier: DamageModifier}},
	AttackModifiers: {{Priority: number, Modifier: DamageModifier}},
	HealingModifiers: {{Priority: number, Modifier: HealingModifier}},
	StaminaCostModifiers: {{Priority: number, Modifier: StaminaCostModifier}},
	SpeedModifiers: {{Priority: number, Modifier: SpeedModifier}},
}, CharacterController))

local Controllers: {[Model]: ControllerType} = {}

function CharacterController.new(Character: Model, IsPlayer: boolean, PlayerData: any?): ControllerType
	local self = setmetatable({
		Character = Character,
		Humanoid = Character:WaitForChild("Humanoid") :: Humanoid,
		IsPlayer = IsPlayer,
		Maid = Maid.new(),
		StateManager = nil :: StateManager.StateManager?,
		StatManager = nil :: StatManager.StatManager?,
		HookController = nil :: HookController.HookController?,
		StaminaController = nil,
		HungerController = nil,
		BodyFatigueController = nil,
		TrainingController = nil,
		DamageModifiers = {},
		AttackModifiers = {},
		HealingModifiers = {},
		StaminaCostModifiers = {},
		SpeedModifiers = {},
	}, CharacterController) :: ControllerType

	self.StateManager = StateManager.new(Character)
	self.StatManager = StatManager.new(Character, PlayerData)
	self.HookController = HookController.new(self)

	self.Maid:GiveTask(self.StateManager)
	self.Maid:GiveTask(self.StatManager)
	self.Maid:GiveTask(self.HookController)

	Character:SetAttribute("HasController", true)
	Controllers[Character] = self

	StateHandlers.Setup(self)
	self:SetupHumanoidStateTracking()

	if IsPlayer then
		self.BodyFatigueController = BodyFatigueController.new(self, PlayerData)
		self.StaminaController = StaminaController.new(self)
		self.HungerController = HungerController.new(self)
		self.TrainingController = TrainingController.new(self, PlayerData)

		self.Maid:GiveTask(self.BodyFatigueController)
		self.Maid:GiveTask(self.StaminaController)
		self.Maid:GiveTask(self.HungerController)
		self.Maid:GiveTask(self.TrainingController)

		self:SetupMovementTracking()
	end

	self.Maid:GiveTask(self.Humanoid.Died:Connect(function()
		self:Destroy()
	end))

	return self
end

function CharacterController:SetupHumanoidStateTracking()
	local Humanoid = self.Humanoid

	self.Maid:GiveTask(RunService.Heartbeat:Connect(function(DeltaTime)
		if self.BodyFatigueController then
			self.BodyFatigueController:Update(DeltaTime)
		end

		if self.HungerController then
			self.HungerController:Update()
		end

		if self.TrainingController then
			self.TrainingController:ProcessTraining(DeltaTime)
		end
	end))

	local IsInAir = false

	self.Maid:GiveTask(Humanoid.StateChanged:Connect(function(_, NewState)
		if NewState == Enum.HumanoidStateType.Jumping or NewState == Enum.HumanoidStateType.Freefall then
			if not IsInAir then
				IsInAir = true
				self.StateManager:SetState(StateTypes.JUMPING, true)
			end
		elseif NewState == Enum.HumanoidStateType.Landed or NewState == Enum.HumanoidStateType.Running then
			if IsInAir then
				IsInAir = false
				self.StateManager:SetState(StateTypes.JUMPING, false)
				self.StateManager:SetState(StateTypes.FALLING, false)
			end
		end

		if NewState == Enum.HumanoidStateType.Freefall then
			self.StateManager:SetState(StateTypes.FALLING, true)
		end
	end))
end

function CharacterController:SetupMovementTracking()
	if not self.IsPlayer or not self.StaminaController then
		return
	end

	local Player = Players:GetPlayerFromCharacter(self.Character)
	if not Player then
		return
	end

	self.Maid:GiveTask(self.Character:GetAttributeChangedSignal("MovementMode"):Connect(function()
		local CurrentMode = self.Character:GetAttribute("MovementMode")

		self.Maid:Set("MovementTraining", nil)

		if CurrentMode == "run" then
			self:HandleSprintMode()
		elseif CurrentMode == "jog" then
			self:HandleJogMode()
		else
			self:HandleWalkMode()
		end
	end))
end

function CharacterController:HandleSprintMode()
	self.StateManager:SetState(StateTypes.SPRINTING, true)
	self.StateManager:SetState(StateTypes.JOGGING, false)
	self.StateManager:FireEvent("SprintStarted", {})

	local SprintConnection = RunService.Heartbeat:Connect(function(DeltaTime)
		local IsMoving = self.Character.PrimaryPart.AssemblyLinearVelocity.Magnitude > 1

		if IsMoving and self.StaminaController then
			local Success = self.StaminaController:HandleSprint(DeltaTime)

			if not Success then
				self.Character:SetAttribute("MovementMode", "walk")
				self.StateManager:SetState(StateTypes.SPRINTING, false)
				self.StateManager:FireEvent("SprintStopped", {})
				self.StateManager:FireEvent("StaminaDepleted", {})
			else
				if self.TrainingController and self.TrainingController:CanTrain() then
					local RunSpeedXP = 15 * DeltaTime
					local FatigueGain = 0.5 * 0.7
					self.TrainingController:GrantStatGain(StatTypes.RUN_SPEED, RunSpeedXP, FatigueGain)
				end
			end
		end
	end)

	self.Maid:Set("MovementTraining", SprintConnection)
end

function CharacterController:HandleJogMode()
	self.StateManager:SetState(StateTypes.JOGGING, true)
	self.StateManager:SetState(StateTypes.SPRINTING, false)
	self.StateManager:FireEvent("JogStarted", {})

	local JogConnection = RunService.Heartbeat:Connect(function(DeltaTime)
		local IsMoving = self.Character.PrimaryPart.AssemblyLinearVelocity.Magnitude > 1

		if IsMoving and self.StaminaController then
			local Success = self.StaminaController:HandleJog(DeltaTime)

			if not Success then
				self.Character:SetAttribute("MovementMode", "walk")
				self.StateManager:SetState(StateTypes.JOGGING, false)
				self.StateManager:FireEvent("JogStopped", {})
				self.StateManager:FireEvent("StaminaDepleted", {})
			else
				if self.TrainingController and self.TrainingController:CanTrain() then
					local StaminaXP = 0.185 * DeltaTime
					local FatigueGain = 0.5 * 0.8
					self.TrainingController:GrantStatGain(StatTypes.MAX_STAMINA, StaminaXP, FatigueGain)
				end
			end
		end
	end)

	self.Maid:Set("MovementTraining", JogConnection)
end

function CharacterController:HandleWalkMode()
	local WasSprinting = self.StateManager:GetState(StateTypes.SPRINTING)
	local WasJogging = self.StateManager:GetState(StateTypes.JOGGING)

	if WasSprinting then
		self.StateManager:FireEvent("SprintStopped", {})
	end

	if WasJogging then
		self.StateManager:FireEvent("JogStopped", {})
	end

	self.StateManager:SetState(StateTypes.SPRINTING, false)
	self.StateManager:SetState(StateTypes.JOGGING, false)
end

function CharacterController:TakeDamage(Damage: number, Source: Player?, Direction: Vector3?)
	local ModifiedDamage = Damage

	for _, Entry in self.DamageModifiers do
		ModifiedDamage = Entry.Modifier(ModifiedDamage, {
			Source = Source,
			Direction = Direction,
			OriginalDamage = Damage,
		})
	end

	if self.StateManager:GetState(StateTypes.INVULNERABLE) then
		return
	end

	if self.StateManager:GetState(StateTypes.BLOCKING) then
		local CombatBalance = require(Shared.Configurations.Balance.CombatBalance)
		ModifiedDamage = ModifiedDamage * (1 - CombatBalance.Blocking.DAMAGE_REDUCTION)
	end

	self.Humanoid.Health -= ModifiedDamage

	self.StateManager:FireEvent("DamageTaken", {
		Amount = ModifiedDamage,
		Source = Source,
		Direction = Direction,
		WasBlocked = self.StateManager:GetState(StateTypes.BLOCKING),
		HealthPercent = self.Humanoid.Health / self.Humanoid.MaxHealth,
	})
end

function CharacterController:SetStates(StatesToSet: {[string]: boolean})
	for StateName, Value in StatesToSet do
		self.StateManager:SetState(StateName, Value)
	end
end

function CharacterController:RegisterDamageModifier(Priority: number, Modifier: DamageModifier)
	local Entry = {Priority = Priority, Modifier = Modifier}
	table.insert(self.DamageModifiers, Entry)
	table.sort(self.DamageModifiers, function(A, B)
		return A.Priority > B.Priority
	end)

	return function()
		local Index = table.find(self.DamageModifiers, Entry)
		if Index then
			table.remove(self.DamageModifiers, Index)
		end
	end
end

function CharacterController:RegisterAttackModifier(Priority: number, Modifier: DamageModifier)
	local Entry = {Priority = Priority, Modifier = Modifier}
	table.insert(self.AttackModifiers, Entry)
	table.sort(self.AttackModifiers, function(A, B)
		return A.Priority > B.Priority
	end)

	return function()
		local Index = table.find(self.AttackModifiers, Entry)
		if Index then
			table.remove(self.AttackModifiers, Index)
		end
	end
end

function CharacterController:RegisterHealingModifier(Priority: number, Modifier: HealingModifier)
	local Entry = {Priority = Priority, Modifier = Modifier}
	table.insert(self.HealingModifiers, Entry)
	table.sort(self.HealingModifiers, function(A, B)
		return A.Priority > B.Priority
	end)

	return function()
		local Index = table.find(self.HealingModifiers, Entry)
		if Index then
			table.remove(self.HealingModifiers, Index)
		end
	end
end

function CharacterController:RegisterStaminaCostModifier(Priority: number, Modifier: StaminaCostModifier)
	local Entry = {Priority = Priority, Modifier = Modifier}
	table.insert(self.StaminaCostModifiers, Entry)
	table.sort(self.StaminaCostModifiers, function(A, B)
		return A.Priority > B.Priority
	end)

	return function()
		local Index = table.find(self.StaminaCostModifiers, Entry)
		if Index then
			table.remove(self.StaminaCostModifiers, Index)
		end
	end
end

function CharacterController:RegisterSpeedModifier(Priority: number, Modifier: SpeedModifier)
	local Entry = {Priority = Priority, Modifier = Modifier}
	table.insert(self.SpeedModifiers, Entry)
	table.sort(self.SpeedModifiers, function(A, B)
		return A.Priority > B.Priority
	end)

	return function()
		local Index = table.find(self.SpeedModifiers, Entry)
		if Index then
			table.remove(self.SpeedModifiers, Index)
		end
	end
end

function CharacterController:GetDebugInfo(): {[string]: any}
	local ActiveStates = {}
	for StateName in StateTypes do
		if self.StateManager:GetState(StateName) then
			table.insert(ActiveStates, StateName)
		end
	end

	return {
		CharacterName = self.Character.Name,
		IsPlayer = self.IsPlayer,
		Health = string.format("%.1f/%.1f", self.Humanoid.Health, self.Humanoid.MaxHealth),
		ActiveStates = ActiveStates,
		ModifierCounts = {
			Damage = #self.DamageModifiers,
			Attack = #self.AttackModifiers,
			Healing = #self.HealingModifiers,
			StaminaCost = #self.StaminaCostModifiers,
			Speed = #self.SpeedModifiers,
		},
	}
end

function CharacterController:Destroy()
	self.Maid:DoCleaning()
	Controllers[self.Character] = nil
end

function CharacterController.Get(Character: Model): ControllerType?
	return Controllers[Character]
end

return CharacterController