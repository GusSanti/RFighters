local EmoteController = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local PlayerState = require(game.ReplicatedStorage.PlayerState.PlayerStateClient)
local EmotesData  = require(script.EmotesData)

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local MainUI      = PlayerGui:WaitForChild("UI")

-- ── Referências de UI ─────────────────────────────────────────────────────────
local EMOTE_FRAME_NAME = "Emotes"
local TOGGLE_KEY       = Enum.KeyCode.X
local MAX_EMOTE_SLOTS  = 8

-- Tween constants
local TARGET_POSITION = UDim2.new(0.521, 0, 0.5, 0)
local TARGET_SIZE     = UDim2.new(0.313, 0, 0.477, 0)
local CLOSED_SIZE     = UDim2.new(0, 0, 0, 0)
local OPEN_INFO       = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_INFO      = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- Viewport constants
local WORLD_MODEL_NAME                    = "WorldModel"
local VIEWPORT_CAMERA_NAME                = "EmoteWheelViewportCamera"
local VIEWPORT_DUMMY_NAME                 = "EmoteWheelDummy"
local GENERATED_VISUAL_ATTRIBUTE          = "EmoteWheelGeneratedVisual"
local VIEWPORT_CAMERA_FIELD_OF_VIEW       = 28
local VIEWPORT_CAMERA_MIN_DISTANCE        = 3
local VIEWPORT_CAMERA_DISTANCE_MULTIPLIER = 1.75
local VIEWPORT_CAMERA_DIRECTION           = Vector3.new(1, 0.35, -2).Unit

-- Emote playback constants
local EMOTE_FADE_TIME      = 0.15
local MOVE_STOP_THRESHOLD  = 0.05

local HEADER_TEMPLATE_NAME = "HeaderTemplate"

local ToxicEmotesCharacter = workspace.Stands.Emotes.TOXIC
local AnimeEmotesCharacter = workspace.Stands.Emotes.ANIME
local ToxicShowEmote       = EmotesData.Emotes.TOXIC.TAKE_THE_L
local AnimeShowEmote       = EmotesData.Emotes.ANIME.JOJO_POSE

-- ── Estado interno ────────────────────────────────────────────────────────────
local State = {
	IsOpen            = false,
	Tween             = nil,
	AnimationToken    = 0,
	SlotConnections   = {},
	ActiveTrack       = nil,
	ActiveEmoteName   = nil,
	ActiveConnections = {},
	ViewportTroves    = {},   -- [viewport] = stopTrack fn
	StandTracks       = {},   -- tracks de emote dos stands
}

local STAND_CFRAME_OFFSETS = {
	TOXIC = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.rad(0), 0),
	ANIME = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.rad(0), 0),
}

-- ─── Helpers de dados ────────────────────────────────────────────────────────

local function NormalizeEmoteSlots(equippedEmotes)
	local normalized = {}
	if type(equippedEmotes) ~= "table" then
		for i = 1, MAX_EMOTE_SLOTS do normalized[i] = "" end
		return normalized
	end
	for i = 1, MAX_EMOTE_SLOTS do
		local name    = equippedEmotes[i]
		normalized[i] = type(name) == "string" and name or ""
	end
	return normalized
end

local function GetEquippedEmotes()
	return NormalizeEmoteSlots(PlayerState.Get("EquippedEmotes"))
end

-- ─── Dummy template ──────────────────────────────────────────────────────────

local function GetDummyTemplate()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local dummy  = assets and assets:FindFirstChild("Dummy")
	return dummy and dummy:IsA("Model") and dummy or nil
end

-- ─── UI helpers ──────────────────────────────────────────────────────────────

local function FindEmoteFrame()
	local frame = MainUI:FindFirstChild(EMOTE_FRAME_NAME)
	if frame and frame:IsA("GuiObject") then return frame end
	return nil
end

