local CameraModule = {}

--Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

--Client Related
local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Camera = workspace.CurrentCamera

local CombatCameraZoomTimeout   = 1.0   -- segundos até o zoom voltar
local CombatCameraZoomMaxStack  = 10    -- máximo de studs acumuláveis

-- estado interno do zoom temporário
local _zoomOffset  = 0
local _zoomTimer   = 0
local _zoomRestoring = false

-- flag para snap instantâneo no primeiro frame da fight camera
local _fightCamFirstFrame = false

-- FIX: declarada como upvalue real (estava comentada, causando erro global)
local fightingCameraActive = false

--Variables
local originalCFrame = nil
local originalCameraType = nil
local originalFieldOfView = nil
local isCustomCamera = false
local renderConnection = nil
local currentTween = nil
local savedFightingCamera = nil

--Constants
local DEFAULT_TWEEN_TIME = 1
local DEFAULT_EASING_STYLE = Enum.EasingStyle.Quad
local DEFAULT_EASING_DIRECTION = Enum.EasingDirection.Out

local DEFAULT_FIGHT_CONFIG = {
	BaseOffset = Vector3.new(0, 11, 18),
	MinZoom = 14,
	MaxZoom = 26,
	MaxPlayerDistance = 130,
	Smoothness = 10,
	SideClamp = 100,
	FixedFOV = 65,
	CharacterClamp = true,
	CharacterMargin = 2,
}

--Types
export type CameraSettings = {
	Duration: number?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
	FieldOfView: number?,
	Instant: boolean?,
}

--Private Functions
local function stopRenderConnection()
	if renderConnection then	
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

local function stopCurrentTween()
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
end

local function saveOriginalCamera()
	if not originalCFrame then
		originalCFrame = Camera.CFrame
		originalCameraType = Camera.CameraType
		originalFieldOfView = Camera.FieldOfView
	end
end

local function getHorizontalBounds(camCFrame: CFrame, targetPoint: Vector3, fovDeg: number): (number, number)
	local camPos = camCFrame.Position
	local distToTarget = (camPos - targetPoint).Magnitude
	local halfFOVRad = math.rad(fovDeg / 2)
	local aspect = Camera.ViewportSize.X / Camera.ViewportSize.Y
	local halfWidth = math.tan(halfFOVRad) * aspect * distToTarget
	return targetPoint.X - halfWidth, targetPoint.X + halfWidth
end

local function clampCharacterToCamera(basePart: BasePart, minX: number, maxX: number, margin: number)
	margin = margin or 2
	if not (basePart and basePart.Parent) then return end

	local hrp = basePart
	if basePart.Name ~= "HumanoidRootPart" then
		local char = basePart.Parent
		if char then
			hrp = char:FindFirstChild("HumanoidRootPart") or basePart
		end
	end

	local clampedX = math.clamp(hrp.Position.X, minX + margin, maxX - margin)
	if math.abs(clampedX - hrp.Position.X) > 0.01 then
		hrp.CFrame = CFrame.new(clampedX, hrp.Position.Y, hrp.Position.Z)
			* (hrp.CFrame - hrp.CFrame.Position)

		local rb = hrp.Parent and hrp.Parent:FindFirstChildWhichIsA("Humanoid")
		if rb and hrp.AssemblyLinearVelocity then
			local vel = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = Vector3.new(0, vel.Y, vel.Z)
		end
	end
end

--Public Functions

