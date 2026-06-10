local module = {}

--[[
	KnockbackService — Tween-based knockback (CFrame endpoint via TweenService)
	
	Profile format:
	{
		Offset         = CFrame  -- deslocamento relativo ao atacante (X=lateral, Y=altura, Z=profundidade)
		                          -- ou Vector3 se quiser só posição, ou usar helpers abaixo
		Duration       = number  -- duração do tween em segundos
		Style          = Enum.EasingStyle (opcional, default Quad)
		Ease           = Enum.EasingDirection (opcional, default Out)
		RelativeToLook = bool    -- se true, usa a direção do ATACANTE; se false, usa a do alvo
		SmartPosition  = bool    -- corrige posição pelo momentum antes de aplicar
		WallCheck      = bool    -- faz raycast pra não atravessar paredes
	}
--]]

local TweenService   = game:GetService("TweenService")
local Debris         = game:GetService("Debris")

local KnockbackRemote   = game.ReplicatedStorage.CombatSystem.Events.ApplyKnockbackClient
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local CombatReplicator  = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local PlayAnimation     = require(game.ReplicatedStorage.CombatSystem.PlayAnimationServer)
local CombatUtils       = require(game.ReplicatedStorage.CombatSystem.CombatUtils)

local KNOCKDOWN_TOKEN_ATTR = "__KnockdownToken"
local FlipEvent            = game.ReplicatedStorage.CombatSystem.Events.FlipCharacter

local CanContinueComboTime = 0.7

-- ─────────────────────────────────────────────────────────────────────────────
-- Raycast list (paredes do workspace — ajuste conforme seu jogo)
-- ─────────────────────────────────────────────────────────────────────────────
local wallRayParams = RaycastParams.new()
wallRayParams.FilterType = Enum.RaycastFilterType.Include
-- Adicione as instâncias de parede do seu jogo aqui:
wallRayParams.FilterDescendantsInstances = {workspace.Map}

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

