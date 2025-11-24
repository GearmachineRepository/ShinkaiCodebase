local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")
local Pose = "Standing"

local UserNoUpdateOnLoopSuccess, UserNoUpdateOnLoopValue = pcall(function() return UserSettings():IsUserFeatureEnabled("UserNoUpdateOnLoop") end)
local UserNoUpdateOnLoop = UserNoUpdateOnLoopSuccess and UserNoUpdateOnLoopValue

local UserAnimateScaleRunSuccess, UserAnimateScaleRunValue = pcall(function() return UserSettings():IsUserFeatureEnabled("UserAnimateScaleRun") end)
local UserAnimateScaleRun = UserAnimateScaleRunSuccess and UserAnimateScaleRunValue

local function GetRigScale()
	if UserAnimateScaleRun then
		return Character:GetScale()
	else
		return 1
	end
end

local AnimationSpeedDampeningObject = script:FindFirstChild("ScaleDampeningPercent")
local HumanoidHipHeight = 2

local EMOTE_TRANSITION_TIME = 0.1
local MOVEMENT_TRANSITION_TIME = 0.2

local CurrentAnim = ""
local CurrentAnimInstance = nil
local CurrentAnimTrack = nil
local CurrentAnimKeyframeHandler = nil
local CurrentAnimSpeed = 1.0

local RunAnimTrack = nil
local RunAnimKeyframeHandler = nil
local JogAnimTrack = nil
local JogAnimKeyframeHandler = nil

local PreloadedAnims = {}

local AnimTable = {}
local AnimNames = { 
	idle = {	
		{ id = "http://www.roblox.com/asset/?id=507766666", weight = 1 },
		{ id = "http://www.roblox.com/asset/?id=507766951", weight = 1 },
		{ id = "http://www.roblox.com/asset/?id=507766388", weight = 9 }
	},
	walk = { 	
		{ id = "rbxassetid://127837729576102", weight = 10 } 
	}, 
	jog = {
		{ id = "rbxassetid://115879642640033", weight = 10 } 
	},
	run = {
		{ id = "rbxassetid://86787802794828", weight = 10 } 
	},
	swim = {
		{ id = "http://www.roblox.com/asset/?id=507784897", weight = 10 } 
	}, 
	swimidle = {
		{ id = "http://www.roblox.com/asset/?id=507785072", weight = 10 } 
	}, 
	jump = {
		{ id = "http://www.roblox.com/asset/?id=507765000", weight = 10 } 
	}, 
	fall = {
		{ id = "http://www.roblox.com/asset/?id=507767968", weight = 10 } 
	}, 
	climb = {
		{ id = "http://www.roblox.com/asset/?id=507765644", weight = 10 } 
	}, 
	sit = {
		{ id = "http://www.roblox.com/asset/?id=2506281703", weight = 10 } 
	},	
	toolnone = {
		{ id = "http://www.roblox.com/asset/?id=507768375", weight = 10 } 
	},
	toolslash = {
		{ id = "http://www.roblox.com/asset/?id=522635514", weight = 10 } 
	},
	toollunge = {
		{ id = "http://www.roblox.com/asset/?id=522638767", weight = 10 } 
	},
	wave = {
		{ id = "http://www.roblox.com/asset/?id=507770239", weight = 10 } 
	},
	point = {
		{ id = "http://www.roblox.com/asset/?id=507770453", weight = 10 } 
	},
	dance = {
		{ id = "http://www.roblox.com/asset/?id=507771019", weight = 10 }, 
		{ id = "http://www.roblox.com/asset/?id=507771955", weight = 10 }, 
		{ id = "http://www.roblox.com/asset/?id=507772104", weight = 10 } 
	},
	dance2 = {
		{ id = "http://www.roblox.com/asset/?id=507776043", weight = 10 }, 
		{ id = "http://www.roblox.com/asset/?id=507776720", weight = 10 }, 
		{ id = "http://www.roblox.com/asset/?id=507776879", weight = 10 } 
	},
	dance3 = {
		{ id = "http://www.roblox.com/asset/?id=507777268", weight = 10 }, 
		{ id = "http://www.roblox.com/asset/?id=507777451", weight = 10 }, 
		{ id = "http://www.roblox.com/asset/?id=507777623", weight = 10 } 
	},
	laugh = {
		{ id = "http://www.roblox.com/asset/?id=507770818", weight = 10 } 
	},
	cheer = {
		{ id = "http://www.roblox.com/asset/?id=507770677", weight = 10 } 
	},
}

