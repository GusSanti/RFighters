local module = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local Assets        = ReplicatedStorage.SkillStorage.JunoTheBear
local Fx            = Assets.FX
local Sounds        = Assets.Sounds
local Animations    = Assets.Animations

local SendDamageIndicator = game.ReplicatedStorage.Events:WaitForChild("SendDamageIndicator")
local IncreaseUltProgress = game.ReplicatedStorage.Events.IcreaseUltProgress

local CombatReplicator  = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local HitboxModule      = require(ServerStorage.FightModules.HitboxHandler)
local DamageIndicator   = require(ReplicatedStorage.Modules.Shared:WaitForChild("DamageIndicator"))
local knockback         = require(ServerStorage.FightModules.Knockback)
local CombatBlock       = require(game.ReplicatedStorage.CombatSystem.CombatBlock)
local DamageModule      = require(game.ReplicatedStorage.CombatSystem.DamageModule)

-- ═══════════════════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════════════════
local CONFIG = {
	IceMeshName        = "Spike",           -- nome da mesh em Assets.FX
	IceFXName        = "IceFX",
	IceSpawnOffset     = CFrame.new(0, -0.5, -5), -- posição relativa ao HumRP

	IceFreezeHitDamage = 8,    -- dano ao congelar (1x por inimigo)
	IceContactDamage   = 3,    -- dano por tick encostado
	IceContactInterval = 0.4,  -- segundos entre ticks de contato

	IceStunDuration    = 3.5,  -- duração do congelamento
	IceLifetime        = 6.0,  -- tempo até o gelo ser destruído

	IceHitboxSize      = Vector3.new(6, 6, 6),

	-- Tween de nascimento
	IceGrowDuration    = 0.55,
	IceFinalSize       = Vector3.new(4, 5, 4),
	IceSpawnSize       = Vector3.new(0.05, 0.05, 0.05),

	-- Tween de destruição
	IceShrinkDuration  = 0.4,

	UltGainOnFreeze    = 1.0,
	UltGainOnContact   = 0.2,

	KnockbackConfig = {
		MaxForce           = Vector3.new(2e4, 0, 2e4),
		VelocityMultiplier = 10,
		Duration           = 0.12,
	},
}

-- ═══════════════════════════════════════════════════════════════
-- ESTADO DOS PLAYERS
-- ═══════════════════════════════════════════════════════════════
local playerStates = {}

local function setupPlayerState(player)
	if not playerStates[player.UserId] then
		playerStates[player.UserId] = { skillActive = false }
	end
end

Players.PlayerAdded:Connect(setupPlayerState)
Players.PlayerRemoving:Connect(function(p) playerStates[p.UserId] = nil end)
for _, p in ipairs(Players:GetPlayers()) do setupPlayerState(p) end

-- ═══════════════════════════════════════════════════════════════
-- CONGELAMENTO
-- ═══════════════════════════════════════════════════════════════
local frozenEnemies = {}

