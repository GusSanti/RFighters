local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Assets            = ReplicatedStorage.SkillStorage.Molten
local Fx                = Assets.FX
local Sounds            = Assets.Sounds
local Animations        = Assets.Animations
local SendDamageIndicator = game.ReplicatedStorage.Events:WaitForChild("SendDamageIndicator")
local IncreaseUltProgress = game.ReplicatedStorage.Events.IcreaseUltProgress
local CombatReplicator  = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local CutsceneCameraReplicate = ReplicatedStorage.Events.CutsceneCameraReplicate
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
	MeshName            = "Magma",
	BurnFXName          = "Burn",
	BurnSpawnOffset     = CFrame.new(0, -1.7, 0),
	BurnHitDamage       = 8,
	BurnContactDamage   = 3,
	BurnContactInterval = 0.4,
	BurnStunDuration    = 3.5,
	BurnLifetime        = 6.0,
	BurnHitboxSize      = Vector3.new(78.75, 0.75, 58.1),
	-- Tween de nascimento
	BurnGrowDuration    = 0.55,
	BurnFinalSize       = Vector3.new(78.75, 0.75, 58.1),
	BurnSpawnSize       = Vector3.new(0.05, 0.05, 0.05),
	-- Tween de destruição
	BurnShrinkDuration  = 0.4,
	UltGainOnBurn       = 1.0,
	UltGainOnContact    = 0.2,
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
-- BURN STUN
-- ═══════════════════════════════════════════════════════════════
local burningEnemies = {}
local function applyBurnStun(enemyCharacter, enemyHumRP)
	if burningEnemies[enemyCharacter] then return end
	burningEnemies[enemyCharacter] = true
	StateManager.POST(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	
	StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SKILL_BEING_ATTACKED, 0.5)

	local BurnFX = Fx:FindFirstChild(CONFIG.BurnFXName) and Fx:FindFirstChild(CONFIG.BurnFXName):Clone()
	if BurnFX then
		BurnFX.Parent = workspace.FX
		local weld = Instance.new("Weld")
		weld.Part0  = enemyCharacter.Torso
		weld.Part1  = BurnFX
		weld.C0     = CFrame.new(0, 0, 0)
		weld.Parent = BurnFX
	end

	local BurnSFX = Sounds:FindFirstChild("Burn") and Sounds.Burn:Clone()
	if BurnSFX then
		BurnSFX.Parent = enemyHumRP
		BurnSFX:Play()
		BurnSFX.Looped = true
		BurnSFX.Ended:Connect(function() BurnSFX:Destroy() end)
	end

	task.delay(CONFIG.BurnStunDuration, function()
		if BurnFX and BurnFX.Parent then BurnFX:Destroy() end
		StateManager.REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		burningEnemies[enemyCharacter] = nil
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- SPAWN DA CHAMA/MAGMA
-- ═══════════════════════════════════════════════════════════════
local function spawnBurnBlock(spawnCFrame, player, char)
	local burnMeshTemplate = Fx:FindFirstChild(CONFIG.MeshName)
	if not burnMeshTemplate then
		warn("[MoltenBurn] Mesh '" .. CONFIG.MeshName .. "' não encontrada em Assets.FX")
		return
	end

	local burnBlock = burnMeshTemplate:Clone()
	burnBlock.Anchored    = true
	burnBlock.CanCollide  = false
	burnBlock.CastShadow  = false
	burnBlock.Size        = CONFIG.BurnSpawnSize
	burnBlock.CFrame      = spawnCFrame
	burnBlock.Parent      = workspace.FX

	for _, p in ipairs(burnBlock:GetDescendants()) do
		if p:IsA("ParticleEmitter") then p.Enabled = true end
	end

	local spawnSFX = Sounds:FindFirstChild("Activate") and Sounds.Activate:Clone()
	if spawnSFX then
		spawnSFX.Parent = burnBlock
		spawnSFX:Play()
		spawnSFX.Ended:Connect(function() spawnSFX:Destroy() end)
	end

	local grow = TweenService:Create(burnBlock,
		TweenInfo.new(CONFIG.BurnGrowDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = CONFIG.BurnFinalSize }
	)
	grow:Play()

	-- ── HITBOX ────────────────────────────────────────────────
	local hitbox = HitboxModule.new()
	hitbox:AttachToPart(burnBlock)
	hitbox.Size    = CONFIG.BurnHitboxSize
	hitbox.HitType = "Multiple"

	local burnedByThisBlock = {}
	local contactCooldown   = {}

	hitbox.OnTouch = function(enemyCharacter)
		if enemyCharacter == char then return end
		local enemyPlayer   = Players:GetPlayerFromCharacter(enemyCharacter)
		local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
		local enemyHumRP    = enemyCharacter:FindFirstChild("HumanoidRootPart")
		if not (enemyHumanoid and enemyHumRP) or enemyHumanoid.Health <= 0 then return end

		local getenemy = StateManager.GET(enemyCharacter)
		if getenemy and getenemy[StateManagerEnums.STATES_ENUM.COMBAT_IFRAME] then return end

		-- Hit inicial de queimadura (1x por inimigo por bloco)
		if not burnedByThisBlock[enemyCharacter] then
			burnedByThisBlock[enemyCharacter] = true
			if enemyPlayer and player then
				CombatBlock.CheckAndApplyCombat(enemyPlayer, player, CONFIG.BurnHitDamage, false)
			end
			DamageModule.TakeDamage(enemyCharacter, CONFIG.BurnHitDamage, true)
			IncreaseUltProgress:Fire(player, CONFIG.UltGainOnBurn)
			SendDamageIndicator:FireClient(player)
			DamageIndicator(enemyCharacter, CONFIG.BurnHitDamage, Color3.new(1, 0.4, 0))       -- laranja fogo
			CombatReplicator.Highlight(enemyCharacter, { Color = Color3.fromRGB(255, 100, 0), Duration = 0.7 })
			CombatReplicator.CameraShake({magnitude = 65, position = enemyHumRP.Position,radius = 15, duration = 0.4, fadeIn = 0.05, fadeOut = 0.25,})
			
			local dir = (enemyHumRP.Position - burnBlock.Position).Unit
			knockback:Knockback(enemyCharacter, {
				MaxForce = CONFIG.KnockbackConfig.MaxForce,
				Velocity  = dir * CONFIG.KnockbackConfig.VelocityMultiplier,
				Duration  = CONFIG.KnockbackConfig.Duration,
			})
			applyBurnStun(enemyCharacter, enemyHumRP)
		end

		-- Dano contínuo de queimadura (tick com cooldown)
		local enemyId = enemyCharacter.Name
		if contactCooldown[enemyId] then return end
		contactCooldown[enemyId] = true
		task.delay(CONFIG.BurnContactInterval, function()
			contactCooldown[enemyId] = nil
			if not burnBlock.Parent then return end
			if not enemyCharacter.Parent then return end
			local hum = enemyCharacter:FindFirstChild("Humanoid")
			if not hum or hum.Health <= 0 then return end
			DamageModule.TakeDamage(enemyCharacter, CONFIG.BurnContactDamage)
			IncreaseUltProgress:Fire(player, CONFIG.UltGainOnContact)
			SendDamageIndicator:FireClient(player)
			DamageIndicator(enemyCharacter, CONFIG.BurnContactDamage, Color3.new(1, 0.6, 0.1)) -- amarelo-alaranjado
		end)
	end

	local heartbeatConn
	heartbeatConn = RunService.Heartbeat:Connect(function()
		if not burnBlock.Parent then
			heartbeatConn:Disconnect()
			return
		end
		hitbox:CheckHits(nil)
	end)

	-- ── DESTRUIÇÃO após lifetime ──────────────────────────────
	local function destroyBurn()
		heartbeatConn:Disconnect()
		hitbox:Cleanup()
		for _, p in ipairs(burnBlock:GetDescendants()) do
			if p:IsA("ParticleEmitter") then p.Enabled = false end
		end
		local shrink = TweenService:Create(burnBlock,
			TweenInfo.new(CONFIG.BurnShrinkDuration, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Size = CONFIG.BurnSpawnSize, Transparency = 1 }
		)
		shrink:Play()
		shrink.Completed:Connect(function()
			if burnBlock and burnBlock.Parent then burnBlock:Destroy() end
		end)
	end
	task.delay(CONFIG.BurnLifetime, destroyBurn)
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

	local animObj = Animations:FindFirstChild("Ability3")
	if not animObj then
		warn("[MoltenBurn] Animação 'Ability3' não encontrada")
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
	
	CutsceneCameraReplicate:FireClient(player, {
		CameraModel     = Fx.Camera,
		Animation       = Animations.Ability3Cutscene,
		CamPartName     = "Cam",
		WeldToCharacter = true,
		WeldC0 = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(180), math.rad(0)),
		WeldC1 = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		RestoreInstant  = true,
	})

	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	local fireConn
	fireConn = track:GetMarkerReachedSignal("fire"):Connect(function()
		local spawnCFrame = humRP.CFrame * CONFIG.BurnSpawnOffset
		spawnBurnBlock(spawnCFrame, player, char)

		local fireSFX = Sounds:FindFirstChild("Fire") and Sounds.Fire:Clone()
		if fireSFX then
			fireSFX.Parent = humRP
			fireSFX:Play()
			fireSFX.Ended:Connect(function() fireSFX:Destroy() end)
		end
	end)

	track.Stopped:Connect(function()
		if fireConn then fireConn:Disconnect() end
		state.skillActive = false
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	end)

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