local EmoteNames = { wave = false, point = false, dance = true, dance2 = true, dance3 = true, laugh = false, cheer = false}

math.randomseed(tick())

function FindExistingAnimationInSet(set, anim)
	if set == nil or anim == nil then
		return 0
	end

	for idx = 1, set.count, 1 do 
		if set[idx].anim.AnimationId == anim.AnimationId then
			return idx
		end
	end

	return 0
end

function ConfigureAnimationSet(name, fileList)
	if AnimTable[name] ~= nil then
		for _, connection in pairs(AnimTable[name].connections) do
			connection:disconnect()
		end
	end
	AnimTable[name] = {}
	AnimTable[name].count = 0
	AnimTable[name].totalWeight = 0	
	AnimTable[name].connections = {}

	local AllowCustomAnimations = true

	local Success, ErrorMessage = pcall(function() AllowCustomAnimations = game:GetService("StarterPlayer").AllowCustomAnimations end)
	if not Success then
		AllowCustomAnimations = true
	end

	local Config = script:FindFirstChild(name)
	if AllowCustomAnimations and Config ~= nil then
		table.insert(AnimTable[name].connections, Config.ChildAdded:connect(function(child) ConfigureAnimationSet(name, fileList) end))
		table.insert(AnimTable[name].connections, Config.ChildRemoved:connect(function(child) ConfigureAnimationSet(name, fileList) end))

		local Index = 0
		for _, childPart in pairs(Config:GetChildren()) do
			if childPart:IsA("Animation") then
				local NewWeight = 1
				local WeightObject = childPart:FindFirstChild("Weight")
				if WeightObject ~= nil then
					NewWeight = WeightObject.Value
				end
				AnimTable[name].count = AnimTable[name].count + 1
				Index = AnimTable[name].count
				AnimTable[name][Index] = {}
				AnimTable[name][Index].anim = childPart
				AnimTable[name][Index].weight = NewWeight
				AnimTable[name].totalWeight = AnimTable[name].totalWeight + AnimTable[name][Index].weight
				table.insert(AnimTable[name].connections, childPart.Changed:connect(function(property) ConfigureAnimationSet(name, fileList) end))
				table.insert(AnimTable[name].connections, childPart.ChildAdded:connect(function(property) ConfigureAnimationSet(name, fileList) end))
				table.insert(AnimTable[name].connections, childPart.ChildRemoved:connect(function(property) ConfigureAnimationSet(name, fileList) end))
			end
		end
	end

	if AnimTable[name].count <= 0 then
		for idx, anim in pairs(fileList) do
			AnimTable[name][idx] = {}
			AnimTable[name][idx].anim = Instance.new("Animation")
			AnimTable[name][idx].anim.Name = name
			AnimTable[name][idx].anim.AnimationId = anim.id
			AnimTable[name][idx].weight = anim.weight
			AnimTable[name].count = AnimTable[name].count + 1
			AnimTable[name].totalWeight = AnimTable[name].totalWeight + anim.weight
		end
	end

	for animTypeKey, animType in pairs(AnimTable) do
		for idx = 1, animType.count, 1 do
			if PreloadedAnims[animType[idx].anim.AnimationId] == nil then
				Humanoid:LoadAnimation(animType[idx].anim)
				PreloadedAnims[animType[idx].anim.AnimationId] = true
			end				
		end
	end
end

function ScriptChildModified(child)
	local FileList = AnimNames[child.Name]
	if FileList ~= nil then
		ConfigureAnimationSet(child.Name, FileList)
	end	
end

script.ChildAdded:connect(ScriptChildModified)
script.ChildRemoved:connect(ScriptChildModified)

local Animator = if Humanoid then Humanoid:FindFirstChildOfClass("Animator") else nil
if Animator then
	local AnimTracks = Animator:GetPlayingAnimationTracks()
	for trackIndex, track in ipairs(AnimTracks) do
		track:Stop(0)
		track:Destroy()
	end
end

for name, fileList in pairs(AnimNames) do 
	ConfigureAnimationSet(name, fileList)
end	

local ToolAnim = "None"
local ToolAnimTime = 0

local JumpAnimTime = 0
local JumpAnimDuration = 0.31

local ToolTransitionTime = 0.1
local FallTransitionTime = 0.2

local CurrentlyPlayingEmote = false
local CurrentMovementMode = "walk"

