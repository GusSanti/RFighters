local ToggleMovementRemote = game.ReplicatedStorage.Events.Movement.ToggleMovement
local MovementReadyRemote = game.ReplicatedStorage.Events.Movement:WaitForChild("MovementReady", 10)

local localPlayer = game.Players.LocalPlayer

-- Aguarda o personagem com segurança
local character = localPlayer.Character
if not character or not character.Parent then
	character = localPlayer.CharacterAdded:Wait()
end

-- Aguarda cada parte individualmente com timeout explícito
local humanoid = character:WaitForChild('Humanoid', 15)
if not humanoid then
	warn("[Init] Humanoid não encontrado, aguardando CharacterAdded...")
	character = localPlayer.CharacterAdded:Wait()
	humanoid = character:WaitForChild('Humanoid', 15)
end

if not humanoid then
	warn("[Init] Humanoid ausente após CharacterAdded, abortando init do CombatClient")
	return
end

local animator = humanoid:WaitForChild('Animator', 10)
local humrp = character:WaitForChild('HumanoidRootPart', 15)

if not humrp then
	warn("[Init] HumanoidRootPart ainda não disponível, yield extra...")
	-- Força um yield e tenta de novo
	task.wait(1)
	humrp = character:WaitForChild('HumanoidRootPart', 10)
end

if not humrp then
	warn("[Init] HumanoidRootPart ausente, abortando init do CombatClient")
	return
end

local StateManager = require(game.ReplicatedStorage.StateManager.StateManager)
local StateEnum = require(game.ReplicatedStorage.StateManager.ENUM)
local CameraModule = require(game.ReplicatedStorage.Modules.CameraModule)
local InputManager = require(game.ReplicatedStorage.Modules.InputManager)
local CombatClient = require(game.ReplicatedStorage.CombatSystem.CombatClient)
local FightingHUD = require(game.ReplicatedStorage.UI.Systems.LocalQueue.FightingHUD)
local PlayerModule = require(localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
local EffectsReplicator = require(game.ReplicatedStorage.CombatSystem.EffectsReplicatorClient)
local EffectsHelper = require(game.ReplicatedStorage.CombatSystem.EffectsHelper)
local CombatUtils = require(game.ReplicatedStorage.CombatSystem.CombatUtils)

local DEBUG_COMBAT_CLIENT = false

local function debugWarn(...)
	if DEBUG_COMBAT_CLIENT then
		warn(...)
	end
end

local CombatRequests = game.ReplicatedStorage.CombatSystem.Events.ClientRequests
local PlayAnimationEvent = game.ReplicatedStorage.CombatSystem.Events.PlayAnimation
local ServerEvents = game.ReplicatedStorage.CombatSystem.Events.ServerEvents
local StateManagerUpdateEvent = game.ReplicatedStorage.StateManager.Remotes.UPDATE_EVENT
local TutorialComplete = game.ReplicatedStorage.Events:WaitForChild("TutorialComplete")
local CharacterSwapEvent = game.ReplicatedStorage.Events:WaitForChild("CharacterSwapped", 10)

local playerGui = localPlayer:WaitForChild("PlayerGui")
local MainUI = playerGui:WaitForChild("UI", 60)
if not MainUI then
	warn("[CombatClient] PlayerGui.UI not found; combat UI disabled")
	return
end

local FightingFrame = MainUI:WaitForChild("FightingFrame", 15)
if not FightingFrame then
	warn("[CombatClient] UI.FightingFrame not found; combat UI disabled")
	return
end

local MobileUI = FightingFrame:WaitForChild("MobileUI", 15)
if not MobileUI then
	warn("[CombatClient] FightingFrame.MobileUI not found; mobile combat UI disabled")
	return
end

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

-- Cria/busca o BindableEvent para comunicar estado de combate
local CombatStateEvent = game.ReplicatedStorage:FindFirstChild("CombatStateChanged")
if not CombatStateEvent then
	CombatStateEvent = Instance.new("BindableEvent")
	CombatStateEvent.Name = "CombatStateChanged"
	CombatStateEvent.Parent = game.ReplicatedStorage
end

-- ─────────────────────────────────────────────────────────────
-- CACHE DE ENUMS (evita indexar tabelas longas todo frame)
-- ─────────────────────────────────────────────────────────────
local ENUM_FULL_STUNNED    = StateEnum.STATES_ENUM.COMBAT_FULL_STUNNED
local ENUM_BEING_ATTACKED  = StateEnum.STATES_ENUM.COMBAT_BEING_ATTACKED
local ENUM_COUNTDOWN_STUN  = StateEnum.STATES_ENUM.COMBAT_COUNTDOWN_STUNNED
local ENUM_INSKILL         = StateEnum.STATES_ENUM.COMBAT_INSKILL
local ENUM_DISABLED_ROTATE = StateEnum.STATES_ENUM.COMBAT_DISABLED_AUTOROTATE

-- ─────────────────────────────────────────────────────────────
-- CACHE DE CÂMERA (evita indexar workspace todo frame)
-- ─────────────────────────────────────────────────────────────
local Camera = workspace.CurrentCamera

-- ─────────────────────────────────────────────────────────────
-- CACHE DE BOTÕES MOBILE (evita GetChildren() todo frame)
-- ─────────────────────────────────────────────────────────────
local IsMobile = UIS.TouchEnabled
local mobileButtons = {}
local mobileButtonOriginals = {}
local currentActionStates = {}
local StateCache

local UNAVAILABLE_BUTTON_COLOR = Color3.fromRGB(120, 120, 120)
local UNAVAILABLE_TEXT_COLOR = Color3.fromRGB(190, 190, 190)

local ACTION_TO_ABILITY_KEY = {
	SKILL1 = "Skill1",
	SKILL2 = "Skill2",
	ULTIMATE = "Ultimate",
}

local function rememberMobileButtonOriginals(button)
	if mobileButtonOriginals[button] then return end

	local label = button:FindFirstChildOfClass("TextLabel")
	mobileButtonOriginals[button] = {
		ImageColor3 = button.ImageColor3,
		ImageTransparency = button.ImageTransparency,
		TextColor3 = label and label.TextColor3 or nil,
		Size = button.Size,
	}
end

local function applyMobileButtonState(button)
	rememberMobileButtonOriginals(button)
	local original = mobileButtonOriginals[button]
	local canUse = currentActionStates[button.Name]

	if canUse == nil or canUse == true then
		button.ImageColor3 = original.ImageColor3
		button.ImageTransparency = original.ImageTransparency
	else
		button.ImageColor3 = UNAVAILABLE_BUTTON_COLOR
		button.ImageTransparency = math.max(original.ImageTransparency, 0.25)
	end

	local label = button:FindFirstChildOfClass("TextLabel")
	if label and original.TextColor3 then
		label.TextColor3 = (canUse == nil or canUse == true) and original.TextColor3 or UNAVAILABLE_TEXT_COLOR
	end
end

local function applyMobileActionStates()
	for _, button in mobileButtons do
		applyMobileButtonState(button)
	end
end

local function pulseMobileButton(action)
	local button = MobileUI:FindFirstChild(action)
	if not button or not button:IsA("GuiButton") then return end
	rememberMobileButtonOriginals(button)

	local original = mobileButtonOriginals[button]
	local shrinkSize = UDim2.new(
		original.Size.X.Scale * 0.92,
		original.Size.X.Offset,
		original.Size.Y.Scale * 0.92,
		original.Size.Y.Offset
	)

	TweenService:Create(button, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = shrinkSize,
	}):Play()
	task.delay(0.06, function()
		if button.Parent then
			TweenService:Create(button, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = original.Size,
			}):Play()
		end
	end)
