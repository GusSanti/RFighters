-- StarterPlayerScripts/KnockbackReplicator
local TweenService = game:GetService("TweenService")
local Debris       = game:GetService("Debris")
local localPlayer  = game.Players.LocalPlayer

local KnockbackRemote = game.ReplicatedStorage.CombatSystem.Events.ApplyKnockbackClient

local wallRayParams = RaycastParams.new()
wallRayParams.FilterType = Enum.RaycastFilterType.Include
wallRayParams.FilterDescendantsInstances = {workspace:WaitForChild("Map")}

local function DeserializeProfile(profile)
	local deserialized = {}
	for k, v in pairs(profile) do
		if type(v) == "table" and v.__type == "CFrame" then
			deserialized[k] = CFrame.new(table.unpack(v.components))
		elseif type(v) == "table" and v.__type == "Vector3" then
			deserialized[k] = Vector3.new(v.x, v.y, v.z)
		else
			deserialized[k] = v
		end
	end
	return deserialized
end

local function PredictPos(char)
	local r = char:FindFirstChild("HumanoidRootPart")
	if not r then return CFrame.identity end
	return CFrame.new(r.Position + r.AssemblyLinearVelocity * 0.05)
end

local function ComputeEndPoint(profile, victimRoot, attackerRoot)
	local offset = profile.Offset

	local basePos
	if profile.SmartPosition then
		basePos = PredictPos(victimRoot.Parent) * victimRoot.CFrame.Rotation
	else
		basePos = victimRoot.CFrame
	end

	if profile.RelativeToLook and attackerRoot then
		local attackerRotation = attackerRoot.CFrame - attackerRoot.CFrame.Position
		local rotatedOffset    = attackerRotation * offset
		local rawEndPoint      = CFrame.new(basePos.Position + rotatedOffset.Position) * basePos.Rotation

		if profile.WallCheck then
			local origin = basePos.Position
			local dir    = rawEndPoint.Position - origin
			local hit    = workspace:Raycast(origin, dir, wallRayParams)
			if hit then
				local safeLen = math.max(hit.Distance - 1, 0)
				rawEndPoint   = CFrame.new(origin + dir.Unit * safeLen) * basePos.Rotation
			end
		end

		return rawEndPoint
	end

	local rawEndPoint = basePos * (offset or CFrame.new())

	if profile.WallCheck then
		local origin = basePos.Position
		local dir    = rawEndPoint.Position - origin
		local hit    = workspace:Raycast(origin, dir, wallRayParams)
		if hit then
			local safeLen = math.max(hit.Distance - 1, 0)
			rawEndPoint   = CFrame.new(origin + dir.Unit * safeLen) * basePos.Rotation
		end
	end

	return rawEndPoint
end

local function CancelActiveTween(r)
	local existing = r:FindFirstChild("__KBTween")
	if existing then
		r.AssemblyLinearVelocity  = Vector3.zero
		r.AssemblyAngularVelocity = Vector3.zero
		existing.Value = true
		existing:Destroy()
	end
end

local function ApplyKnockbackLocal(data)
	local character = localPlayer.Character
	if not character then return end

	local root     = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	
	if not data.Profile then return end

	local profile    = DeserializeProfile(data.Profile)
	local attackerCF = data.attackerCFrame

	if not profile or not root or not humanoid then return end
	if humanoid.Health <= 0 then return end

	if profile.IsSelfImpulse then
		local offset   = profile.Offset
		local worldDir

		if profile.RelativeToLook and attackerCF then
			worldDir = attackerCF:VectorToWorldSpace(
				Vector3.new(offset.X, offset.Y, -offset.Z)
			)
		else
			worldDir = Vector3.new(offset.X, offset.Y, offset.Z)
		end

		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("LinearVelocity") and obj.Name == "__SelfImpulseLV" then
				obj.Attachment0:Destroy()
				obj:Destroy()
			end
		end

		local attachment  = Instance.new("Attachment")
		attachment.Name   = "__SelfImpulseAttach"
		attachment.Parent = root

		local lv          = Instance.new("LinearVelocity")
		lv.Name           = "__SelfImpulseLV"
		lv.Attachment0    = attachment
		lv.RelativeTo     = Enum.ActuatorRelativeTo.World
		lv.MaxForce       = math.huge
		lv.VectorVelocity = worldDir / profile.Duration
		lv.Parent         = root

		Debris:AddItem(lv, profile.Duration)
		Debris:AddItem(attachment, profile.Duration)
		return
	end

	local fakeAttackerRoot = nil
	if attackerCF then
		fakeAttackerRoot = { CFrame = attackerCF }
	end

	local endPoint = ComputeEndPoint(profile, root, fakeAttackerRoot)
	local duration = profile.Duration or 0.3
	local style    = profile.Style    or Enum.EasingStyle.Quad
	local ease     = profile.Ease     or Enum.EasingDirection.Out

	CancelActiveTween(root)

	for _, obj in ipairs(root:GetChildren()) do
		if obj:IsA("BodyVelocity") or obj:IsA("LinearVelocity") then
			obj:Destroy()
		end
	end

	local bv    = Instance.new("BodyVelocity")
	bv.Name     = "__KnockbackPhysicsLock"
	bv.MaxForce = Vector3.new(50000, 50000, 50000)
	bv.Velocity = Vector3.zero
	bv.Parent   = root

	local sentinel  = Instance.new("BoolValue")
	sentinel.Name   = "__KBTween"
	sentinel.Value  = false
	sentinel.Parent = root

	local tween = TweenService:Create(root, TweenInfo.new(duration, style, ease), { CFrame = endPoint })
	tween:Play()

	tween.Completed:Once(function()
		root.AssemblyLinearVelocity  = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		if sentinel.Parent then sentinel:Destroy() end
		if bv.Parent then bv:Destroy() end
	end)
end

warn("KNOCKBACK REPLICATOR RODANDO")

KnockbackRemote.OnClientEvent:Connect(function(data)
	ApplyKnockbackLocal(data)
end)