function StopAllAnimations()
	local OldAnim = CurrentAnim

	if EmoteNames[OldAnim] ~= nil and EmoteNames[OldAnim] == false then
		OldAnim = "idle"
	end

	if CurrentlyPlayingEmote then
		OldAnim = "idle"
		CurrentlyPlayingEmote = false
	end

	CurrentAnim = ""
	CurrentAnimInstance = nil
	if CurrentAnimKeyframeHandler ~= nil then
		CurrentAnimKeyframeHandler:disconnect()
	end

	if CurrentAnimTrack ~= nil then
		CurrentAnimTrack:Stop()
		CurrentAnimTrack:Destroy()
		CurrentAnimTrack = nil
	end

	if RunAnimKeyframeHandler ~= nil then
		RunAnimKeyframeHandler:disconnect()
	end

	if RunAnimTrack ~= nil then
		RunAnimTrack:Stop()
		RunAnimTrack:Destroy()
		RunAnimTrack = nil
	end

	if JogAnimTrack ~= nil then
		JogAnimTrack:Stop()
		JogAnimTrack:Destroy()
		JogAnimTrack = nil
	end

	return OldAnim
end

function GetHeightScale()
	if Humanoid then
		if not Humanoid.AutomaticScalingEnabled then
			return GetRigScale()
		end

		local Scale = Humanoid.HipHeight / HumanoidHipHeight
		if AnimationSpeedDampeningObject == nil then
			AnimationSpeedDampeningObject = script:FindFirstChild("ScaleDampeningPercent")
		end
		if AnimationSpeedDampeningObject ~= nil then
			Scale = 1 + (Humanoid.HipHeight - HumanoidHipHeight) * AnimationSpeedDampeningObject.Value / HumanoidHipHeight
		end
		return Scale
	end	
	return GetRigScale()
end

local SMALL_BUT_NOT_ZERO = 0.0001
local function SetRunSpeed(speed)
	local BaseWalkSpeed = 9
	local BaseJogSpeed = 18
	local BaseRunSpeed = 28

	local WalkAnimationWeight = SMALL_BUT_NOT_ZERO
	local JogAnimationWeight = SMALL_BUT_NOT_ZERO
	local RunAnimationWeight = SMALL_BUT_NOT_ZERO
	local TimeWarp = 1

	local MovementState = Humanoid:GetAttribute("MovementMode") or "walk"
	CurrentMovementMode = MovementState

	if MovementState == "walk" then
		WalkAnimationWeight = 1
		TimeWarp = speed / BaseWalkSpeed

		if JogAnimTrack then
			JogAnimTrack:Stop(MOVEMENT_TRANSITION_TIME)
			JogAnimTrack:Destroy()
			JogAnimTrack = nil
		end
		if RunAnimTrack then
			RunAnimTrack:Stop(MOVEMENT_TRANSITION_TIME)
			RunAnimTrack:Destroy()
			RunAnimTrack = nil
		end
	elseif MovementState == "jog" then
		if not JogAnimTrack then
			local JogIndex = RollAnimation("jog")
			JogAnimTrack = Humanoid:LoadAnimation(AnimTable["jog"][JogIndex].anim)
			JogAnimTrack.Priority = Enum.AnimationPriority.Core
			JogAnimTrack:Play(MOVEMENT_TRANSITION_TIME)
		end

		JogAnimationWeight = 1
		TimeWarp = speed / BaseJogSpeed

		if CurrentAnimTrack then
			CurrentAnimTrack:Stop(MOVEMENT_TRANSITION_TIME)
		end
		if RunAnimTrack then
			RunAnimTrack:Stop(MOVEMENT_TRANSITION_TIME)
			RunAnimTrack:Destroy()
			RunAnimTrack = nil
		end

		if JogAnimTrack then
			JogAnimTrack:AdjustWeight(JogAnimationWeight)
			JogAnimTrack:AdjustSpeed(TimeWarp)
		end
		return
	elseif MovementState == "run" then
		if not RunAnimTrack then
			local RunIndex = RollAnimation("run")
			RunAnimTrack = Humanoid:LoadAnimation(AnimTable["run"][RunIndex].anim)
			RunAnimTrack.Priority = Enum.AnimationPriority.Core
			RunAnimTrack:Play(MOVEMENT_TRANSITION_TIME)
		end

		RunAnimationWeight = 1
		TimeWarp = speed / BaseRunSpeed

		if CurrentAnimTrack then
			CurrentAnimTrack:Stop(MOVEMENT_TRANSITION_TIME)
		end
		if JogAnimTrack then
			JogAnimTrack:Stop(MOVEMENT_TRANSITION_TIME)
			JogAnimTrack:Destroy()
			JogAnimTrack = nil
		end

		if RunAnimTrack then
			RunAnimTrack:AdjustWeight(RunAnimationWeight)
			RunAnimTrack:AdjustSpeed(TimeWarp)
		end
		return
	end

	if CurrentAnimTrack then
		CurrentAnimTrack:AdjustWeight(WalkAnimationWeight)
		CurrentAnimTrack:AdjustSpeed(TimeWarp)
	end