end

local function shouldSuppressLocalInput()
	return StateCache[ENUM_FULL_STUNNED] or StateCache[ENUM_COUNTDOWN_STUN]
end

local function rebuildMobileButtonCache()
	mobileButtons = {}
	for _, b in MobileUI:GetChildren() do
		if b:IsA("ImageButton") then
			rememberMobileButtonOriginals(b)
			table.insert(mobileButtons, b)
		end
	end
	applyMobileActionStates()
end
rebuildMobileButtonCache()

-- Reconstrói o cache se botões forem adicionados/removidos
MobileUI.ChildAdded:Connect(rebuildMobileButtonCache)
MobileUI.ChildRemoved:Connect(rebuildMobileButtonCache)

local Controls = PlayerModule:GetControls()

local cameraConnection
local inputBeganConnection
local inputEndedConnection
local moveConnection
local touchTrackConnection
local touchBeganConnection
local touchEndedConnection
local landingConnection = nil -- FIX: rastreia conexão para evitar leak

local activeTracks = {}
StateCache = StateManager.GET()

local characterVisuals = nil
local playerLockingEnabled = false

local moveDir = 0
local wantJump = false
local hasJumped = false
local isAirborne = false
local combatActive = false

local WALK_SPEED = 13
local DASH_FORCE = 30
local DASH_TIME = 0.4
local Y_BOOST = 0

local mobileRight = false
local mobileLeft = false
local currentEnemyHRP
local crouchTrack = nil
local pendingControlsRestore = false
local gpMoveActive = false
local isCrouchingByGamepad = false
local THUMBSTICK_DEADZONE = 0.25
local gamepadConnection = nil
local gamepadButtonState = {}

local LANDING_EFFECT_TABLE = {
	Type = 'Emit',
	TargetCharacterBodyPart = 'Left Leg',
	Effect = game.ReplicatedStorage.CombatStorage.GlobalVFX.Land,
}
local LANDING_SOUND_TABLE = {
	Sound = game.ReplicatedStorage.CombatStorage.GlobalSFX.Land,
	TargetCharacterBodyPart = 'HumanoidRootPart',
}

local GAMEPAD_ACTION_MAP = {
	[Enum.KeyCode.ButtonA]   = "JUMP",
	[Enum.KeyCode.ButtonX]   = "LIGHTATK",
	[Enum.KeyCode.ButtonY]   = "HARDATK",
	[Enum.KeyCode.ButtonB]   = "CHARGEATK",
	[Enum.KeyCode.ButtonR1]  = "GRAB",
	[Enum.KeyCode.ButtonL1]  = "ULTIMATE",
	[Enum.KeyCode.ButtonL2]  = "BLOCK",
	[Enum.KeyCode.DPadRight] = "SKILL1",
	[Enum.KeyCode.DPadLeft]  = "SKILL2",
}

-- ─────────────────────────────────────────────────────────────
-- TUTORIAL
-- ─────────────────────────────────────────────────────────────