function CameraModule.SetCamera(target: BasePart | CFrame, settings: CameraSettings?)
	settings = settings or {}

	saveOriginalCamera()
	stopRenderConnection()
	stopCurrentTween()

	Camera.CameraType = Enum.CameraType.Scriptable
	isCustomCamera = true

	local targetCFrame = if typeof(target) == "CFrame" then target else target.CFrame
	local targetFOV = settings.FieldOfView

	if settings.Instant then
		Camera.CFrame = targetCFrame
		if targetFOV then
			Camera.FieldOfView = targetFOV
		end
	else
		local tweenProperties = {CFrame = targetCFrame}
		if targetFOV then
			tweenProperties.FieldOfView = targetFOV
		end

		local duration = settings.Duration or DEFAULT_TWEEN_TIME
		local easingStyle = settings.EasingStyle or DEFAULT_EASING_STYLE
		local easingDirection = settings.EasingDirection or DEFAULT_EASING_DIRECTION

		currentTween = TweenService:Create(
			Camera,
			TweenInfo.new(duration, easingStyle, easingDirection),
			tweenProperties
		)
		currentTween:Play()

		currentTween.Completed:Once(function()
			currentTween = nil
		end)
	end

	return currentTween
end

function CameraModule.SetCameraInstant(target: BasePart | CFrame, fov: number?)
	return CameraModule.SetCamera(target, {
		Instant = true,
		FieldOfView = fov
	})
end

function CameraModule.SetCameraTween(target: BasePart | CFrame, duration: number?, easingStyle: Enum.EasingStyle?, easingDirection: Enum.EasingDirection?)
	return CameraModule.SetCamera(target, {
		Duration = duration,
		EasingStyle = easingStyle,
		EasingDirection = easingDirection
	})
end

function CameraModule.SetCameraFollow(targetPart: BasePart, updateFieldOfView: boolean?)
	saveOriginalCamera()
	stopRenderConnection()
	stopCurrentTween()

	Camera.CameraType = Enum.CameraType.Scriptable
	isCustomCamera = true

	renderConnection = RunService.RenderStepped:Connect(function()
		if targetPart and targetPart.Parent then
			Camera.CFrame = targetPart.CFrame
			if updateFieldOfView and targetPart:GetAttribute("FieldOfView") then
				Camera.FieldOfView = targetPart:GetAttribute("FieldOfView")
			end
		else
			CameraModule.RestoreCamera()
		end
	end)
end

function CameraModule.RestoreCamera(settings: CameraSettings?)
	warn("[CameraModule] RestoreCamera chamado | isCustomCamera:", isCustomCamera, "| originalCFrame:", originalCFrame ~= nil, "| settings:", settings)

	if not isCustomCamera or not originalCFrame then
		warn("[CameraModule] RestoreCamera sem estado válido — aplicando fallback")
		stopRenderConnection()
		stopCurrentTween()
		fightingCameraActive = false
		Camera.CameraType = Enum.CameraType.Custom
		Camera.FieldOfView = 70
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then Camera.CameraSubject = humanoid end
		warn("[CameraModule] Fallback aplicado | CameraType: Custom | CameraSubject:", humanoid ~= nil)
		return
	end

	settings = settings or {}

	stopRenderConnection()
	stopCurrentTween()

	CameraModule._prevDist = nil

	Camera.CameraType = originalCameraType or Enum.CameraType.Custom

	if settings.Instant then
		if originalCFrame then
			Camera.CFrame = originalCFrame
		end
		if originalFieldOfView then
			Camera.FieldOfView = originalFieldOfView
		end
		isCustomCamera = false
		originalCFrame = nil
		originalCameraType = nil
		originalFieldOfView = nil
	else
		if originalCFrame then
			local tweenProperties = {CFrame = originalCFrame}
			if originalFieldOfView then
				tweenProperties.FieldOfView = originalFieldOfView
			end

			local duration = settings.Duration or DEFAULT_TWEEN_TIME
			local easingStyle = settings.EasingStyle or DEFAULT_EASING_STYLE
			local easingDirection = settings.EasingDirection or DEFAULT_EASING_DIRECTION

			currentTween = TweenService:Create(
				Camera,
				TweenInfo.new(duration, easingStyle, easingDirection),
				tweenProperties
			)
			currentTween:Play()

			currentTween.Completed:Once(function()
				isCustomCamera = false
				originalCFrame = nil
				originalCameraType = nil
				originalFieldOfView = nil
				currentTween = nil
			end)
		else
			isCustomCamera = false
		end
	end