end

function SetAnimationSpeed(speed)
	if CurrentAnim == "walk" then
		SetRunSpeed(speed)
	else
		if speed ~= CurrentAnimSpeed then
			CurrentAnimSpeed = speed
			if CurrentAnimTrack then
				CurrentAnimTrack:AdjustSpeed(CurrentAnimSpeed)
			end
		end
	end
end

function KeyFrameReachedFunc(frameName)
	if frameName == "End" then
		if CurrentAnim == "walk" then
			if UserNoUpdateOnLoop == true then
				if RunAnimTrack and RunAnimTrack.Looped ~= true then
					RunAnimTrack.TimePosition = 0.0
				end
				if JogAnimTrack and JogAnimTrack.Looped ~= true then
					JogAnimTrack.TimePosition = 0.0
				end
				if CurrentAnimTrack and CurrentAnimTrack.Looped ~= true then
					CurrentAnimTrack.TimePosition = 0.0
				end
			else
				if RunAnimTrack then
					RunAnimTrack.TimePosition = 0.0
				end
				if JogAnimTrack then
					JogAnimTrack.TimePosition = 0.0
				end
				if CurrentAnimTrack then
					CurrentAnimTrack.TimePosition = 0.0
				end
			end
		else
			local RepeatAnim = CurrentAnim
			if EmoteNames[RepeatAnim] ~= nil and EmoteNames[RepeatAnim] == false then
				RepeatAnim = "idle"
			end

			if CurrentlyPlayingEmote then
				if CurrentAnimTrack.Looped then
					return
				end

				RepeatAnim = "idle"
				CurrentlyPlayingEmote = false
			end

			local AnimSpeed = CurrentAnimSpeed
			PlayAnimation(RepeatAnim, 0.15, Humanoid)
			SetAnimationSpeed(AnimSpeed)
		end
	end
end

function RollAnimation(animName)
	local Roll = math.random(1, AnimTable[animName].totalWeight) 
	local Index = 1
	while Roll > AnimTable[animName][Index].weight do
		Roll = Roll - AnimTable[animName][Index].weight
		Index = Index + 1
	end
	return Index
end

local function SwitchToAnim(anim, animName, transitionTime, humanoid)
	if anim ~= CurrentAnimInstance then

		if CurrentAnimTrack ~= nil then
			CurrentAnimTrack:Stop(transitionTime)
			CurrentAnimTrack:Destroy()
		end

		if RunAnimTrack ~= nil then
			RunAnimTrack:Stop(transitionTime)
			RunAnimTrack:Destroy()
			if UserNoUpdateOnLoop == true then
				RunAnimTrack = nil
			end
		end

		if JogAnimTrack ~= nil then
			JogAnimTrack:Stop(transitionTime)
			JogAnimTrack:Destroy()
			JogAnimTrack = nil
		end

		CurrentAnimSpeed = 1.0

		CurrentAnimTrack = humanoid:LoadAnimation(anim)
		CurrentAnimTrack.Priority = Enum.AnimationPriority.Core

		CurrentAnimTrack:Play(transitionTime)
		CurrentAnim = animName
		CurrentAnimInstance = anim

		if CurrentAnimKeyframeHandler ~= nil then
			CurrentAnimKeyframeHandler:disconnect()
		end
		CurrentAnimKeyframeHandler = CurrentAnimTrack.KeyframeReached:connect(KeyFrameReachedFunc)

		if animName == "walk" then
			local MovementState = Humanoid:GetAttribute("MovementMode") or "walk"

			if MovementState == "jog" then
				local JogIndex = RollAnimation("jog")
				JogAnimTrack = humanoid:LoadAnimation(AnimTable["jog"][JogIndex].anim)
				JogAnimTrack.Priority = Enum.AnimationPriority.Core
				JogAnimTrack:Play(transitionTime)
			elseif MovementState == "run" then
				local RunIndex = RollAnimation("run")
				RunAnimTrack = humanoid:LoadAnimation(AnimTable["run"][RunIndex].anim)
				RunAnimTrack.Priority = Enum.AnimationPriority.Core
				RunAnimTrack:Play(transitionTime)
			end
		end
	end