local TUTORIAL_STEPS = {
	{ text = "👋 Welcome! Let's learn how to fight.",  waitFor = nil },
	{ text = "➡️  Move to the RIGHT.",                 waitFor = "RIGHT" },
	{ text = "⬅️  Move to the LEFT.",                  waitFor = "LEFT" },
	{ text = "⬆️  JUMP!",                              waitFor = "JUMP" },
	{ text = "👊 Perform a LIGHT attack. (M1 or U)",   waitFor = "LIGHTATK" },
	{ text = "💥 Perform a MEDIUM attack. (M2 or I)",  waitFor = "HARDATK" },
	{ text = "💥 Perform a HEAVY attack. (Q or O)",    waitFor = "CHARGEATK" },
	{ text = "🛡️  BLOCK the attack. (F)",              waitFor = "BLOCK" },
	{ text = "⚡ Use DASH to escape. (Double Tap Left or Right)", waitFor = "DASH" },
	{ text = "✅ Tutorial complete! Good luck!",       waitFor = nil },
}

local tutorialActive = false
local tutorialStepIndex = 0
local tutorialWaitingFor = nil
local tutorialGui = nil
local tutorialLabel = nil
local tutorialFrame = nil
local tutorialFadeGui = nil
local tutorialFadeFrame = nil

local function setTutorialVisible(visible)
	if tutorialFrame then
		tutorialFrame.Visible = visible
	end
end

local function getTutorialFadeFrame()
	if tutorialFadeFrame then
		return tutorialFadeFrame
	end

	tutorialFadeGui = Instance.new("ScreenGui")
	tutorialFadeGui.Name = "TutorialCleanTeleportFade"
	tutorialFadeGui.ResetOnSpawn = false
	tutorialFadeGui.IgnoreGuiInset = true
	tutorialFadeGui.DisplayOrder = 1000
	tutorialFadeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	tutorialFadeGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Black"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = tutorialFadeGui

	tutorialFadeFrame = frame
	return tutorialFadeFrame
end

local function fadeTutorialTeleportIn()
	local frame = getTutorialFadeFrame()
	frame.BackgroundTransparency = 1
	frame.Visible = true

	local tween = TweenService:Create(
		frame,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0 }
	)
	tween:Play()
	tween.Completed:Wait()
end