end

function CameraModule.RestoreCameraInstant()
	return CameraModule.RestoreCamera({Instant = true})
end

function CameraModule.SetFieldOfView(fov: number, duration: number?)
	local tweenDuration = duration or 0.5

	stopCurrentTween()

	currentTween = TweenService:Create(
		Camera,
		TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{FieldOfView = fov}
	)
	currentTween:Play()

	currentTween.Completed:Once(function()
		currentTween = nil
	end)

	return currentTween
end

function CameraModule.ShakeCamera(options)
	options = options or {}

	local magnitude  = options.magnitude  or 20
	local position   = options.position   or Vector3.zero
	local radius     = options.radius     or 15
	local duration   = options.duration   or 0.3
	local fadeIn     = options.fadeIn     or 0.05
	local fadeOut    = options.fadeOut    or 0.15

	local character = localPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local dist = (hrp.Position - position).Magnitude
		if dist > radius then return end
		magnitude = magnitude * (1 - (dist / radius))
	end

	local startTime = tick()
	local shakeConnection

	shakeConnection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		if elapsed >= duration then
			shakeConnection:Disconnect()
			return
		end

		local envelope
		if elapsed < fadeIn then
			envelope = elapsed / fadeIn
		elseif elapsed > duration - fadeOut then
			envelope = (duration - elapsed) / fadeOut
		else
			envelope = 1
		end

		local intensity = magnitude * envelope

		local offsetX = (math.random() * 2 - 1) * intensity * 0.01
		local offsetY = (math.random() * 2 - 1) * intensity * 0.01

		Camera.CFrame = Camera.CFrame * CFrame.new(offsetX, offsetY, 0)
	end)
end

function CameraModule.IsCustomCamera(): boolean
	return isCustomCamera
end

function CameraModule.GetOriginalCFrame(): CFrame?
	return originalCFrame
end

function CameraModule.GetCurrentTween(): Tween?
	return currentTween
end

function CameraModule.StopTween()
	stopCurrentTween()
end

function CameraModule.ClearFightingCamera()
	savedFightingCamera = nil
end

function CameraModule.StopFightingCamera()
	warn("[CameraModule] StopFightingCamera | isCustomCamera:", isCustomCamera, "| originalCFrame:", originalCFrame ~= nil)

	fightingCameraActive = false
	stopRenderConnection()
	CameraModule._prevDist = nil
	_zoomOffset       = 0
	_zoomTimer        = 0
	_zoomRestoring    = false
	_fightCamFirstFrame = false
	isCustomCamera      = false
	originalCFrame      = nil
	originalCameraType  = nil
	originalFieldOfView = nil

	warn("[CameraModule] StopFightingCamera concluído | estado limpo")
end