--- Prevê a posição do personagem com base na velocidade atual (suaviza snap)
local function PredictPos(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return CFrame.identity end
	local vel = root.AssemblyLinearVelocity
	-- pequena projeção (~1 frame de física)
	return CFrame.new(root.Position + vel * 0.05)
end

--- Calcula o CFrame de destino baseado no profile e nas partes envolvidas
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
		local rotatedOffset = attackerRotation * offset
		local rawEndPoint = CFrame.new(basePos.Position + rotatedOffset.Position) * basePos.Rotation

		if profile.WallCheck then
			local origin = basePos.Position
			local dir = rawEndPoint.Position - origin
			local hit = workspace:Raycast(origin, dir, wallRayParams)
			if hit then
				local safeLen = math.max(hit.Distance - 1, 0)
				rawEndPoint = CFrame.new(origin + dir.Unit * safeLen) * basePos.Rotation
			end
		end

		return rawEndPoint
	end

	-- Sem RelativeToLook: usa orientação da própria vítima
	local rawEndPoint = basePos * offset

	if profile.WallCheck then
		local origin = basePos.Position
		local dir = rawEndPoint.Position - origin
		local hit = workspace:Raycast(origin, dir, wallRayParams)
		if hit then
			local safeLen = math.max(hit.Distance - 1, 0)
			rawEndPoint = CFrame.new(origin + dir.Unit * safeLen) * basePos.Rotation
		end
	end

	return rawEndPoint
end

--- Cancela tweens de knockback anteriores num personagem
local function CancelActiveTween(root)
	local existing = root:FindFirstChild("__KBTween")
	if existing then
		-- Zera antes de cancelar
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		existing.Value = true
		existing:Destroy()
	end
end

local function ApplyKnockbackTweenServer(profile, character, attackerCharacter)
	if profile.None then return end

	local root     = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end

	local attackerRoot = attackerCharacter and attackerCharacter:FindFirstChild("HumanoidRootPart")

	-- ── IsSelfImpulse: LinearVelocity, não trava posição ──
	if profile.IsSelfImpulse then
		local offset = profile.Offset
		local worldDir

		if profile.RelativeToLook and attackerRoot then
			worldDir = attackerRoot.CFrame:VectorToWorldSpace(
				Vector3.new(offset.X, offset.Y, -offset.Z)
			)
		else
			worldDir = Vector3.new(offset.X, offset.Y, offset.Z)
		end

		-- Remove LinearVelocity anterior do mesmo tipo
		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("LinearVelocity") and obj.Name == "__SelfImpulseLV" then
				obj.Attachment0:Destroy()
				obj:Destroy()
			end
		end

		local attachment = Instance.new("Attachment")
		attachment.Name = "__SelfImpulseAttach"
		attachment.Parent = root

		local lv = Instance.new("LinearVelocity")
		lv.Name = "__SelfImpulseLV"
		lv.Attachment0 = attachment
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.MaxForce = math.huge
		lv.VectorVelocity = worldDir / profile.Duration
		lv.Parent = root

		Debris:AddItem(lv, profile.Duration)
		Debris:AddItem(attachment, profile.Duration)
		return
	end

	-- ── Tween: posição absoluta para vítimas ──
	local endPoint = ComputeEndPoint(profile, root, attackerRoot)
	local duration = profile.Duration or 0.3
	local style    = profile.Style or Enum.EasingStyle.Quad
	local ease     = profile.Ease  or Enum.EasingDirection.Out

	CancelActiveTween(root)
	
	for _, obj in ipairs(root:GetChildren()) do
		if obj:IsA("BodyVelocity") or obj:IsA("LinearVelocity") then
			obj:Destroy()
		end
	end

	local bv = Instance.new("BodyVelocity")
	bv.Name     = "__KnockbackPhysicsLock"
	bv.MaxForce = Vector3.new(50000, 50000, 50000)
	bv.Velocity = Vector3.new(0, 0, 0)
	bv.Parent   = root

	local sentinel = Instance.new("BoolValue")
	sentinel.Name  = "__KBTween"
	sentinel.Value = false
	sentinel.Parent = root

	local tween = TweenService:Create(root, TweenInfo.new(duration, style, ease), { CFrame = endPoint })
	tween:Play()

	tween.Completed:Once(function()
		-- Zera velocidade acumulada antes de soltar o controle
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero

		if sentinel.Parent then sentinel:Destroy() end
		if bv.Parent then bv:Destroy() end
	end)

	return tween
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Token de knockdown (evita sobreposição de estados)
-- ─────────────────────────────────────────────────────────────────────────────

local function AcquireKnockdownToken(character): number
	local existing = character:GetAttribute(KNOCKDOWN_TOKEN_ATTR)
	if existing then
		StateManager.REMOVE(character, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		StateManager.REMOVE(character, StateManagerEnums.STATES_ENUM.COMBAT_IFRAME)
	end
	local token = os.clock()
	character:SetAttribute(KNOCKDOWN_TOKEN_ATTR, token)
	StateManager.POST(character, StateManagerEnums.STATES_ENUM.COMBAT_IN_KNOCKDOWN)
	return token
end

local function IsTokenValid(character, token): boolean
	return character:GetAttribute(KNOCKDOWN_TOKEN_ATTR) == token
end

local function ReleaseKnockdownToken(character, token)
	if IsTokenValid(character, token) then
		character:SetAttribute(KNOCKDOWN_TOKEN_ATTR, nil)
		StateManager.REMOVE(character, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		StateManager.REMOVE(character, StateManagerEnums.STATES_ENUM.COMBAT_IFRAME)
		StateManager.REMOVE(character, StateManagerEnums.STATES_ENUM.COMBAT_IN_KNOCKDOWN)
	end
end

local function deepCleanup(character)
	local states = {
		StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED,
		StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED,
		StateManagerEnums.STATES_ENUM.COMBAT_SLIGHTLY_STUNNED,
		StateManagerEnums.STATES_ENUM.COMBAT_CROUCHING,
	}
	for _, state in ipairs(states) do
		while StateManager.GET(character)[state] do
			StateManager.REMOVE(character, state)
		end
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Float helper (mantém personagem no ar durante knockdown aéreo)
-- ─────────────────────────────────────────────────────────────────────────────

local function ApplyFloat(character, duration)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	for _, obj in ipairs(root:GetChildren()) do
		if obj.Name == "__FloatHold" then obj:Destroy() end
	end
	local bv        = Instance.new("BodyVelocity")
	bv.Name         = "__FloatHold"
	bv.MaxForce     = Vector3.new(0, 1e5, 0)
	bv.Velocity     = Vector3.new(0, 0, 0)
	bv.Parent       = root
	Debris:AddItem(bv, duration)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ExecuteKnockdown — controla estados + animações após o knockback
-- A transição é seamless: o tween de CFrame já posicionou o personagem;
-- o knockdown assume o controle de estado imediatamente em paralelo.
-- ─────────────────────────────────────────────────────────────────────────────

local function SerializeProfile(profile)
	local serialized = {}
	for k, v in pairs(profile) do
		if typeof(v) == "CFrame" then
			serialized[k] = { __type = "CFrame", components = {v:GetComponents()} }
		elseif typeof(v) == "Vector3" then
			serialized[k] = { __type = "Vector3", x = v.X, y = v.Y, z = v.Z }
		else
			serialized[k] = v
		end
	end
	return serialized
end

local function ExecuteKnockdown(VictimCharacter, KnockdownInfo)
	task.spawn(function()
		local myToken = AcquireKnockdownToken(VictimCharacter)
		StateManager.POST(VictimCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

		-- Animação no ar (se aplicável)
		if KnockdownInfo.InAirAnim then
			PlayAnimation.PlayCharacterAnimation(VictimCharacter, KnockdownInfo.InAirAnim)
			if not IsTokenValid(VictimCharacter, myToken) then return end
			task.wait(0.5)

			local hrp = VictimCharacter:FindFirstChild("HumanoidRootPart")
			while CombatUtils.IsCharacterInAir(VictimCharacter) do
				task.wait()
				if not IsTokenValid(VictimCharacter, myToken) then return end
				if hrp and hrp.AssemblyLinearVelocity.Y < -5 then
					break
				end
			end
		end

		-- Queda
		local fallingTrack = PlayAnimation.PlayCharacterAnimation(VictimCharacter, KnockdownInfo.FallAnim)
		while CombatUtils.IsCharacterInAir(VictimCharacter) do
			task.wait()
			if not IsTokenValid(VictimCharacter, myToken) then return end
		end

		if fallingTrack then PlayAnimation.StopAnimation(VictimCharacter, fallingTrack) end
		
		local adicionalStopTime = 0
		
		if KnockdownInfo.CanContinueCombo then
			adicionalStopTime += CanContinueComboTime
		end
		
		local fallTrack = PlayAnimation.PlayCharacterAnimation(VictimCharacter, KnockdownInfo.GroundAnim, KnockdownInfo.Duration + adicionalStopTime)

		-- Janela de combo continuado
		if KnockdownInfo.CanContinueCombo then
			CombatReplicator.Highlight(VictimCharacter, { Color = Color3.fromRGB(15, 231, 255), Duration = CanContinueComboTime })
			task.wait(CanContinueComboTime)
			if not IsTokenValid(VictimCharacter, myToken) then return end
		end

		-- Iframe no chão
		StateManager.POST(VictimCharacter, StateManagerEnums.STATES_ENUM.COMBAT_IFRAME)
		CombatReplicator.Highlight(VictimCharacter, {
			Color    = Color3.fromRGB(255, 255, 255),
			Duration = KnockdownInfo.Duration + 0.5,
		})

		task.wait(KnockdownInfo.Duration)
		if not IsTokenValid(VictimCharacter, myToken) then return end

		-- Wake-up
		local wakeUpTrack
		
		if not StateManager.GET(VictimCharacter)[StateManagerEnums.STATES_ENUM.COMBAT_FROZEN_STUNNED] then
			wakeUpTrack = PlayAnimation.PlayCharacterAnimation(VictimCharacter, KnockdownInfo.WakeUpAnim)
		end

		if KnockdownInfo.WakeUpKnockback and not StateManager.GET(VictimCharacter)[StateManagerEnums.STATES_ENUM.COMBAT_FROZEN_STUNNED] then
			local victimPlayer = game.Players:GetPlayerFromCharacter(VictimCharacter)	
			if victimPlayer then
				KnockbackRemote:FireClient(victimPlayer, {
					Profile        = SerializeProfile(KnockdownInfo.WakeUpKnockback),
					attackerCFrame = nil,
				})
				--ApplyKnockbackTweenServer(KnockdownInfo.WakeUpKnockback, VictimCharacter, nil)
			else
				-- WakeUpKnockback também é tween-based; sem atacante, offset absoluto
				ApplyKnockbackTweenServer(KnockdownInfo.WakeUpKnockback, VictimCharacter, nil)
			end
		end

		if not wakeUpTrack and fallTrack then
			PlayAnimation.StopAnimation(VictimCharacter, fallTrack)
		end
		if not IsTokenValid(VictimCharacter, myToken) then return end

		StateManager.REMOVE(VictimCharacter, StateManagerEnums.STATES_ENUM.COMBAT_IFRAME)
		StateManager.REMOVE(VictimCharacter, StateManagerEnums.STATES_ENUM.COMBAT_IN_KNOCKDOWN)
		deepCleanup(VictimCharacter)
		ReleaseKnockdownToken(VictimCharacter, myToken)
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ApplyKnockback — ponto de entrada público
-- ─────────────────────────────────────────────────────────────────────────────

--[[
	knockbackTable = {
		Profile       = <KnockbackProfile>,
		KnockdownInfo = <KnockdownInfo> (opcional),
	}
	
	Para players: dispara KnockbackRemote com Profile + attackerCFrame
	  → o cliente faz o tween localmente (responsividade)
	Para bots:   ApplyKnockbackTweenServer direto no servidor
	
	O KnockdownInfo (estados + animações) é sempre gerenciado pelo servidor.
--]]

function module.ApplyKnockback(knockbackTable, character, delayTime, attackerCharacter)
	delayTime = tonumber(delayTime) or 0

	local profile = knockbackTable.Profile
	if typeof(profile) ~= "table" or not character then
		warn("[KnockbackService] Profile ou Character inválido")
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root     = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end

	local victimPlayer = game.Players:GetPlayerFromCharacter(character)

	task.delay(delayTime, function()
		if humanoid.Health <= 0 then return end

		if victimPlayer then
			local attackerCFrame = nil
			if attackerCharacter then
				local ar = attackerCharacter:FindFirstChild("HumanoidRootPart")
				if ar then attackerCFrame = ar.CFrame end
			end

			print("firing knockback to", victimPlayer.Name)
			KnockbackRemote:FireClient(victimPlayer, {
				Profile        = SerializeProfile(profile),
				attackerCFrame = attackerCFrame,
			})
			print("fired")
		else
			ApplyKnockbackTweenServer(profile, character, attackerCharacter)
		end

		if knockbackTable.KnockdownInfo then
			ExecuteKnockdown(character, knockbackTable.KnockdownInfo)
		end
	end)
end

-- Exposto para uso interno (ex: wake-up bots, testes)
module.ApplyKnockbackTweenServer = ApplyKnockbackTweenServer
module.ComputeEndPoint           = ComputeEndPoint

return module