local function fadeTutorialTeleportOut()
	if not tutorialFadeFrame then return end

	local frame = tutorialFadeFrame
	frame.Visible = true
	frame.BackgroundTransparency = 0

	local tween = TweenService:Create(
		frame,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Once(function()
		if tutorialFadeGui then
			tutorialFadeGui:Destroy()
			tutorialFadeGui = nil
			tutorialFadeFrame = nil
		end
	end)
end

local function onTutorialInput(action)
	if not tutorialActive then return end
	if not combatActive then return end
	if not tutorialWaitingFor then return end
	if action ~= tutorialWaitingFor then return end
	tutorialWaitingFor = nil
	task.delay(0.3, function()
		if tutorialActive then
			tutorialStepIndex += 1
		end
	end)
end

local function showTutorialText(text)
	if not tutorialGui then
		tutorialGui = Instance.new("ScreenGui")
		tutorialGui.Name = "TutorialGui"
		tutorialGui.ResetOnSpawn = false
		tutorialGui.IgnoreGuiInset = true
		tutorialGui.DisplayOrder = 80
		tutorialGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		tutorialGui.Parent = playerGui

		local container = Instance.new("Frame")
		container.Name = "TutorialPanel"
		container.Size = UDim2.new(0.62, 0, 0, 86)
		container.Position = UDim2.new(0.19, 0, 0.12, 0)
		container.BackgroundTransparency = 1
		container.BorderSizePixel = 0
		container.Parent = tutorialGui

		local shadow = Instance.new("Frame")
		shadow.Name = "Shadow"
		shadow.Size = UDim2.new(1, 12, 1, 12)
		shadow.Position = UDim2.new(0, 6, 0, 8)
		shadow.BackgroundColor3 = Color3.fromRGB(5, 7, 15)
		shadow.BackgroundTransparency = 0.38
		shadow.BorderSizePixel = 0
		shadow.ZIndex = 1
		shadow.Parent = container

		local shadowCorner = Instance.new("UICorner")
		shadowCorner.CornerRadius = UDim.new(0, 18)
		shadowCorner.Parent = shadow

		local frame = Instance.new("Frame")
		frame.Name = "Frame"
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundColor3 = Color3.fromRGB(17, 23, 46)
		frame.BackgroundTransparency = 0.04
		frame.BorderSizePixel = 0
		frame.ZIndex = 2
		frame.Parent = container

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 18)
		corner.Parent = frame

		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 47, 88)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(16, 24, 55)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(41, 16, 52)),
		})
		gradient.Rotation = 12
		gradient.Parent = frame

		local border = Instance.new("UIStroke")
		border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		border.Color = Color3.fromRGB(255, 205, 79)
		border.LineJoinMode = Enum.LineJoinMode.Round
		border.Thickness = 2
		border.Transparency = 0.08
		border.Parent = frame

		local accent = Instance.new("Frame")
		accent.Name = "Accent"
		accent.Size = UDim2.new(0, 9, 1, -18)
		accent.Position = UDim2.new(0, 12, 0, 9)
		accent.BackgroundColor3 = Color3.fromRGB(255, 204, 58)
		accent.BorderSizePixel = 0
		accent.ZIndex = 3
		accent.Parent = frame

		local accentCorner = Instance.new("UICorner")
		accentCorner.CornerRadius = UDim.new(1, 0)
		accentCorner.Parent = accent

		local accentGradient = Instance.new("UIGradient")
		accentGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 98)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 91, 91)),
		})
		accentGradient.Rotation = 90
		accentGradient.Parent = accent

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -58, 1, -10)
		label.Position = UDim2.new(0, 42, 0, 5)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.FontFace = Font.new("rbxasset://fonts/families/Bangers.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
		label.TextStrokeTransparency = 1
		label.TextWrapped = true
		label.ZIndex = 4
		label.Text = text
		label.Parent = frame

		local textStroke = Instance.new("UIStroke")
		textStroke.Name = "TextStroke"
		textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		textStroke.Color = Color3.fromRGB(0, 0, 0)
		textStroke.LineJoinMode = Enum.LineJoinMode.Round
		textStroke.Thickness = 2
		textStroke.Transparency = 0
		textStroke.Parent = label

		tutorialFrame = container
		tutorialLabel = label
	else
		tutorialLabel.Text = text
		tutorialFrame.Visible = true
	end
end

local function closeTutorial()
	tutorialActive = false
	tutorialWaitingFor = nil
	tutorialStepIndex = 0
	fadeTutorialTeleportIn()
	if tutorialGui then
		tutorialGui:Destroy()
		tutorialGui = nil
		tutorialLabel = nil
		tutorialFrame = nil
	end
	TutorialComplete:FireServer()
end

local function runTutorial()
	if tutorialActive then return end
	tutorialActive = true
	tutorialStepIndex = 1

	while tutorialActive do
		if tutorialStepIndex > #TUTORIAL_STEPS then
			task.wait(2)
			closeTutorial()
			break
		end

		if not combatActive then
			setTutorialVisible(false)
			repeat task.wait(0.3) until combatActive or not tutorialActive
			if not tutorialActive then break end
			setTutorialVisible(true)
		end

		local step = TUTORIAL_STEPS[tutorialStepIndex]
		showTutorialText(step.text)

		if not step.waitFor then
			task.wait(2.5)
			tutorialStepIndex += 1
		else
			tutorialWaitingFor = step.waitFor
			local before = tutorialStepIndex

			while tutorialActive and tutorialStepIndex == before do
				if not combatActive then
					tutorialWaitingFor = nil
					setTutorialVisible(false)
					repeat task.wait(0.3) until combatActive or not tutorialActive
					if not tutorialActive then break end
					setTutorialVisible(true)
					tutorialWaitingFor = step.waitFor
				end
				task.wait(0.1)
			end
		end
	end
end

-- ─────────────────────────────────────────────────────────────
-- STATE CACHE
-- ─────────────────────────────────────────────────────────────

StateManagerUpdateEvent.OnClientEvent:Connect(function(newState)
	StateCache = newState
end)

-- ─────────────────────────────────────────────────────────────
-- LANDING DETECTION
-- FIX: desconecta a conexão anterior antes de criar nova
-- ─────────────────────────────────────────────────────────────

local function connectLandingDetection()
	if landingConnection then
		landingConnection:Disconnect()
		landingConnection = nil
	end

	if not humanoid then return end

	landingConnection = humanoid.StateChanged:Connect(function(_, new)
		if not combatActive then return end

		if new == Enum.HumanoidStateType.Freefall
			or new == Enum.HumanoidStateType.Jumping then
			isAirborne = true
			return
		end

		if not isAirborne then return end
		if new ~= Enum.HumanoidStateType.Running
			and new ~= Enum.HumanoidStateType.GettingUp then return end

		isAirborne = false

		if not humrp then return end

		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = { character }
		rayParams.FilterType = Enum.RaycastFilterType.Exclude

		if not workspace:Raycast(humrp.Position, Vector3.new(0, -3.5, 0), rayParams) then return end

		EffectsHelper.PlayEffect(LANDING_EFFECT_TABLE, character)
		EffectsHelper.PlaySound(LANDING_SOUND_TABLE, character)
	end)
end

connectLandingDetection()

-- ─────────────────────────────────────────────────────────────
-- CHARACTER SWAP EVENT
-- ─────────────────────────────────────────────────────────────

if CharacterSwapEvent then
	CharacterSwapEvent.OnClientEvent:Connect(function(newChar)
		debugWarn("[CharacterSwap] Novo personagem recebido, atualizando refs...")
		character = newChar
		humanoid = newChar:WaitForChild("Humanoid", 5)
		animator = humanoid and humanoid:WaitForChild("Animator", 5)
		humrp = newChar:WaitForChild("HumanoidRootPart", 5)
		crouchTrack = nil
		characterVisuals = nil
		isAirborne = false
		connectLandingDetection()
		debugWarn("[CharacterSwap] Refs atualizadas com sucesso")
	end)
end

-- ─────────────────────────────────────────────────────────────
-- CHARACTER ADDED
-- ─────────────────────────────────────────────────────────────

localPlayer.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = newCharacter:WaitForChild('Humanoid')
	animator = humanoid:WaitForChild('Animator')
	humrp = newCharacter:WaitForChild('HumanoidRootPart')
	crouchTrack = nil
	characterVisuals = nil
	isAirborne = false
	connectLandingDetection()

	if pendingControlsRestore then
		pendingControlsRestore = false
		task.defer(function()
			character = newCharacter
			humanoid = newCharacter:FindFirstChildOfClass("Humanoid")
			humrp = newCharacter:FindFirstChild("HumanoidRootPart")
			if not humanoid or not humrp then
				warn("[CharacterAdded] Humanoid ou HRP ausente, abortando restore")
				return
			end
			humanoid.AutoRotate = true
			Controls:Disable()
			Controls:Enable()
			Camera.CameraType = Enum.CameraType.Custom
			Camera.CameraSubject = humanoid
			debugWarn("[CharacterAdded] Controles restaurados com sucesso")
		end)
	end
end)