local function GetTextureSlot(frame, slotIndex)
	local slot = frame:FindFirstChild("Texture" .. tostring(slotIndex), true)
	return slot and slot:IsA("GuiObject") and slot or nil
end

local function FindItemViewport(root)
	if not root then return nil end
	if root:IsA("ViewportFrame") then return root end
	local named = root:FindFirstChild("ITEM", true)
	if named and named:IsA("ViewportFrame") then return named end
	return root:FindFirstChildWhichIsA("ViewportFrame", true)
end

-- ─── Tween helpers ───────────────────────────────────────────────────────────

local function CancelFrameTween()
	if State.Tween then
		State.Tween:Cancel()
		State.Tween = nil
	end
end

-- ─── Viewport helpers ────────────────────────────────────────────────────────

local function ClearViewport(viewport)
	if not viewport then return nil end

	local trove = State.ViewportTroves[viewport]
	if trove then
		trove()
		State.ViewportTroves[viewport] = nil
	end

	for _, child in ipairs(viewport:GetChildren()) do
		if child:GetAttribute(GENERATED_VISUAL_ATTRIBUTE) == true then
			child:Destroy()
		end
	end

	local worldModel = viewport:FindFirstChild(WORLD_MODEL_NAME)
	if not worldModel or not worldModel:IsA("WorldModel") then
		worldModel        = Instance.new("WorldModel")
		worldModel.Name   = WORLD_MODEL_NAME
		worldModel.Parent = viewport
	end
	for _, child in ipairs(worldModel:GetChildren()) do
		child:Destroy()
	end

	return worldModel
end

local function ClearSlotVisual(textureSlot)
	local viewport = FindItemViewport(textureSlot)
	if viewport then
		ClearViewport(viewport)
		viewport.Visible = false
	end
end

local function ConfigureViewportCamera(viewport, model)
	local camera = viewport:FindFirstChild(VIEWPORT_CAMERA_NAME)
	if not camera or not camera:IsA("Camera") then
		camera        = Instance.new("Camera")
		camera.Name   = VIEWPORT_CAMERA_NAME
		camera.Parent = viewport
	end
	camera.FieldOfView     = VIEWPORT_CAMERA_FIELD_OF_VIEW
	viewport.CurrentCamera = camera

	local modelCFrame, modelSize = model:GetBoundingBox()
	local maxDim  = math.max(modelSize.X, modelSize.Y, modelSize.Z, VIEWPORT_CAMERA_MIN_DISTANCE)
	local fitDist = (maxDim / 2) / math.tan(math.rad(camera.FieldOfView) / 2)
	local camDist = math.max(fitDist * VIEWPORT_CAMERA_DISTANCE_MULTIPLIER, VIEWPORT_CAMERA_MIN_DISTANCE)
	local camPos  = modelCFrame.Position + VIEWPORT_CAMERA_DIRECTION * camDist
	camera.CFrame = CFrame.new(camPos, modelCFrame.Position)
end

local function PrepareAnimatedRigForViewport(model)
	model:PivotTo(CFrame.new())
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored   = desc.Name == "HumanoidRootPart"
			desc.CanCollide = false
			desc.CanTouch   = false
			desc.CanQuery   = false
			desc.Massless   = true
		end
	end
end

local function LoadEmoteTrack(humanoid, animator, animation)
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	if ok and track then return track end
	local ok2, track2 = pcall(function() return humanoid:LoadAnimation(animation) end)
	if ok2 and track2 then return track2 end
	warn("[LoadEmoteTrack] Falhou:", not ok and track or track2)
	return nil
end

local function RenderEmoteImage(viewport, imageId)
	local image = Instance.new("ImageLabel")
	image.Name                   = "EmoteWheelImage"
	image:SetAttribute(GENERATED_VISUAL_ATTRIBUTE, true)
	image.BackgroundTransparency = 1
	image.Size                   = UDim2.fromScale(1, 1)
	image.Image                  = imageId
	image.ScaleType              = Enum.ScaleType.Fit
	image.Parent                 = viewport
	viewport.Visible             = true
