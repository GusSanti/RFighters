local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ShakeEvent = game.ReplicatedStorage.CombatSystem.Events:WaitForChild("CharacterShake")

local EffectsReplicatorEvent = ReplicatedStorage.CombatSystem.Events.EffectsReplicatorEvent
local VFX    = require(ReplicatedStorage.Modules.Utilitary.VFX)
local CameraModule = require(ReplicatedStorage.Modules.CameraModule)
local Trove  = require(ReplicatedStorage.Modules.Trove)

-- Utils
local function getAllDescendants(instance)
	return instance:GetDescendants()
end

local function getLongestLifetime(effect)
	local maxLifetime = 0

	for _, obj in ipairs(effect:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then
			local lifetime = obj.Lifetime.Max
			local emitDuration = obj:GetAttribute("EmitDuration") or 0
			local delay = obj:GetAttribute("Delay") or obj:GetAttribute("EmitDelay") or 0

			local totalTime

			if emitDuration > 0 then
				totalTime = delay + emitDuration + lifetime
			else
				totalTime = delay + lifetime
			end

			if totalTime > maxLifetime then
				maxLifetime = totalTime
			end
		end
	end

	return maxLifetime
end

local function emitAll(effect)
	for _, obj in ipairs(getAllDescendants(effect)) do
		if obj:IsA("ParticleEmitter") then
			local emitDuration = obj:GetAttribute("EmitDuration")
			local EmitDelay = obj:GetAttribute("Delay") or obj:GetAttribute("EmitDelay") or 0

			--print(EmitDelay)

			task.delay(EmitDelay, function()
				if emitDuration then
					--print('Enabled')
					obj.Enabled = true

					task.delay(emitDuration, function()
						--print('Disabled')
						if obj then
							obj.Enabled = false
						end
					end)
				else
					--print('Emited')
					local emitCount = obj:GetAttribute("EmitCount") or obj.Rate or 1
					obj:Emit(emitCount)
				end
			end)
		end
	end
end

local function enableAll(effect)
	for _, obj in ipairs(getAllDescendants(effect)) do
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = true
		elseif obj:IsA("Beam") or obj:IsA("Trail") then
			obj.Enabled = true
		elseif obj:IsA("PointLight") or obj:IsA("SpotLight") then
			obj.Enabled = true
		end
	end
end

local function disableAll(effect)
	for _, obj in ipairs(getAllDescendants(effect)) do
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = false
		elseif obj:IsA("Beam") or obj:IsA("Trail") then
			obj.Enabled = false
		elseif obj:IsA("PointLight") or obj:IsA("SpotLight") then
			obj.Enabled = false
		end
	end
end

local function cloneToTarget(effectTemplate, targetPart, c0, c1, onlyPos, orientation)
	local clone = effectTemplate:Clone()
	clone.Parent = targetPart
	local partToWeld

	local orientationCFrame = orientation and CFrame.Angles(
		math.rad(orientation.X),
		math.rad(orientation.Y),
		math.rad(orientation.Z)
	) or CFrame.new()

	if clone:IsA("Model") then
		if clone.PrimaryPart then
			if not onlyPos then
				clone:PivotTo(targetPart.CFrame * orientationCFrame)
			else
				clone:PivotTo(CFrame.new(targetPart.Position) * orientationCFrame)
			end
			partToWeld = clone.PrimaryPart
		end
	elseif clone:IsA("BasePart") then
		if not onlyPos then
			clone.CFrame = targetPart.CFrame * orientationCFrame
		else
			clone.CFrame = CFrame.new(targetPart.Position) * orientationCFrame
		end
		partToWeld = clone
	end

	if partToWeld and (c0 or c1) then
		local weld = Instance.new("Weld")
		weld.Part0 = targetPart
		weld.Part1 = partToWeld
		weld.C0 = c0 or CFrame.new()
		weld.C1 = c1 or CFrame.new()
		weld.Parent = partToWeld
	end
	return clone
end

local function onlyYCF(cf)
	return CFrame.fromOrientation(0, Vector3.new(cf:ToOrientation()).Y, 0)
end

local function destroyVelocity(object)
	for _, d in ipairs(object:GetDescendants()) do
		if d:IsA("LinearVelocity") or d:IsA("BodyPosition") then
			d:Destroy()
		end
	end
end

local function applyBodyPosition(targetPart, options)
	options = options or {}
	local offset     = options.offset     or 1
	local duration   = options.duration   or 0.6
	local tweenInfo  = options.tweenInfo  or {1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out}
	local maxForce   = options.maxForce   or Vector3.new(1, 0, 1) * 30000
	local pValue     = options.pValue     or 12500
	local dValue     = options.dValue     or 300

	destroyVelocity(targetPart)

	local bp = Instance.new("BodyPosition")
	bp.P        = pValue
	bp.D        = dValue
	bp.MaxForce = maxForce
	bp.Parent   = targetPart

	Debris:AddItem(bp, duration)

	TweenService:Create(bp, TweenInfo.new(table.unpack(tweenInfo)), {
		P = 5000,
		D = 600,
	}):Play()

	local trove = Trove.new()
	trove:AttachToInstance(bp)
	trove:Add(bp)
	trove:Add(task.delay(duration, trove.Destroy, trove))
	trove:Add(RunService.PreRender:Connect(function()
		bp.Position = onlyYCF(targetPart.CFrame).Rotation.LookVector * offset + targetPart.Position
	end))
end

EffectsReplicatorEvent.OnClientEvent:Connect(function(action, targetPart, effectTemplate, lifetime, options)
	options = options or {}

	if action == "HIGHLIGHT" then
		if not targetPart then return end
		VFX.Highlight(targetPart, options.Color or Color3.fromRGB(255,0,0), options.Duration or 1)
		return
	end

	if action == "BODYPOSITION" then
		if not targetPart then return end
		applyBodyPosition(targetPart, options)
		return
	end

	if action == "CAMERASHAKE" then
		CameraModule.ShakeCamera(options)
		return
	end

	if not effectTemplate or not targetPart then return end
	local effectClone = cloneToTarget(effectTemplate, targetPart, options.C0, options.C1, options.OnlyPosition, options.Orientation)

	if action == "Emit" then
		emitAll(effectClone)
		Debris:AddItem(effectClone, getLongestLifetime(effectClone) + 0.2)
	end

	if action == "Enable" then
		enableAll(effectClone)
		task.delay(lifetime or 1, function()
			disableAll(effectClone)
			Debris:AddItem(effectClone, getLongestLifetime(effectClone) + 0.2)
		end)
	end
end)

local DEFAULTS = {
	intensity = 0.4,
	duration  = 0.25,
	frequency = 30,
	decay     = 5,
	joints = {
		["Torso"]     = 1.0,  -- Root Joint (HRP → Torso)
		["Head"]      = 0.8,
		["Left Arm"]  = 0.6,
		["Right Arm"] = 0.6,
		["Left Leg"]  = 0.4,
		["Right Leg"] = 0.4,
	},
}

local activeShakes = {}

local function getMotors(character)
	local motors = {}
	for _, v in ipairs(character:GetDescendants()) do
		if v:IsA("Motor6D") and v.Part1 then
			motors[v.Part1.Name] = v
		end
	end
	return motors
end

local function doShake(character, options)
	if not character or not character.Parent then return end

	-- Cancela shake anterior do mesmo personagem
	if activeShakes[character] then
		activeShakes[character] = false
	end

	local cfg = {}
	for k, v in pairs(DEFAULTS) do cfg[k] = v end
	if options then
		for k, v in pairs(options) do cfg[k] = v end
	end

	local token = {}
	activeShakes[character] = token

	local motors  = getMotors(character)
	local offsets = {}
	for name, motor in pairs(motors) do
		offsets[name] = motor.C0
	end

	local elapsed = 0
	local conn

	conn = RunService.Heartbeat:Connect(function(dt)
		if activeShakes[character] ~= token or not character.Parent then
			for name, motor in pairs(motors) do
				if motor.Parent and offsets[name] then motor.C0 = offsets[name] end
			end
			conn:Disconnect()
			if activeShakes[character] == token then activeShakes[character] = nil end
			return
		end

		elapsed += dt

		if elapsed >= cfg.duration then
			for name, motor in pairs(motors) do
				if motor.Parent and offsets[name] then motor.C0 = offsets[name] end
			end
			conn:Disconnect()
			activeShakes[character] = nil
			return
		end

		local t      = elapsed / cfg.duration
		local decay  = math.exp(-cfg.decay * t)
		local wave   = math.sin(elapsed * cfg.frequency * math.pi * 2)
		local shiftX = cfg.intensity * decay * wave

		for name, motor in pairs(motors) do
			if not motor.Parent then continue end
			local weight = cfg.joints[name] or 0
			if weight == 0 then
				motor.C0 = offsets[name]
				continue
			end
			motor.C0 = offsets[name] * CFrame.new(0, (shiftX * weight) / 2, shiftX * weight)
		end
	end)
end

ShakeEvent.OnClientEvent:Connect(function(character, options)
	doShake(character, options)
end)