-- ─────────────────────────────────────────────────────────────
-- COMBAT HELPERS
-- ─────────────────────────────────────────────────────────────

local function isGoingToEnemy()
	if not currentEnemyHRP then return false end
	if moveDir == 0 then return false end
	local right = Camera.CFrame.RightVector.Unit
	local toEnemy = (currentEnemyHRP.Position - humrp.Position)
	toEnemy = Vector3.new(toEnemy.X, 0, toEnemy.Z).Unit
	local dot = right:Dot(toEnemy)
	local finalDot = (moveDir > 0) and dot or -dot
	return finalDot > 0
end

local function fetchCharacterVisuals()
	if characterVisuals then return characterVisuals end
	local ok, result = pcall(function()
		return CombatRequests:InvokeServer('GetCharacterStorageVisuals')
	end)
	if not ok then
		warn("[CombatClient] GetCharacterStorageVisuals falhou:", result)
		return nil
	end
	characterVisuals = result
	return characterVisuals
end

local function applyCharacterAnimations()
	fetchCharacterVisuals()
	if not characterVisuals then warn("Character visuals não encontrado") return end
	local animateTemplate = characterVisuals.Animations.AnimateScript
	if not animateTemplate then warn("AnimateScript não existe") return end
	local oldAnimate = character:FindFirstChild("Animate")
	if oldAnimate then oldAnimate:Destroy() end
	local newAnimate = animateTemplate:Clone()
	newAnimate.Name = "Animate"
	newAnimate.Parent = character
end

local function playCrouchAnimation()
	fetchCharacterVisuals()
	if not characterVisuals then return end
	local crouchAnim = characterVisuals.Animations.BasicInputs.CROUCH
	if not crouchTrack then
		crouchTrack = animator:LoadAnimation(crouchAnim)
		crouchTrack.Looped = true
		crouchTrack.Priority = Enum.AnimationPriority.Movement
	end
	if not crouchTrack.IsPlaying then
		crouchTrack:Play()
	end
end

local function stopCrouchAnimation()
	if crouchTrack and crouchTrack.IsPlaying then
		crouchTrack:Stop()
	end
end

-- ─────────────────────────────────────────────────────────────
-- INPUT DETECTION
-- ─────────────────────────────────────────────────────────────

local function registerInput(action, phase)
	if phase == "Began" then
		onTutorialInput(action)
		if currentActionStates[action] == false then
			local abilityKey = ACTION_TO_ABILITY_KEY[action]
			if abilityKey then
				FightingHUD.PulseAbility(abilityKey)
			end
			pulseMobileButton(action)
		end
	end
	CombatClient.RegisterInput(action, phase)
end

local function detectMovementInput()
	fetchCharacterVisuals()
	if not characterVisuals then return end

	inputBeganConnection = UIS.InputBegan:Connect(function(input, gp)
		if gp then return end
		if shouldSuppressLocalInput() then return end
		local inputAction = InputManager.GetActionByInput(input)
		if not inputAction then return end
		registerInput(inputAction, 'Began')
		if inputAction == "RIGHT" then moveDir += 1
		elseif inputAction == "LEFT" then moveDir -= 1
		elseif inputAction == "JUMP" then wantJump = true
		elseif inputAction == "CROUCH" then playCrouchAnimation()
		end
	end)

	inputEndedConnection = UIS.InputEnded:Connect(function(input, gp)
		if gp then return end
		local inputAction = InputManager.GetActionByInput(input)
		if not inputAction then return end
		if inputAction == "RIGHT" then moveDir -= 1
		elseif inputAction == "LEFT" then moveDir += 1
		elseif inputAction == "JUMP" then wantJump = false
		elseif inputAction == "CROUCH" then stopCrouchAnimation()
		end
		if shouldSuppressLocalInput() then return end
		registerInput(inputAction, 'Ended')
	end)
end

-- ─────────────────────────────────────────────────────────────
-- MOVEMENT LOOP
-- ─────────────────────────────────────────────────────────────