end

local function RenderEmoteViewport(textureSlot, emoteName)
	local viewport = FindItemViewport(textureSlot)
	if not viewport then return end

	local emoteData = EmotesData.GetEmote(emoteName)
	if type(emoteData) ~= "table" then
		ClearViewport(viewport)
		return
	end

	local worldModel  = ClearViewport(viewport)
	local animationId = emoteData.AnimationId

	if type(animationId) ~= "string" or animationId == "" then
		if type(emoteData.ImageId) == "string" and emoteData.ImageId ~= "" then
			RenderEmoteImage(viewport, emoteData.ImageId)
		end
		return
	end

	local dummyTemplate = GetDummyTemplate()
	if not worldModel or not dummyTemplate then return end

	local dummy = dummyTemplate:Clone()
	dummy.Name  = VIEWPORT_DUMMY_NAME
	PrepareAnimatedRigForViewport(dummy)
	dummy.Parent = worldModel
	ConfigureViewportCamera(viewport, dummy)

	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	if not humanoid then ClearViewport(viewport); return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator        = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation           = Instance.new("Animation")
	animation.AnimationId     = animationId
	animation.Name            = "EmoteWheelPreview"
	animation.Parent          = dummy

	local track = LoadEmoteTrack(humanoid, animator, animation)
	if not track then ClearViewport(viewport); return end

	track.Looped   = true
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0, 1, 1)

	State.ViewportTroves[viewport] = function()
		pcall(function() track:Stop(); track:Destroy() end)
	end

	viewport.Visible = true
end

-- ─── Stand Skin + Emote ──────────────────────────────────────────────────────