end

function PlayAnimation(animName, transitionTime, humanoid) 	
	local Index = RollAnimation(animName)
	local Anim = AnimTable[animName][Index].anim

	SwitchToAnim(Anim, animName, transitionTime, humanoid)
	CurrentlyPlayingEmote = false
end

function PlayEmote(emoteAnim, transitionTime, humanoid)
	SwitchToAnim(emoteAnim, emoteAnim.Name, transitionTime, humanoid)
	CurrentlyPlayingEmote = true
end

local ToolAnimName = ""
local ToolAnimTrack = nil
local ToolAnimInstance = nil
local CurrentToolAnimKeyframeHandler = nil

function ToolKeyFrameReachedFunc(frameName)
	if frameName == "End" then
		PlayToolAnimation(ToolAnimName, 0.0, Humanoid)
	end
end

function PlayToolAnimation(animName, transitionTime, humanoid, priority)	 		
	local Index = RollAnimation(animName)
	local Anim = AnimTable[animName][Index].anim

	if ToolAnimInstance ~= Anim then

		if ToolAnimTrack ~= nil then
			ToolAnimTrack:Stop()
			ToolAnimTrack:Destroy()
			transitionTime = 0
		end

		ToolAnimTrack = humanoid:LoadAnimation(Anim)
		if priority then
			ToolAnimTrack.Priority = priority
		end

		ToolAnimTrack:Play(transitionTime)
		ToolAnimName = animName
		ToolAnimInstance = Anim

		CurrentToolAnimKeyframeHandler = ToolAnimTrack.KeyframeReached:connect(ToolKeyFrameReachedFunc)
	end
end

function StopToolAnimations()
	local OldAnim = ToolAnimName

	if CurrentToolAnimKeyframeHandler ~= nil then
		CurrentToolAnimKeyframeHandler:disconnect()
	end

	ToolAnimName = ""
	ToolAnimInstance = nil
	if ToolAnimTrack ~= nil then
		ToolAnimTrack:Stop()
		ToolAnimTrack:Destroy()
		ToolAnimTrack = nil
	end

	return OldAnim
end

function OnRunning(speed)
	local HeightScale = if UserAnimateScaleRun then GetHeightScale() else 1

	local MovedDuringEmote = CurrentlyPlayingEmote and Humanoid.MoveDirection == Vector3.new(0, 0, 0)
	local SpeedThreshold = MovedDuringEmote and (Humanoid.WalkSpeed / HeightScale) or 0.75

	if speed > SpeedThreshold * HeightScale then
		PlayAnimation("walk", MOVEMENT_TRANSITION_TIME, Humanoid)
		SetAnimationSpeed(speed)
		Pose = "Running"
	else
		if EmoteNames[CurrentAnim] == nil and not CurrentlyPlayingEmote then
			PlayAnimation("idle", 0.2, Humanoid)
			Pose = "Standing"
		end
	end
end

function OnDied()
	Pose = "Dead"
end

function OnJumping()
	PlayAnimation("jump", 0.1, Humanoid)
	JumpAnimTime = JumpAnimDuration
	Pose = "Jumping"
end

function OnClimbing(speed)
	if UserAnimateScaleRun then
		speed /= GetHeightScale()
	end
	local Scale = 5.0
	PlayAnimation("climb", 0.1, Humanoid)
	SetAnimationSpeed(speed / Scale)
	Pose = "Climbing"
end

function OnGettingUp()
	Pose = "GettingUp"
end

function OnFreeFall()
	if JumpAnimTime <= 0 then
		PlayAnimation("fall", FallTransitionTime, Humanoid)
	end
	Pose = "FreeFall"
end

function OnFallingDown()
	Pose = "FallingDown"
end

function OnSeated()
	Pose = "Seated"
end

function OnPlatformStanding()
	Pose = "PlatformStanding"
end

function OnSwimming(speed)
	if UserAnimateScaleRun then
		speed /= GetHeightScale()
	end
	if speed > 1.00 then
		local Scale = 10.0
		PlayAnimation("swim", 0.4, Humanoid)
		SetAnimationSpeed(speed / Scale)
		Pose = "Swimming"
	else
		PlayAnimation("swimidle", 0.4, Humanoid)
		Pose = "Standing"
	end