local function startMovementLoop()
	local buttonWasDown = {}
	local fingerPosition = Vector2.new(-1, -1)

	touchTrackConnection = UIS.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseMovement then
			fingerPosition = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	-- FIX: isFingerOver usa variáveis locais capturadas, sem re-indexar a cada call
	local function isFingerOver(button)
		local absPos = button.AbsolutePosition
		local absSize = button.AbsoluteSize
		local fx, fy = fingerPosition.X, fingerPosition.Y
		return fx >= absPos.X
			and fx <= absPos.X + absSize.X
			and fy >= absPos.Y
			and fy <= absPos.Y + absSize.Y
	end

	local isTouching = false

	touchBeganConnection = UIS.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			fingerPosition = Vector2.new(input.Position.X, input.Position.Y)
			isTouching = true
		end
	end)

	touchEndedConnection = UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			isTouching = false
		end
	end)

	moveConnection = RunService.RenderStepped:Connect(function()
		if not humrp or humanoid.Health <= 0 then return end

		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.FallingDown
			or state == Enum.HumanoidStateType.Ragdoll
			or state == Enum.HumanoidStateType.GettingUp then
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end

		-- FIX: lê StateCache uma vez por frame em variáveis locais
		local isFullStunned   = StateCache[ENUM_FULL_STUNNED]
		local isBeingAttacked = StateCache[ENUM_BEING_ATTACKED]

		if isFullStunned or isBeingAttacked then
			humanoid:Move(Vector3.zero, false)
			return
		end

		if not InputManager.IsDown('RIGHT') and not InputManager.IsDown('LEFT')
			and not mobileRight and not mobileLeft and not gpMoveActive
			and moveDir ~= 0 then
			moveDir = 0
		end

		-- FIX: usa Camera cacheado em vez de workspace.CurrentCamera
		local right = Camera.CFrame.RightVector.Unit

		if moveDir ~= 0 then
			humanoid:Move(right * moveDir, true)
		else
			humanoid:Move(Vector3.zero, false)
		end

		if wantJump and not hasJumped and humanoid.FloorMaterial ~= Enum.Material.Air 
				and not StateManager.GET(localPlayer)[StateEnum.STATES_ENUM.COMBAT_FROZEN_STUNNED] 
				and not StateManager.GET(localPlayer)[StateEnum.STATES_ENUM.COMBAT_FULL_STUNNED] then
				
			hasJumped = true
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		else
			if not wantJump then hasJumped = false end
		end

		if currentEnemyHRP and currentEnemyHRP.Parent
			and not StateCache[ENUM_INSKILL]
			and not StateCache[ENUM_DISABLED_ROTATE] then
			local dx = currentEnemyHRP.Position.X - humrp.Position.X
			if math.abs(dx) > 0.05 then
				local targetAngle = math.rad(dx > 0 and -90 or 90)
				humrp.CFrame = CFrame.new(humrp.Position) * CFrame.Angles(0, targetAngle, 0)
			end
		end

		-- FIX: só processa botões mobile se for dispositivo touch
		-- FIX: usa mobileButtons cacheado em vez de GetChildren() todo frame
		if IsMobile then
			for _, button in mobileButtons do
				local isDown = isTouching and isFingerOver(button)
				local wasDown = buttonWasDown[button.Name]

				if isDown and not wasDown then
					buttonWasDown[button.Name] = true
					registerInput(button.Name, 'Began')
					if button.Name == "RIGHT" then moveDir += 1; mobileRight = true
					elseif button.Name == "LEFT" then moveDir -= 1; mobileLeft = true
					elseif button.Name == "JUMP" then wantJump = true
					elseif button.Name == "CROUCH" then playCrouchAnimation()
					end

				elseif not isDown and wasDown then
					buttonWasDown[button.Name] = false
					if button.Name == "RIGHT" then moveDir -= 1; mobileRight = false
					elseif button.Name == "LEFT" then moveDir += 1; mobileLeft = false
					elseif button.Name == "JUMP" then wantJump = false
					elseif button.Name == "CROUCH" then stopCrouchAnimation()
					end
					if shouldSuppressLocalInput() then continue end
					registerInput(button.Name, 'Ended')
				end
			end
		end
	end)
end

local function stopMovementLoop()
	if inputBeganConnection then inputBeganConnection:Disconnect() end
	if inputEndedConnection then inputEndedConnection:Disconnect() end
	if moveConnection then moveConnection:Disconnect() moveConnection = nil end
	if touchTrackConnection then touchTrackConnection:Disconnect() touchTrackConnection = nil end
	if touchBeganConnection then touchBeganConnection:Disconnect() touchBeganConnection = nil end
	if touchEndedConnection then touchEndedConnection:Disconnect() touchEndedConnection = nil end
	moveDir = 0
	mobileRight = false
	mobileLeft = false
	wantJump = false
	hasJumped = false
	currentEnemyHRP = nil
	if humanoid then
		humanoid.WalkSpeed = WALK_SPEED
		humanoid.AutoJumpEnabled = true
	end
	stopCrouchAnimation()
end

-- ─────────────────────────────────────────────────────────────
-- GAMEPAD LOOP
-- ─────────────────────────────────────────────────────────────