local function CopyPlayerAppearanceToStand(stand, character)
	if not stand or not stand.Parent or not character then return nil end

	local standHRP = stand:FindFirstChild("HumanoidRootPart")
	if not standHRP then return nil end

	local standCFrame = standHRP.CFrame
	local standName   = stand.Name

	local headerTemplate = standHRP:FindFirstChild(HEADER_TEMPLATE_NAME)
	local savedHeader    = headerTemplate and headerTemplate:Clone() or nil

	local charHumanoid = character:FindFirstChildOfClass("Humanoid")
	if not charHumanoid then return nil end

	local desc = charHumanoid:GetAppliedDescription()
	if not desc then return nil end

	local rigType = charHumanoid.RigType
	local newChar = Players:CreateHumanoidModelFromDescriptionAsync(desc, rigType)
	if not newChar then return nil end

	newChar.Name = standName

	local animateScript = newChar:FindFirstChild("Animate")
	if animateScript then animateScript:Destroy() end

	for _, obj in ipairs(newChar:GetDescendants()) do
		if obj:IsA("LocalScript") or obj:IsA("Script") or obj:IsA("ModuleScript") then
			obj:Destroy()
		end
	end

	for _, part in ipairs(newChar:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = false
			part.CanTouch   = false
			part.CanQuery   = false
		elseif part:IsA("BasePart") and part.Name == "HumanoidRootPart" then
			part.Anchored = true
		end
	end

	local offset = STAND_CFRAME_OFFSETS[standName] or CFrame.identity
	newChar:PivotTo(standCFrame * offset)

	if savedHeader then
		local newHRP = newChar:FindFirstChild("HumanoidRootPart")
		if newHRP then
			savedHeader.Parent = newHRP
		end
	end

	for _, child in ipairs(stand:GetChildren()) do
		if child:IsA("BillboardGui") or child:IsA("SurfaceGui") or child:IsA("ProximityPrompt") then
			child.Parent = newChar
		end
	end

	local parent = stand.Parent
	stand:Destroy()
	newChar.Parent = parent

	return newChar
end

local function PlayStandEmote(stand, emoteData)
	if not stand or type(emoteData) ~= "table" then return end

	local animId = emoteData.AnimationId
	if type(animId) ~= "string" or animId == "" then return end

	local humanoid = stand:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator        = Instance.new("Animator")
		animator.Parent = humanoid
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:Stop(0)
	end

	local prevTrack = State.StandTracks[stand]
	if prevTrack then
		pcall(function() prevTrack:Stop(0); prevTrack:Destroy() end)
		State.StandTracks[stand] = nil
	end

	local animation           = Instance.new("Animation")
	animation.Name            = "StandEmote"
	animation.AnimationId     = animId
	animation.Parent          = stand

	local track = LoadEmoteTrack(humanoid, animator, animation)
	animation:Destroy()
	if not track then return end

	track.Looped   = true
	track.Priority = Enum.AnimationPriority.Core
	track:Play(0, 1, 1)

	State.StandTracks[stand] = track
end

local function SetupStands()
	local character = LocalPlayer.Character
	if not character then return end

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end

	task.wait(1)

	character = LocalPlayer.Character
	if not character then return end

	local newToxic = CopyPlayerAppearanceToStand(ToxicEmotesCharacter, character)
	ToxicEmotesCharacter = newToxic or ToxicEmotesCharacter

	local newAnime = CopyPlayerAppearanceToStand(AnimeEmotesCharacter, character)
	AnimeEmotesCharacter = newAnime or AnimeEmotesCharacter

	task.wait(3)

	PlayStandEmote(ToxicEmotesCharacter, ToxicShowEmote)
	PlayStandEmote(AnimeEmotesCharacter, AnimeShowEmote)
end

-- ─── Slot connections ────────────────────────────────────────────────────────

local function DisconnectSlotConnections()
	for _, conn in ipairs(State.SlotConnections) do
		conn:Disconnect()
	end
	table.clear(State.SlotConnections)
end

-- ─── Active emote ────────────────────────────────────────────────────────────

local function StopActiveEmote()
	for _, conn in ipairs(State.ActiveConnections) do
		conn:Disconnect()
	end
	table.clear(State.ActiveConnections)

	local track       = State.ActiveTrack
	State.ActiveTrack     = nil
	State.ActiveEmoteName = nil

	if track then
		track:Stop(EMOTE_FADE_TIME)
		track:Destroy()
	end
end

local function ShouldStopForHumanoidState(state)
	return state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Freefall
		or state == Enum.HumanoidStateType.FallingDown
		or state == Enum.HumanoidStateType.Ragdoll
		or state == Enum.HumanoidStateType.Climbing
		or state == Enum.HumanoidStateType.Swimming
		or state == Enum.HumanoidStateType.Seated
end

local function WatchMovementForEmote(humanoid, animator)
	table.insert(State.ActiveConnections, animator.AnimationPlayed:Connect(function(playedTrack)
		if playedTrack ~= State.ActiveTrack then
			StopActiveEmote()
		end
	end))

	table.insert(State.ActiveConnections, humanoid.Running:Connect(function(speed)
		if math.abs(speed) > MOVE_STOP_THRESHOLD then
			StopActiveEmote()
		end
	end))

	table.insert(State.ActiveConnections, humanoid.StateChanged:Connect(function(_, newState)
		if ShouldStopForHumanoidState(newState) then
			StopActiveEmote()
		end
	end))

	table.insert(State.ActiveConnections, RunService.Heartbeat:Connect(function()
		if humanoid.Parent == nil then
			StopActiveEmote()
			return
		end
		if humanoid.MoveDirection.Magnitude > MOVE_STOP_THRESHOLD then
			StopActiveEmote()
		end
	end))
end

local function PlayCharacterEmote(emoteName)
	StopActiveEmote()

	local emoteData = EmotesData.GetEmote(emoteName)
	if type(emoteData) ~= "table"
		or type(emoteData.AnimationId) ~= "string"
		or emoteData.AnimationId == "" then
		return
	end

	local character = LocalPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator        = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation           = Instance.new("Animation")
	animation.Name            = "ActiveEmote"
	animation.AnimationId     = emoteData.AnimationId
	animation.Parent          = character

	local track = LoadEmoteTrack(humanoid, animator, animation)
	animation:Destroy()
	if not track then return end

	State.ActiveTrack     = track
	State.ActiveEmoteName = emoteName
	WatchMovementForEmote(humanoid, animator)

	track.Looped   = true
	track.Priority = Enum.AnimationPriority.Action
	track:Play(EMOTE_FADE_TIME, 1, 1)
end

-- ─── Frame open / close ──────────────────────────────────────────────────────

local function CloseFrame(afterClose)
	local frame = FindEmoteFrame()
	if not frame then
		if afterClose then afterClose() end
		return
	end

	State.IsOpen = false
	State.AnimationToken += 1
	local token = State.AnimationToken
	CancelFrameTween()

	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position    = TARGET_POSITION

	local tween = TweenService:Create(frame, CLOSE_INFO, { Size = CLOSED_SIZE })
	State.Tween = tween

	local conn
	conn = tween.Completed:Connect(function()
		conn:Disconnect()
		if State.AnimationToken ~= token then return end
		State.Tween    = nil
		frame.Visible  = false
		frame.Position = TARGET_POSITION
		frame.Size     = CLOSED_SIZE
		if afterClose then afterClose() end
	end)

	tween:Play()
end

local function PopulateSlots()
	local frame = FindEmoteFrame()
	if not frame then return end

	DisconnectSlotConnections()
	local equippedEmotes = GetEquippedEmotes()

	for slotIndex = 1, MAX_EMOTE_SLOTS do
		local textureSlot = GetTextureSlot(frame, slotIndex)
		if not textureSlot then continue end

		ClearSlotVisual(textureSlot)
		local emoteName = equippedEmotes[slotIndex]
		if emoteName ~= "" then
			RenderEmoteViewport(textureSlot, emoteName)
		end

		local button = textureSlot:FindFirstChild("Btn")
		if button and button:IsA("GuiButton") then
			local captured = emoteName
			table.insert(State.SlotConnections, button.MouseButton1Click:Connect(function()
				CloseFrame(function()
					if captured ~= "" then
						PlayCharacterEmote(captured)
					end
				end)
			end))
		end
	end
end

local function OpenFrame()
	local frame = FindEmoteFrame()
	if not frame then return end

	PopulateSlots()
	State.IsOpen = true
	State.AnimationToken += 1
	CancelFrameTween()

	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position    = TARGET_POSITION
	frame.Size        = CLOSED_SIZE
	frame.Visible     = true

	local tween = TweenService:Create(frame, OPEN_INFO, { Size = TARGET_SIZE })
	State.Tween = tween
	tween.Completed:Connect(function()
		if State.Tween == tween then State.Tween = nil end
	end)
	tween:Play()
end

local function ToggleFrame()
	local frame = FindEmoteFrame()
	if not frame then return end

	if State.IsOpen or frame.Visible then
		CloseFrame(nil)
	else
		OpenFrame()
	end
end

-- ─── Public API ──────────────────────────────────────────────────────────────

function EmoteController.Start()
	local frame = FindEmoteFrame()
	if frame then
		frame.Visible     = false
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position    = TARGET_POSITION
		frame.Size        = CLOSED_SIZE
	end
end

function EmoteController.Init()
	EmoteController.Start()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode ~= TOGGLE_KEY then return end
		ToggleFrame()
	end)

	local function onCharacterAdded(_character)
		StopActiveEmote()
		task.spawn(SetupStands)
	end

	LocalPlayer.CharacterRemoving:Connect(function()
		StopActiveEmote()
	end)
	LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

	if LocalPlayer.Character then
		task.spawn(SetupStands)
	end
end

return EmoteController