function CameraModule.SetFightingCamera(p1: BasePart, p2: BasePart, config): RBXScriptConnection?
	config = config or {}

	savedFightingCamera = {p1 = p1, p2 = p2, config = config}

	saveOriginalCamera()
	stopRenderConnection()
	stopCurrentTween()

	local cfg = {
		BaseOffset        = config.BaseOffset        or Vector3.new(0, 0, 2),
		MinZoom           = config.MinZoom           or 16,
		MaxZoom           = config.MaxZoom           or 70,
		MaxPlayerDistance = config.MaxPlayerDistance or 25,
		Smoothness        = config.Smoothness        or 4,
		SideClamp         = config.SideClamp         or math.huge,
		FixedFOV          = config.FixedFOV          or 50,
		CharacterClamp    = false,
		CharacterMargin   = config.CharacterMargin   or 1,
	}

	local function calcRequiredZoom(dist: number, fovDeg: number, minZoom: number, maxZoom: number, margin: number): number
		local vp = Camera.ViewportSize
		if vp.X == 0 or vp.Y == 0 then return minZoom end

		local halfFOVRad = math.rad(fovDeg / 2)
		local aspect     = vp.X / vp.Y
		local halfSpan   = dist / 2 + (margin or 2)

		if aspect == 0 or halfFOVRad == 0 then return minZoom end  -- evita divisão por zero

		local requiredZoom = halfSpan / (math.tan(halfFOVRad) * aspect)

		if requiredZoom ~= requiredZoom or requiredZoom >= math.huge or requiredZoom <= 0 then
			return minZoom
		end

		return math.max(requiredZoom, minZoom)
	end

	-- No topo de SetFightingCamera, antes do renderConnection:
	local MaxZDepth = config.MaxZDepth or 35  -- limite de Z em studs, configurável

	local character = Players.LocalPlayer.Character
	local localPart = (p1.Parent == character) and p1 or p2

	local DIST_JIGGLE = 10
	local spawnDist = (p1.Position - p2.Position).Magnitude
	local effectiveMaxDist = math.max(spawnDist, cfg.MaxPlayerDistance) + DIST_JIGGLE

	Camera.CameraType = Enum.CameraType.Scriptable
	Camera.FieldOfView = cfg.FixedFOV
	isCustomCamera = true
	fightingCameraActive = true

	-- calcula a CFrame inicial e snapa instantaneamente antes de ligar o loop
	do
		local pos1 = p1.Position
		local pos2 = p2.Position
		local mid  = (pos1 + pos2) * 0.5 + Vector3.new(0, 1.3, 0)
		local dist = (pos1 - pos2).Magnitude
		local zoom = calcRequiredZoom(dist, cfg.FixedFOV, cfg.MinZoom, cfg.MaxZoom, cfg.CharacterMargin)
		zoom = math.max(zoom, cfg.MinZoom)
		local snapPos = mid + cfg.BaseOffset.Unit * zoom
		snapPos = Vector3.new(
			math.clamp(snapPos.X, -cfg.SideClamp, cfg.SideClamp),
			snapPos.Y,
			snapPos.Z
		)
		Camera.CFrame = CFrame.lookAt(snapPos, mid)
	end

	-- ativa o flag para o primeiro tick do loop ainda usar t=1 (garante consistência)
	_fightCamFirstFrame = true
	local _lockedZoom = nil

	renderConnection = RunService.RenderStepped:Connect(function(dt)

		if not fightingCameraActive then
			stopRenderConnection()
			return
		end

		if not (p1 and p1.Parent and p2 and p2.Parent) then
			stopRenderConnection()
			fightingCameraActive = false
			CameraModule.RestoreCamera()
			return
		end

		local pos1 = p1.Position
		local pos2 = p2.Position
		local rawDist = (pos1 - pos2).Magnitude

		if rawDist > effectiveMaxDist and cfg.CharacterClamp then
			local dir = (pos2 - pos1).Unit
			local excess = (rawDist - effectiveMaxDist) * 0.5

			local hrp1 = p1.Name == "HumanoidRootPart" and p1
				or (p1.Parent and p1.Parent:FindFirstChild("HumanoidRootPart")) or p1
			local hrp2 = p2.Name == "HumanoidRootPart" and p2
				or (p2.Parent and p2.Parent:FindFirstChild("HumanoidRootPart")) or p2

			local pushT = math.min(cfg.Smoothness * dt * 2, 1)

			local target1 = hrp1.Position + dir * excess
			local target2 = hrp2.Position - dir * excess

			local function safePush(hrp: BasePart, target: Vector3)
				local newPos = hrp.Position:Lerp(target, pushT)
				local _, yaw, _ = hrp.CFrame:ToEulerAnglesYXZ()
				hrp.CFrame = CFrame.new(newPos) * CFrame.fromEulerAnglesYXZ(0, yaw, 0)
			end

			safePush(hrp1, target1)
			safePush(hrp2, target2)

			local vel1 = hrp1.AssemblyLinearVelocity
			local vel2 = hrp2.AssemblyLinearVelocity
			if vel1:Dot(dir) < 0 then
				hrp1.AssemblyLinearVelocity = Vector3.new(0, vel1.Y, 0)
			end
			if vel2:Dot(-dir) < 0 then
				hrp2.AssemblyLinearVelocity = Vector3.new(0, vel2.Y, 0)
			end
		end

		local dist = rawDist

		local mid = (p1.Position + p2.Position) * 0.5 + Vector3.new(0, 1.3, 0)

		local alpha = math.clamp(dist / effectiveMaxDist, 0, 1)
		alpha = alpha ^ 0.4
		-- Zoom geométrico pelo FOV real — sem limite máximo
		local zoom = calcRequiredZoom(dist, cfg.FixedFOV, cfg.MinZoom, cfg.MaxZoom, cfg.CharacterMargin)
		zoom = math.max(zoom, cfg.MinZoom)
		if zoom ~= zoom or zoom >= math.huge then return end  -- ignora o frame inteiro se zoom for inválido

		if _zoomOffset > 0 then
			if _zoomTimer > 0 then
				_zoomTimer = _zoomTimer - dt
				_zoomRestoring = false
			else
				_zoomRestoring = true
				local lerpSpeed = 3
				_zoomOffset = math.max(0, _zoomOffset - lerpSpeed * dt)
			end
			zoom = zoom + _zoomOffset
		end

		-- Edge detection: ainda expande se personagem estiver perto da borda
		local function getScreenMargin(worldPos: Vector3): number
			local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
			if not onScreen then return -math.huge end
			local vp = Camera.ViewportSize
			local mx = math.min(screenPos.X / vp.X, 1 - screenPos.X / vp.X)
			local my = math.min(screenPos.Y / vp.Y, 1 - screenPos.Y / vp.Y)
			return math.min(mx, my)
		end

		local EDGE_THRESHOLD  = 0.08
		local EDGE_ZOOM_SPEED = 12

		local margin1   = getScreenMargin(p1.Position + Vector3.new(0, 2, 0))
		local margin2   = getScreenMargin(p2.Position + Vector3.new(0, 2, 0))
		local minMargin = math.min(margin1, margin2)

		if minMargin > -math.huge and minMargin < EDGE_THRESHOLD then
			local deficit = math.clamp((EDGE_THRESHOLD - minMargin) / EDGE_THRESHOLD, 0, 1)
			zoom = zoom + deficit * EDGE_ZOOM_SPEED
		end

		zoom = math.max(zoom, cfg.MinZoom)
		if zoom ~= zoom or zoom >= math.huge then return end  -- ← guard final antes de usar o zoom

		local desiredPos = mid + cfg.BaseOffset.Unit * zoom

		desiredPos = Vector3.new(
			math.clamp(desiredPos.X, -cfg.SideClamp, cfg.SideClamp),
			desiredPos.Y,
			desiredPos.Z
		)

		-- SUBSTITUI o bloco inteiro do zDepth/zRatio:

		local baseDesiredPos = mid + cfg.BaseOffset.Unit * zoom
		local zDepth = math.abs(baseDesiredPos.Z - mid.Z)

		local hysteresisBand = 5
		local enterThreshold = MaxZDepth
		local exitThreshold  = MaxZDepth - hysteresisBand

		local zRatio = 0

		if _lockedZoom then
			-- usa zDepth do zoom ATUAL (distância real) pra decidir se sai
			local currentZoom = calcRequiredZoom(dist, cfg.FixedFOV, cfg.MinZoom, cfg.MaxZoom, cfg.CharacterMargin)
			local currentBasePos = mid + cfg.BaseOffset.Unit * currentZoom
			local currentZDepth = math.abs(currentBasePos.Z - mid.Z)

			local ratio = math.clamp((currentZDepth - exitThreshold) / 4, 0, 1)
			if ratio <= 0 then
				_lockedZoom = nil
				zRatio = 0
				-- zoom já está correto (foi calculado acima como currentZoom)
				zoom = currentZoom
			else
				zoom = _lockedZoom
				zRatio = ratio
			end
		else
			local ratio = math.clamp((zDepth - enterThreshold) / 4, 0, 1)
			if ratio > 0 then
				_lockedZoom = zoom
				zoom = _lockedZoom
				zRatio = ratio
			end
		end

		-- reconstrói desiredPos com o zoom (possivelmente travado)
		local desiredPos = mid + cfg.BaseOffset.Unit * zoom

		local localPos = localPart.Position
		local pivotX = mid.X + (localPos.X - mid.X) * zRatio
		desiredPos = Vector3.new(
			math.clamp(pivotX, -cfg.SideClamp, cfg.SideClamp),
			desiredPos.Y,
			desiredPos.Z
		)

		local lookTarget = mid + Vector3.new((localPos.X - mid.X) * zRatio, 0, 0)
		local desiredCFrame = CFrame.lookAt(desiredPos, lookTarget)

		local prevDist = CameraModule._prevDist or dist
		CameraModule._prevDist = dist

		-- primeiro frame: snap instantâneo (t=1), depois suaviza normalmente
		local t
		if _fightCamFirstFrame then
			t = 1
			_fightCamFirstFrame = false
		else
			local isZoomingOut = dist > prevDist
			local smooth = isZoomingOut and (cfg.Smoothness * 2.5) or cfg.Smoothness
			t = 1 - math.exp(-smooth * dt)
		end

		Camera.CFrame = Camera.CFrame:Lerp(desiredCFrame, t)

		if cfg.CharacterClamp then
			local minX, maxX = getHorizontalBounds(Camera.CFrame, mid, cfg.FixedFOV)
			clampCharacterToCamera(p1, minX, maxX, cfg.CharacterMargin)
			clampCharacterToCamera(p2, minX, maxX, cfg.CharacterMargin)

			local zoomRatio = (zoom - cfg.MinZoom) / (cfg.MaxZoom - cfg.MinZoom)
			local atMaxZoom = zoomRatio >= 0.97

			local function applySpeedLock(part, minX, maxX, margin)
				local hum = part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")
				if not hum then return end

				local px = part.Position.X
				local atLeft  = px <= (minX + margin + 0.1)
				local atRight = px >= (maxX - margin - 0.1)

				if atMaxZoom and (atLeft or atRight) then
					local vel = part.AssemblyLinearVelocity
					if atLeft  and vel.X < 0 then
						part.AssemblyLinearVelocity = Vector3.new(0, vel.Y, vel.Z)
					end
					if atRight and vel.X > 0 then
						part.AssemblyLinearVelocity = Vector3.new(0, vel.Y, vel.Z)
					end

					local other = (part == p1) and p2 or p1
					local dir = (other.Position - part.Position) * Vector3.new(1, 0, 1)

					if dir.Magnitude > 0.01 then
						local hrp = part.Parent and part.Parent:FindFirstChild("HumanoidRootPart") or part
						hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + dir)
					end
				end
			end

			applySpeedLock(p1, minX, maxX, cfg.CharacterMargin)
			applySpeedLock(p2, minX, maxX, cfg.CharacterMargin)
		end
	end)

	return renderConnection