local function startGamepadLoop()
	if gamepadConnection then return end
	local thumbX = 0
	local gpMoveDir = 0

	gamepadConnection = RunService.Heartbeat:Connect(function()
		if not moveConnection then return end
		local gamepads = UIS:GetConnectedGamepads()
		if #gamepads == 0 then return end
		local gp = gamepads[1]
		local state = UIS:GetGamepadState(gp)
		local newThumbX = 0
		local newThumbY = 0

		for _, inputObj in ipairs(state) do
			if inputObj.KeyCode == Enum.KeyCode.Thumbstick1 then
				local x = inputObj.Position.X
				if math.abs(x) > THUMBSTICK_DEADZONE then newThumbX = x > 0 and 1 or -1 end
				newThumbY = inputObj.Position.Y
				break
			end
		end

		if newThumbX ~= thumbX then
			moveDir = moveDir - gpMoveDir
			thumbX = newThumbX
			gpMoveDir = newThumbX
			moveDir = moveDir + gpMoveDir
			gpMoveActive = gpMoveDir ~= 0
			if newThumbX > 0 then registerInput("RIGHT", "Began")
			elseif newThumbX < 0 then registerInput("LEFT", "Began")
			else registerInput(gpMoveDir > 0 and "RIGHT" or "LEFT", "Ended")
			end
		end

		-- FIX: lê enums cacheados
		local suppressInput = shouldSuppressLocalInput()

		for _, inputObj in ipairs(state) do
			local action = GAMEPAD_ACTION_MAP[inputObj.KeyCode]
			if not action then continue end
			local isDown = inputObj.Position.Z > 0.1
			local wasDown = gamepadButtonState[inputObj.KeyCode]
			if isDown and not wasDown then
				gamepadButtonState[inputObj.KeyCode] = true
				if suppressInput then continue end
				registerInput(action, "Began")
				if action == "JUMP" then wantJump = true end
			elseif not isDown and wasDown then
				gamepadButtonState[inputObj.KeyCode] = false
				if action == "JUMP" then wantJump = false end
				if suppressInput then continue end
				registerInput(action, "Ended")
			end
		end

		local CROUCH_THRESHOLD = 0.6
		if newThumbY < -CROUCH_THRESHOLD and not isCrouchingByGamepad then
			isCrouchingByGamepad = true; playCrouchAnimation()
		elseif newThumbY >= -CROUCH_THRESHOLD and isCrouchingByGamepad then
			isCrouchingByGamepad = false; stopCrouchAnimation()
		end
	end)
end

local function stopGamepadLoop()
	if gamepadConnection then gamepadConnection:Disconnect() gamepadConnection = nil end
	gamepadButtonState = {}
	gpMoveActive = false
	moveDir = 0
end

-- ─────────────────────────────────────────────────────────────
-- ENABLE / DISABLE MOVEMENT
-- ─────────────────────────────────────────────────────────────

local function EnableMovement(enemy): boolean
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	humanoid = character:WaitForChild('Humanoid', 8)
	if not humanoid then warn("[EnableMovement] Humanoid não encontrado") return false end
	animator = humanoid:WaitForChild('Animator', 8)
	if not animator then warn("[EnableMovement] Animator não encontrado") return false end
	humrp = character:WaitForChild('HumanoidRootPart', 8)
	if not humrp then warn("[EnableMovement] HumanoidRootPart não encontrado") return false end
	if not enemy or not enemy.Parent then warn("[EnableMovement] Enemy inválido") return false end
	local enemyHRP = enemy:WaitForChild("HumanoidRootPart", 8)
	if not enemyHRP then warn("[EnableMovement] Enemy HRP não encontrado") return false end

	currentEnemyHRP = enemyHRP
	playerLockingEnabled = true
	humanoid.AutoRotate = false
	humanoid.AutoJumpEnabled = false
	combatActive = true
	isAirborne = false

	if tutorialActive then
		setTutorialVisible(true)
	end

	cameraConnection = CameraModule.SetFightingCamera(humrp, currentEnemyHRP)
	if IsMobile then MobileUI.Visible = true end

	applyCharacterAnimations()
	detectMovementInput()
	startMovementLoop()
	startGamepadLoop()
	Controls:Disable()
	CombatStateEvent:Fire(true)

	return true
end

local function DisableMovement(isReturningToLobby: boolean?)
	combatActive = false
	isAirborne = false

	if tutorialActive then
		setTutorialVisible(false)
	end

	CameraModule.StopFightingCamera()
	if cameraConnection then cameraConnection:Disconnect() cameraConnection = nil end

	currentEnemyHRP = nil
	playerLockingEnabled = false
	Camera.CameraType = Enum.CameraType.Follow
	Camera.FieldOfView = 70

	local currentCharacter = localPlayer.Character
	if currentCharacter then
		character = currentCharacter
		humanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
		animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		humrp = currentCharacter:FindFirstChild("HumanoidRootPart")
	end

	if humanoid then humanoid.AutoRotate = true end
	if IsMobile then MobileUI.Visible = false end

	stopMovementLoop()
	stopGamepadLoop()
	CombatStateEvent:Fire(false)

	if isReturningToLobby then
		pendingControlsRestore = true
		debugWarn("[DisableMovement] pendingControlsRestore = true")
	else
		Controls:Enable()
		debugWarn("[DisableMovement] Controls:Enable() chamado")
	end
end

-- ─────────────────────────────────────────────────────────────
-- REMOTES
-- ─────────────────────────────────────────────────────────────

if MovementReadyRemote then
	MovementReadyRemote.OnClientInvoke = function(action, args)
		if action == "Enable" then
			if moveConnection then stopMovementLoop() end
			return EnableMovement(args.Enemy)
		end
		return false
	end
else
	warn("[MovementReady] RemoteFunction não encontrado")
end

