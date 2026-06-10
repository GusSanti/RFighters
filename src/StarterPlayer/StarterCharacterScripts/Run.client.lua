local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local WALK_SPEED = 16
local RUN_SPEED  = 24

local RUN_KEY_PRIMARY   = Enum.KeyCode.LeftControl
local RUN_KEY_SECONDARY = Enum.KeyCode.RightControl
local RUN_TOGGLE_DEBOUNCE = 0.08

local RUN_ANIM_ID  = "rbxassetid://73888542204041"
local WALK_ANIM_ID = "rbxassetid://109666298265797"
local IDLE_ANIM_ID = "rbxassetid://82594136642187"

local RunIntent    = false
local LastToggleAt = 0
local InCombat     = false

local runTrack   = nil
local walkTrack  = nil
local idleTrack  = nil
local currentAnimator = nil

-- ─────────────────────────────────────────────────────────────
-- ANIMATION HELPERS
-- ─────────────────────────────────────────────────────────────

local function getAnimator()
	local char = LocalPlayer.Character
	if not char then return nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	return hum:FindFirstChildOfClass("Animator")
end

local function loadTracks(animator)
	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = WALK_ANIM_ID

	local runAnim = Instance.new("Animation")
	runAnim.AnimationId = RUN_ANIM_ID

	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = IDLE_ANIM_ID

	walkTrack = animator:LoadAnimation(walkAnim)
	walkTrack.Priority = Enum.AnimationPriority.Movement
	walkTrack.Looped = true

	runTrack = animator:LoadAnimation(runAnim)
	runTrack.Priority = Enum.AnimationPriority.Movement
	runTrack.Looped = true

	idleTrack = animator:LoadAnimation(idleAnim)
	idleTrack.Priority = Enum.AnimationPriority.Movement
	idleTrack.Looped = true

	currentAnimator = animator
end

local function stopAllTracks()
	if runTrack  and runTrack.IsPlaying  then runTrack:Stop(0.2)  end
	if walkTrack and walkTrack.IsPlaying then walkTrack:Stop(0.2) end
	if idleTrack and idleTrack.IsPlaying then idleTrack:Stop(0.2) end
end

local function updateAnimation(isMoving: boolean)
	if InCombat then
		stopAllTracks()
		return
	end

	local animator = getAnimator()
	if not animator then return end

	if animator ~= currentAnimator then
		runTrack  = nil
		walkTrack = nil
		idleTrack = nil
		loadTracks(animator)
	end

	if not isMoving then
		-- parado: toca idle, para as outras
		if runTrack  and runTrack.IsPlaying  then runTrack:Stop(0.2)  end
		if walkTrack and walkTrack.IsPlaying then walkTrack:Stop(0.2) end
		if idleTrack and not idleTrack.IsPlaying then idleTrack:Play(0.2) end
		return
	end

	-- em movimento: para idle
	if idleTrack and idleTrack.IsPlaying then idleTrack:Stop(0.15) end

	if RunIntent then
		if walkTrack and walkTrack.IsPlaying then walkTrack:Stop(0.15) end
		if runTrack  and not runTrack.IsPlaying  then runTrack:Play(0.15)  end
	else
		if runTrack  and runTrack.IsPlaying  then runTrack:Stop(0.15)  end
		if walkTrack and not walkTrack.IsPlaying then walkTrack:Play(0.15) end
	end
end

-- ─────────────────────────────────────────────────────────────
-- COMBAT STATE
-- ─────────────────────────────────────────────────────────────

local CombatStateEvent = ReplicatedStorage:WaitForChild("CombatStateChanged", 10)
if CombatStateEvent then
	CombatStateEvent.Event:Connect(function(active)
		InCombat = active
		if active then
			RunIntent = false
			stopAllTracks()
		end
	end)
end

-- ─────────────────────────────────────────────────────────────
-- INPUT
-- ─────────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	if InCombat then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if input.KeyCode ~= RUN_KEY_PRIMARY and input.KeyCode ~= RUN_KEY_SECONDARY then return end
	if UserInputService:GetFocusedTextBox() then return end
	local now = os.clock()
	if now - LastToggleAt < RUN_TOGGLE_DEBOUNCE then return end
	LastToggleAt = now
	RunIntent = not RunIntent
end)

-- ─────────────────────────────────────────────────────────────
-- HEARTBEAT LOOP
-- ─────────────────────────────────────────────────────────────

RunService.Heartbeat:Connect(function()
	local char = LocalPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	if InCombat then return end

	hum.WalkSpeed = RunIntent and RUN_SPEED or WALK_SPEED

	local vel = hum.RootPart and hum.RootPart.AssemblyLinearVelocity or Vector3.zero
	local isMoving = Vector2.new(vel.X, vel.Z).Magnitude > 0.5

	updateAnimation(isMoving)
end)

-- ─────────────────────────────────────────────────────────────
-- CHARACTER ADDED
-- ─────────────────────────────────────────────────────────────

local function onCharacterAdded(char)
	RunIntent       = false
	runTrack        = nil
	walkTrack       = nil
	idleTrack       = nil
	currentAnimator = nil

	local hum = char:WaitForChild("Humanoid", 8)
	if not hum then return end
	local animator = hum:WaitForChild("Animator", 8)
	if not animator then return end
	loadTracks(animator)
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then
	onCharacterAdded(LocalPlayer.Character)
end