end

function CameraModule.ApplyTemporaryZoom(studs: number)
	if not fightingCameraActive then return end

	_zoomOffset  = math.min(_zoomOffset + studs, CombatCameraZoomMaxStack)
	_zoomTimer   = CombatCameraZoomTimeout
	_zoomRestoring = false
end

	--[[
	    SetAnimatedCamera (atualizado)

	    config:
	      CameraModel     (Model)
	      Animation       (Animation)
	      CamPartName     (string)        default: "Cam"
	      Offset          (CFrame)        offset de spawn
	      WeldToCharacter (boolean)       se true, weld automático no HRP do player
	      WeldC0          (CFrame)        C0 do Motor6D  (default: CFrame.new(0,0,0))
	      WeldC1          (CFrame)        C1 do Motor6D  (default: CFrame.new(0,0,0))
	      OnEnd           (function)
	      RestoreInstant  (boolean)
	]]
function CameraModule.SetAnimatedCamera(config)
	config = config or {}

	local localPlayer   = Players.LocalPlayer
	local character     = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local hrp           = character:WaitForChild("HumanoidRootPart")

	local cameraModel    = config.CameraModel
	local animation      = config.Animation
	local camPartName    = config.CamPartName    or "Cam"
	local spawnOffset    = config.Offset         or CFrame.new(0, 0, 0)
	local onEnd          = config.OnEnd
	local restoreInstant = config.RestoreInstant ~= nil and config.RestoreInstant or true
	local weldToChar     = config.WeldToCharacter ~= nil and config.WeldToCharacter or false
	local weldC0         = config.WeldC0         or CFrame.new(0, 0, 0)
	local weldC1         = config.WeldC1         or CFrame.new(0, 0, 0)

	assert(cameraModel, "[CameraModule] SetAnimatedCamera: CameraModel é obrigatório")
	assert(animation,   "[CameraModule] SetAnimatedCamera: Animation é obrigatório")

	saveOriginalCamera()
	stopRenderConnection()
	stopCurrentTween()
	isCustomCamera = true

	local clonedModel = cameraModel:Clone()
	clonedModel.Parent = character

	local modelHRP = clonedModel:FindFirstChild("RootPart") or clonedModel:FindFirstChild("HumanoidRootPart") or clonedModel.PrimaryPart
	assert(modelHRP, "[CameraModule] SetAnimatedCamera: CameraModel precisa de HumanoidRootPart")

	local motor = nil
	if weldToChar then
		modelHRP.Anchored = false
		modelHRP.CanCollide = false

		motor = Instance.new("Weld")
		motor.Name = "CutsceneCameraWeld"
		motor.Part0 = hrp
		motor.Part1 = modelHRP
		motor.C0    = weldC0
		motor.C1    = weldC1
		motor.Parent = hrp
	end

	local humanoid = clonedModel:FindFirstChildWhichIsA("Humanoid")
	local animController = clonedModel:FindFirstChildWhichIsA("AnimationController")
	local animator = humanoid or animController
	assert(animator, "[CameraModule] SetAnimatedCamera: CameraModel precisa de Humanoid ou AnimationController")

	local animatorInstance = animator:FindFirstChildOfClass("Animator") or Instance.new("Animator", animator)
	local track = animatorInstance:LoadAnimation(animation)
	track:Play()
	track:AdjustSpeed(config.AnimationSpeed or 1)

	Camera.CameraType = Enum.CameraType.Scriptable
	Camera.CFrame = modelHRP.CFrame

	renderConnection = RunService.RenderStepped:Connect(function()
		local camPart = clonedModel:FindFirstChild(camPartName, true)
		if camPart then
			Camera.CFrame = camPart.CFrame
		end
	end)

	track.Stopped:Once(function()
		stopRenderConnection()

		if motor and motor.Parent then
			motor:Destroy()
		end

		clonedModel:Destroy()

		isCustomCamera = false
		originalCFrame = nil
		originalCameraType = nil
		originalFieldOfView = nil

		if savedFightingCamera then
			local s = savedFightingCamera
			CameraModule.SetFightingCamera(s.p1, s.p2, s.config)
		else
			Camera.CameraType = Enum.CameraType.Custom
			Camera.FieldOfView = 70
			Camera.CameraSubject = character:FindFirstChildWhichIsA("Humanoid")
		end

		if onEnd then
			task.spawn(onEnd)
		end
	end)

	return track
end

return CameraModule