end

function AnimateTool()
	if ToolAnim == "None" then
		PlayToolAnimation("toolnone", ToolTransitionTime, Humanoid, Enum.AnimationPriority.Idle)
		return
	end

	if ToolAnim == "Slash" then
		PlayToolAnimation("toolslash", 0, Humanoid, Enum.AnimationPriority.Action)
		return
	end

	if ToolAnim == "Lunge" then
		PlayToolAnimation("toollunge", 0, Humanoid, Enum.AnimationPriority.Action)
		return
	end
end

function GetToolAnim(tool)
	for _, child in ipairs(tool:GetChildren()) do
		if child.Name == "toolanim" and child.className == "StringValue" then
			return child
		end
	end
	return nil
end

local LastTick = 0

function StepAnimate(currentTime)
	local Amplitude = 1
	local Frequency = 1
	local DeltaTime = currentTime - LastTick
	LastTick = currentTime

	local ClimbFudge = 0
	local SetAngles = false

	if JumpAnimTime > 0 then
		JumpAnimTime = JumpAnimTime - DeltaTime
	end

	if Pose == "FreeFall" and JumpAnimTime <= 0 then
		PlayAnimation("fall", FallTransitionTime, Humanoid)
	elseif Pose == "Seated" then
		PlayAnimation("sit", 0.5, Humanoid)
		return
	elseif Pose == "Running" then
		PlayAnimation("walk", MOVEMENT_TRANSITION_TIME, Humanoid)
	elseif Pose == "Dead" or Pose == "GettingUp" or Pose == "FallingDown" or Pose == "Seated" or Pose == "PlatformStanding" then
		StopAllAnimations()
		Amplitude = 0.1
		Frequency = 1
		SetAngles = true
	end

	local Tool = Character:FindFirstChildOfClass("Tool")
	if Tool and Tool:FindFirstChild("Handle") then
		local AnimStringValueObject = GetToolAnim(Tool)

		if AnimStringValueObject then
			ToolAnim = AnimStringValueObject.Value
			AnimStringValueObject.Parent = nil
			ToolAnimTime = currentTime + .3
		end

		if currentTime > ToolAnimTime then
			ToolAnimTime = 0
			ToolAnim = "None"
		end

		AnimateTool()		
	else
		StopToolAnimations()
		ToolAnim = "None"
		ToolAnimInstance = nil
		ToolAnimTime = 0
	end
end

Humanoid:GetAttributeChangedSignal("MovementMode"):Connect(function()
	if Pose == "Running" then
		local Speed = Humanoid.WalkSpeed
		SetRunSpeed(Speed)
	end
end)

Humanoid.Died:connect(OnDied)
Humanoid.Running:connect(OnRunning)
Humanoid.Jumping:connect(OnJumping)
Humanoid.Climbing:connect(OnClimbing)
Humanoid.GettingUp:connect(OnGettingUp)
Humanoid.FreeFalling:connect(OnFreeFall)
Humanoid.FallingDown:connect(OnFallingDown)
Humanoid.Seated:connect(OnSeated)
Humanoid.PlatformStanding:connect(OnPlatformStanding)
Humanoid.Swimming:connect(OnSwimming)

game:GetService("Players").LocalPlayer.Chatted:connect(function(msg)
	local Emote = ""
	if string.sub(msg, 1, 3) == "/e " then
		Emote = string.sub(msg, 4)
	elseif string.sub(msg, 1, 7) == "/emote " then
		Emote = string.sub(msg, 8)
	end

	if Pose == "Standing" and EmoteNames[Emote] ~= nil then
		PlayAnimation(Emote, EMOTE_TRANSITION_TIME, Humanoid)
	end
end)

script:WaitForChild("PlayEmote").OnInvoke = function(emote)
	if Pose ~= "Standing" then
		return
	end

	if EmoteNames[emote] ~= nil then
		PlayAnimation(emote, EMOTE_TRANSITION_TIME, Humanoid)
		return true, CurrentAnimTrack
	elseif typeof(emote) == "Instance" and emote:IsA("Animation") then
		PlayEmote(emote, EMOTE_TRANSITION_TIME, Humanoid)
		return true, CurrentAnimTrack
	end

	return false
end

if Character.Parent ~= nil then
	PlayAnimation("idle", 0.1, Humanoid)
	Pose = "Standing"
end

while Character.Parent ~= nil do
	local _, CurrentGameTime = wait(0.1)
	StepAnimate(CurrentGameTime)
end