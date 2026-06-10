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

local animator = humanoid:WaitForChild('Animator', 10)
local humrp = character:WaitForChild('HumanoidRootPart', 15)

if not humrp then
	warn("[Init] HumanoidRootPart ainda não disponível, yield extra...")
	-- Força um yield e tenta de novo
	task.wait(1)
	humrp = character:WaitForChild('HumanoidRootPart', 10)
end

local StateManager = require(game.ReplicatedStorage.StateManager.StateManager)
local StateEnum = require(game.ReplicatedStorage.StateManager.ENUM)
local CameraModule = require(game.ReplicatedStorage.Modules.CameraModule)
local InputManager = require(game.ReplicatedStorage.Modules.InputManager)
local CombatClient = require(game.ReplicatedStorage.CombatSystem.CombatClient)
local PlayerModule = require(localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
local EffectsReplicator = require(game.ReplicatedStorage.CombatSystem.EffectsReplicatorClient)
local EffectsHelper = require(game.ReplicatedStorage.CombatSystem.EffectsHelper)
local CombatUtils = require(game.ReplicatedStorage.CombatSystem.CombatUtils)

local CombatRequests = game.ReplicatedStorage.CombatSystem.Events.ClientRequests
local PlayAnimationEvent = game.ReplicatedStorage.CombatSystem.Events.PlayAnimation
local ServerEvents = game.ReplicatedStorage.CombatSystem.Events.ServerEvents
local StateManagerUpdateEvent = game.ReplicatedStorage.StateManager.Remotes.UPDATE_EVENT
local TutorialComplete = game.ReplicatedStorage.Events:WaitForChild("TutorialComplete")
local CharacterSwapEvent = game.ReplicatedStorage.Events:WaitForChild("CharacterSwapped", 10)

local playerGui = localPlayer:WaitForChild("PlayerGui")
local MainUI = playerGui:WaitForChild("UI")
local FightingFrame = MainUI:WaitForChild('FightingFrame')
local MobileUI = FightingFrame:WaitForChild('MobileUI')

local RunService = game:GetService("RunService")
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

local function rebuildMobileButtonCache()
	mobileButtons = {}
	for _, b in MobileUI:GetChildren() do
		if b:IsA("ImageButton") then
			table.insert(mobileButtons, b)
		end
	end
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
local landingConnection = nil -- FIX: rastreia conexão para evitar leak

local activeTracks = {}
local StateCache = StateManager.GET()

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

local function setTutorialVisible(visible)
	if tutorialFrame then
		tutorialFrame.Visible = visible
	end
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
		tutorialGui.Parent = playerGui

		local frame = Instance.new("Frame")
		frame.Name = "Frame"
		frame.Size = UDim2.new(0.6, 0, 0, 65)
		frame.Position = UDim2.new(0.2, 0, 0.07, 0)
		frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		frame.BackgroundTransparency = 0.35
		frame.BorderSizePixel = 0
		frame.Parent = tutorialGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = frame

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -24, 1, 0)
		label.Position = UDim2.new(0, 12, 0, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = text
		label.Parent = frame

		tutorialFrame = frame
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
		warn("[CharacterSwap] Novo personagem recebido, atualizando refs...")
		character = newChar
		humanoid = newChar:WaitForChild("Humanoid", 5)
		animator = humanoid and humanoid:WaitForChild("Animator", 5)
		humrp = newChar:WaitForChild("HumanoidRootPart", 5)
		crouchTrack = nil
		characterVisuals = nil
		isAirborne = false
		connectLandingDetection()
		warn("[CharacterSwap] Refs atualizadas com sucesso")
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
			warn("[CharacterAdded] Controles restaurados com sucesso")
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

local function applyCharacterAnimations()
	if not characterVisuals then
		characterVisuals = CombatRequests:InvokeServer('GetCharacterStorageVisuals')
	end
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
	if not characterVisuals then
		characterVisuals = CombatRequests:InvokeServer('GetCharacterStorageVisuals')
	end
	if not characterVisuals then return end
	local crouchAnim = characterVisuals.Animations.BasicInputs.CROUCH
	if not crouchTrack then
		crouchTrack = animator:LoadAnimation(crouchAnim)
		crouchTrack.Looped = true
		crouchTrack.Priority = Enum.AnimationPriority.Movement
	end
	if not crouchTrack.IsPlaying then
		crouchTrack:Play()
		StateManager.POST(ENUM_FULL_STUNNED)
	end
end

local function stopCrouchAnimation()
	if crouchTrack and crouchTrack.IsPlaying then
		crouchTrack:Stop()
		StateManager.REMOVE(ENUM_FULL_STUNNED)
	end
end

-- ─────────────────────────────────────────────────────────────
-- INPUT DETECTION
-- ─────────────────────────────────────────────────────────────

local function registerInput(action, phase)
	if phase == "Began" then
		onTutorialInput(action)
	end
	CombatClient.RegisterInput(action, phase)
end

local function detectMovementInput()
	if not characterVisuals then
		characterVisuals = CombatRequests:InvokeServer('GetCharacterStorageVisuals')
	end
	if not characterVisuals then return end

	inputBeganConnection = UIS.InputBegan:Connect(function(input, gp)
		if gp then return end
		if StateCache[ENUM_FULL_STUNNED]
			or StateCache[ENUM_BEING_ATTACKED]
			or StateCache[ENUM_COUNTDOWN_STUN]
		then return end
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
		if StateCache[ENUM_FULL_STUNNED]
			or StateCache[ENUM_BEING_ATTACKED]
			or StateCache[ENUM_COUNTDOWN_STUN] then return end
		registerInput(inputAction, 'Ended')
	end)
end

-- ─────────────────────────────────────────────────────────────
-- MOVEMENT LOOP
-- ─────────────────────────────────────────────────────────────

local function startMovementLoop()
	local buttonWasDown = {}
	local fingerPosition = Vector2.new(-1, -1)

	local touchTrackConnection = UIS.InputChanged:Connect(function(input)
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

	local touchBeganConn = UIS.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			fingerPosition = Vector2.new(input.Position.X, input.Position.Y)
			isTouching = true
		end
	end)

	local touchEndedConn = UIS.InputEnded:Connect(function(input)
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

		if wantJump and not hasJumped and humanoid.FloorMaterial ~= Enum.Material.Air then
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
					if isFullStunned or isBeingAttacked or StateCache[ENUM_COUNTDOWN_STUN] then continue end
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
		local isStunned  = StateCache[ENUM_FULL_STUNNED]
		local isAttacked = StateCache[ENUM_BEING_ATTACKED]
		local isCountdown = StateCache[ENUM_COUNTDOWN_STUN]

		for _, inputObj in ipairs(state) do
			local action = GAMEPAD_ACTION_MAP[inputObj.KeyCode]
			if not action then continue end
			local isDown = inputObj.Position.Z > 0.1
			local wasDown = gamepadButtonState[inputObj.KeyCode]
			if isDown and not wasDown then
				gamepadButtonState[inputObj.KeyCode] = true
				if isStunned or isAttacked or isCountdown then continue end
				registerInput(action, "Began")
				if action == "JUMP" then wantJump = true end
			elseif not isDown and wasDown then
				gamepadButtonState[inputObj.KeyCode] = false
				if action == "JUMP" then wantJump = false end
				if isStunned or isAttacked or isCountdown then continue end
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
		warn("[DisableMovement] pendingControlsRestore = true")
	else
		Controls:Enable()
		warn("[DisableMovement] Controls:Enable() chamado")
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
	warn("COMBAT CLIENT: TOGGLE MOVEMENT, ACTION: ", action)
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
	end
end)