local function applyIceStun(enemyCharacter, enemyHumRP)
	if frozenEnemies[enemyCharacter] then return end
	frozenEnemies[enemyCharacter] = true

	StateManager.POST(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	
	StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SKILL_BEING_ATTACKED, 0.5)
	
	local iceFX = Fx:FindFirstChild(CONFIG.IceFXName) and Fx:FindFirstChild(CONFIG.IceFXName):Clone()
	if iceFX then
		iceFX.Parent = workspace.FX
		local weld = Instance.new("Weld")
		weld.Part0  = enemyCharacter.Torso
		weld.Part1  = iceFX
		weld.C0     = CFrame.new(0, 0, 0)
		weld.Parent = iceFX
	end

	
	local freezeSFX = Sounds:FindFirstChild("frostice") and Sounds.frostice:Clone()
	if freezeSFX then
		freezeSFX.Parent = enemyHumRP
		freezeSFX:Play()
		freezeSFX.Ended:Connect(function() freezeSFX:Destroy() end)
	end

	task.delay(CONFIG.IceStunDuration, function()
		if iceFX and iceFX.Parent then iceFX:Destroy() end
		StateManager.REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		frozenEnemies[enemyCharacter] = nil
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- SPAWN DO BLOCO DE GELO
-- ═══════════════════════════════════════════════════════════════
local function spawnIceBlock(spawnCFrame, player, char)
	local iceMeshTemplate = Fx:FindFirstChild(CONFIG.IceMeshName)
	if not iceMeshTemplate then
		warn("[JunoIce] Mesh '" .. CONFIG.IceMeshName .. "' não encontrada em Assets.FX")
		return
	end

	local iceBlock = iceMeshTemplate:Clone()
	iceBlock.Anchored    = true
	iceBlock.CanCollide  = false
	iceBlock.CastShadow  = false
	iceBlock.Size        = CONFIG.IceSpawnSize
	iceBlock.CFrame      = spawnCFrame
	iceBlock.Parent      = workspace.FX

	-- Partículas ligadas
	for _, p in ipairs(iceBlock:GetDescendants()) do
		if p:IsA("ParticleEmitter") then p.Enabled = true end
	end

	-- SFX de spawn
	local spawnSFX = Sounds:FindFirstChild("FreezeSFX") and Sounds.FreezeSFX:Clone()
	if spawnSFX then
		spawnSFX.Parent = iceBlock
		spawnSFX:Play()
		spawnSFX.Ended:Connect(function() spawnSFX:Destroy() end)
	end

	-- ── TWEEN DE NASCIMENTO (cristal de anime) ─────────────────────────────
	-- Passo 1: spike vertical rápido
	local spike = TweenService:Create(iceBlock,
		TweenInfo.new(CONFIG.IceGrowDuration * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(
				CONFIG.IceFinalSize.X * 0.25,
				CONFIG.IceFinalSize.Y * 1.4,
				CONFIG.IceFinalSize.Z * 0.25
			)
		}
	)
	-- Passo 2: expande com overshoot (Back easing)
	local expand = TweenService:Create(iceBlock,
		TweenInfo.new(CONFIG.IceGrowDuration * 0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = CONFIG.IceFinalSize }
	)

	spike:Play()
	spike.Completed:Connect(function() expand:Play() end)

	-- ── HITBOX ─────────────────────────────────────────────────────────────
	local hitbox = HitboxModule.new()
	hitbox:AttachToPart(iceBlock)
	hitbox.Size    = CONFIG.IceHitboxSize
	hitbox.HitType = "Multiple"

	local frozenByThisBlock = {}
	local contactCooldown   = {}

	hitbox.OnTouch = function(enemyCharacter)
		if enemyCharacter == char then return end

		local enemyPlayer   = Players:GetPlayerFromCharacter(enemyCharacter)
		local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
		local enemyHumRP    = enemyCharacter:FindFirstChild("HumanoidRootPart")
		if not (enemyHumanoid and enemyHumRP) or enemyHumanoid.Health <= 0 then return end

		local getenemy = StateManager.GET(enemyCharacter)
		if getenemy and getenemy[StateManagerEnums.STATES_ENUM.COMBAT_IFRAME] then return end

		-- Congelamento (1x por inimigo por bloco)
		if not frozenByThisBlock[enemyCharacter] then
			frozenByThisBlock[enemyCharacter] = true

			if enemyPlayer and player then
				CombatBlock.CheckAndApplyCombat(enemyPlayer, player, CONFIG.IceFreezeHitDamage, false)
			end

			DamageModule.TakeDamage(enemyCharacter, CONFIG.IceFreezeHitDamage, true)
			IncreaseUltProgress:Fire(player, CONFIG.UltGainOnFreeze)
			SendDamageIndicator:FireClient(player)
			DamageIndicator(enemyCharacter, CONFIG.IceFreezeHitDamage, Color3.new(0, 0.7, 1))

			CombatReplicator.Highlight(enemyCharacter, { Color = Color3.fromRGB(0, 180, 255), Duration = 0.7 })
			CombatReplicator.CameraShake({magnitude = 65, position = enemyHumRP.Position,radius = 15, duration = 0.4, fadeIn = 0.05, fadeOut = 0.25,})

			local dir = (enemyHumRP.Position - iceBlock.Position).Unit
			knockback:Knockback(enemyCharacter, {
				MaxForce = CONFIG.KnockbackConfig.MaxForce,
				Velocity  = dir * CONFIG.KnockbackConfig.VelocityMultiplier,
				Duration  = CONFIG.KnockbackConfig.Duration,
			})

			applyIceStun(enemyCharacter, enemyHumRP)
		end

		-- Dano contínuo por contato (tick com cooldown)
		local enemyId = enemyCharacter.Name
		if contactCooldown[enemyId] then return end
		contactCooldown[enemyId] = true

		task.delay(CONFIG.IceContactInterval, function()
			contactCooldown[enemyId] = nil
			if not iceBlock.Parent then return end
			if not enemyCharacter.Parent then return end
			local hum = enemyCharacter:FindFirstChild("Humanoid")
			if not hum or hum.Health <= 0 then return end

			DamageModule.TakeDamage(enemyCharacter, CONFIG.IceContactDamage)
			IncreaseUltProgress:Fire(player, CONFIG.UltGainOnContact)
			SendDamageIndicator:FireClient(player)
			DamageIndicator(enemyCharacter, CONFIG.IceContactDamage, Color3.new(0.5, 0.9, 1))
		end)
	end

	-- Heartbeat para checar hits
	local heartbeatConn
	heartbeatConn = RunService.Heartbeat:Connect(function()
		if not iceBlock.Parent then
			heartbeatConn:Disconnect()
			return
		end
		hitbox:CheckHits(nil)
	end)

	-- ── DESTRUIÇÃO após lifetime ───────────────────────────────────────────
	local function destroyIce()
		heartbeatConn:Disconnect()
		hitbox:Cleanup()

		for _, p in ipairs(iceBlock:GetDescendants()) do
			if p:IsA("ParticleEmitter") then p.Enabled = false end
		end

		local shrink = TweenService:Create(iceBlock,
			TweenInfo.new(CONFIG.IceShrinkDuration, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Size = CONFIG.IceSpawnSize, Transparency = 1 }
		)
		shrink:Play()
		shrink.Completed:Connect(function()
			if iceBlock and iceBlock.Parent then iceBlock:Destroy() end
		end)
	end

	task.delay(CONFIG.IceLifetime, destroyIce)
end

-- ═══════════════════════════════════════════════════════════════
-- ENTRY POINT
-- ═══════════════════════════════════════════════════════════════
function module.UseSkill(char: Model)
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end

	local userId = player.UserId
	local state  = playerStates[userId]
	if not state then
		setupPlayerState(player)
		state = playerStates[userId]
	end

	if state.skillActive then return end

	local humanoid = char:FindFirstChild("Humanoid")
	local humRP    = char:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChild("Animator")
	if not (humanoid and humRP and animator) or humanoid.Health <= 0 then return end

	local getCharacter = StateManager.GET(char)
	if getCharacter and (
		getCharacter[StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED] or
			getCharacter[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED]
		) then return end

	local animObj = Animations:FindFirstChild("Ability1")
	if not animObj then
		warn("[JunoIce] Animação 'Ability1' não encontrada")
		return
	end

	state.skillActive = true

	local activateSFX = Sounds:FindFirstChild("Activate") and Sounds.Activate:Clone()
	if activateSFX then
		activateSFX.Parent = humRP
		activateSFX:Play()
		activateSFX.Ended:Connect(function() activateSFX:Destroy() end)
	end

	local track = animator:LoadAnimation(animObj)
	track.Priority = Enum.AnimationPriority.Action2
	track:Play()

	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	-- Spawna o gelo no marcador "fire" da animação
	local fireConn
	fireConn = track:GetMarkerReachedSignal("fire"):Connect(function()
		local spawnCFrame = humRP.CFrame * CONFIG.IceSpawnOffset
		spawnIceBlock(spawnCFrame, player, char)

		local fireSFX = Sounds:FindFirstChild("Fire") and Sounds.Fire:Clone()
		if fireSFX then
			fireSFX.Parent = humRP
			fireSFX:Play()
			fireSFX.Ended:Connect(function() fireSFX:Destroy() end)
		end
	end)

	-- Cleanup ao terminar animação
	track.Stopped:Connect(function()
		if fireConn then fireConn:Disconnect() end

		state.skillActive = false
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	end)

	-- Interrompe se stunado durante a animação
	task.spawn(function()
		while track.IsPlaying do
			local cur = StateManager.GET(char)
			if cur and cur[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED] then
				track:Stop()
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

return module