ToggleMovementRemote.OnClientEvent:Connect(function(action, args)
	debugWarn("COMBAT CLIENT: TOGGLE MOVEMENT, ACTION: ", action)
	if action == 'Enable' then
		if moveConnection then stopMovementLoop() end
		EnableMovement(args.Enemy)
	elseif action == 'Disable' then
		DisableMovement(false)
	elseif action == 'DisableReturnLobby' then
		DisableMovement(true)
	end
end)

-- ─────────────────────────────────────────────────────────────
-- ANIMATION
-- ─────────────────────────────────────────────────────────────

local function PlayAnimation(animation, stopdelay, IsSmooth, priority)
	local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local anim = hum:FindFirstChildOfClass("Animator")
	if not anim then return end
	if not IsSmooth then
		for _, track in ipairs(anim:GetPlayingAnimationTracks()) do
			if track.Priority ~= Enum.AnimationPriority.Action then continue end
			track:Stop()
		end
	end
	local newTrack = anim:LoadAnimation(animation)
	newTrack.Priority = priority or Enum.AnimationPriority.Action
	newTrack:Play()
	activeTracks[animation.AnimationId] = newTrack
	newTrack.Stopped:Connect(function()
		activeTracks[animation.AnimationId] = nil
	end)
	if not stopdelay then return end
	task.delay(stopdelay, function()
		if newTrack.IsPlaying then
			newTrack:Stop()
			EffectsReplicator.Emit(character.HumanoidRootPart, game.ReplicatedStorage.CombatStorage.GlobalVFX.AnimationCancelPop)
			EffectsReplicator.Highlight(character, {Color = Color3.fromRGB(255, 255, 255), Duration = 0.2})
		end
		local animate = character:FindFirstChild("Animate")
		if animate and animate.Disabled then
			animate.Disabled = false
			hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
			task.defer(function()
				if hum then hum:ChangeState(Enum.HumanoidStateType.Running) end
			end)
		end
	end)
end

PlayAnimationEvent.OnClientEvent:Connect(function(action, animation, stopdelay, IsSmooth, priority)
	if action == 'PlayAnimation' then
		PlayAnimation(animation, stopdelay, IsSmooth, priority)
	elseif action == 'StopAnimation' then
		local track = activeTracks[animation.AnimationId]
		if track and track.IsPlaying then
			track:Stop()
			activeTracks[animation.AnimationId] = nil
			EffectsReplicator.Emit(character.HumanoidRootPart, game.ReplicatedStorage.CombatStorage.GlobalVFX.AnimationCancelPop)
			EffectsReplicator.Highlight(character, {Color = Color3.fromRGB(255, 255, 255), Duration = 0.2})
		end
		local animate = character:FindFirstChild("Animate")
		if animate and animate.Disabled then
			animate.Disabled = false
			local hum = character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
				task.defer(function()
					if hum then hum:ChangeState(Enum.HumanoidStateType.Running) end
				end)
			end
		end
	end
end)

-- ─────────────────────────────────────────────────────────────
-- DASH
-- ─────────────────────────────────────────────────────────────

local function executeDashClient(direction)
	if not humrp or humanoid.Health <= 0 then return end
	onTutorialInput("DASH")
	if isGoingToEnemy() then
		PlayAnimation(characterVisuals.Animations.BasicInputs.FORWARD_DASH)
	else
		PlayAnimation(characterVisuals.Animations.BasicInputs.BACK_DASH)
	end
	if humrp:FindFirstChild("DashVelocity") then return end

	-- FIX: usa Camera cacheado
	local rightVector = Camera.CFrame.RightVector.Unit
	local finalDir
	if direction == "RIGHT" then finalDir = rightVector
	elseif direction == "LEFT" then finalDir = -rightVector
	else return end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { workspace.Map }

	local origin = humrp.Position
	local rayResult = workspace:Raycast(origin, finalDir * 3, rayParams)
	if rayResult then return end

	local attachment = Instance.new("Attachment")
	attachment.Name = "DashAttachment"
	attachment.Parent = humrp

	local lv = Instance.new("LinearVelocity")
	lv.Name = "DashVelocity"
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = math.huge
	lv.VectorVelocity = Vector3.new(finalDir.X * DASH_FORCE, Y_BOOST, finalDir.Z * DASH_FORCE)
	lv.Parent = humrp

	Debris:AddItem(lv, DASH_TIME)
	Debris:AddItem(attachment, DASH_TIME)
end

-- ─────────────────────────────────────────────────────────────
-- SERVER EVENTS
-- ─────────────────────────────────────────────────────────────

ServerEvents.OnClientEvent:Connect(function(action, args)
	if action == "ExecuteDash" then
		executeDashClient(args)
	elseif action == "ActionStatesUpdate" then
		currentActionStates = args or {}
		FightingHUD.SetActionStates(currentActionStates)
		applyMobileActionStates()
	elseif action == "StaminaInsufficient" then
		FightingHUD.PulseStaminaDenied()
	elseif action == 'DisableCrouchAnimation' then
		stopCrouchAnimation()
	elseif action == 'ApplyCameraZoom' then
		CameraModule.ApplyTemporaryZoom(args.Zoom)
	elseif action == "DisablePlayerLock" then
		playerLockingEnabled = false
	elseif action == "EnablePlayerLock" then
		playerLockingEnabled = true
	elseif action == "StartTutorial" then
		task.spawn(runTutorial)
	elseif action == "FinishTutorialTeleportFade" then
		fadeTutorialTeleportOut()
	end
end)
