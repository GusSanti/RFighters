local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local Assets            = ReplicatedStorage.SkillStorage.Bolg
local Fx                = Assets.FX
local Sounds            = Assets.Sounds
local Animations        = Assets.Animations

local DeathConnectionEvent = game.ReplicatedStorage.CombatSystem.Events.DeathConnectionEvent
local SendStreakUpdate  = game.ReplicatedStorage.Events:WaitForChild("UpdateStreakInfo")
local IncreaseUltProgress  = game.ReplicatedStorage.Events.IcreaseUltProgress

local CombatReplicator  = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local HitboxModule      = require(ServerStorage.FightModules.HitboxHandler)
local DamageIndicator   = require(ReplicatedStorage.Modules.Shared:WaitForChild("DamageIndicator"))
local knockback         = require(ServerStorage.FightModules.Knockback)
local CombatBlock       = require(game.ReplicatedStorage.CombatSystem.CombatBlock)
local DamageModule = require(game.ReplicatedStorage.CombatSystem.DamageModule)

local CONFIG = {
	Damage           = 15,
	HitboxSize       = Vector3.new(5, 5, 5),
	ProjectileSpeed  = 55,
	ProjectileLife   = 4,
	MaxRange         = 300,
	-- 2 projéteis por fire
	ProjectileCount  = 2,
	ProjectileOffset = 1.2,

	KnockbackConfig  = {
		MaxForce           = Vector3.new(2e4, 0, 2e4),
		VelocityMultiplier = 15,
		Duration           = 0.15,
	},
}

local playerStates = {}

local function setupPlayerState(player)
	if not playerStates[player.UserId] then
		playerStates[player.UserId] = { Projectile = false }
	end
end

Players.PlayerAdded:Connect(setupPlayerState)
Players.PlayerRemoving:Connect(function(p) playerStates[p.UserId] = nil end)
for _, p in ipairs(Players:GetPlayers()) do setupPlayerState(p) end

local function launchSingleProjectile(char, humRP, player, state, offsetCFrame)
	local projFX = Fx:FindFirstChild("Ability 1") and Fx:FindFirstChild("Ability 1"):Clone()
	if not projFX then
		warn("[Bolg Ability1] FX 'Ability 1' não encontrado em Assets.FX")
		return
	end

	projFX.Parent = workspace.FX
	projFX.CFrame = humRP.CFrame * CFrame.new(0, 0, -2) * CFrame.Angles(0, math.rad(180), 0)

	local projHitbox = HitboxModule.new()
	projHitbox:AttachToPart(projFX)
	projHitbox.Size    = CONFIG.HitboxSize
	projHitbox.HitType = "Multiple"

	local hitCooldowns = {}

	projHitbox.OnTouch = function(enemyCharacter)
		if enemyCharacter == char then return end

		local enemyPlayer   = Players:GetPlayerFromCharacter(enemyCharacter)
		local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
		local enemyHumRP    = enemyCharacter:FindFirstChild("HumanoidRootPart")
		if not (enemyHumanoid and enemyHumRP) or enemyHumanoid.Health <= 0 then return end

		local getenemy = StateManager.GET(enemyCharacter)
		if getenemy and getenemy[StateManagerEnums.STATES_ENUM.COMBAT_IFRAME] then return end

		local enemyId = enemyCharacter.Name
		if hitCooldowns[enemyId] then return end
		hitCooldowns[enemyId] = true
		task.delay(0.2, function() hitCooldowns[enemyId] = nil end)

		if enemyPlayer and player then
			if CombatBlock.CheckAndApplyCombat(enemyPlayer, player, CONFIG.Damage, false) then return end
		end

		local damage = CONFIG.Damage
		
		DamageModule.TakeDamage(enemyCharacter, damage, true, char)

		IncreaseUltProgress:Fire(player, 0.5)

		local HitSFX = Sounds:FindFirstChild("HitSFX") and Sounds.HitSFX:Clone()
		if HitSFX then
			HitSFX.Parent = enemyHumRP
			HitSFX:Play()
			HitSFX.Ended:Connect(function() HitSFX:Destroy() end)
		end

		local HitSFX2 = Sounds:FindFirstChild("Hit") and Sounds.Hit:Clone()
		if HitSFX2 then
			HitSFX2.Parent = enemyHumRP
			HitSFX2:Play()
			HitSFX2.Ended:Connect(function() HitSFX2:Destroy() end)
		end

		SendStreakUpdate:Fire(player)

		CombatReplicator.CameraShake({magnitude = 65, position = enemyHumRP.Position,radius = 15, duration = 0.3, fadeIn = 0.05, fadeOut = 0.2})
		CombatReplicator.Highlight(enemyCharacter, {Color = Color3.fromRGB(255, 64, 0), Duration = 0.5})
		DamageIndicator(enemyCharacter, damage, Color3.new(255, 64, 0))

		local dir = (enemyHumRP.Position - projFX.Position).Unit
		knockback:Knockback(enemyCharacter, {
			MaxForce = CONFIG.KnockbackConfig.MaxForce,
			Velocity  = dir * CONFIG.KnockbackConfig.VelocityMultiplier,
			Duration  = CONFIG.KnockbackConfig.Duration,
		})
		
		StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED, 0.5)
		StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SKILL_BEING_ATTACKED, 0.5)
	end

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bv.Velocity  = humRP.CFrame.LookVector * CONFIG.ProjectileSpeed
	bv.Parent    = projFX

	local startPos = projFX.Position
	local elapsed  = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local tooFar  = (projFX.Position - startPos).Magnitude >= CONFIG.MaxRange
		local expired = elapsed >= CONFIG.ProjectileLife

		if tooFar or expired or not projFX.Parent then
			conn:Disconnect()
			projHitbox:Cleanup()
			bv:Destroy()
			task.delay(0.3, function()
				if projFX and projFX.Parent then projFX:Destroy() end
			end)
			return
		end

		projHitbox:CheckHits(nil)
	end)

	Debris:AddItem(projFX, CONFIG.ProjectileLife + 1)
end

local function launchProjectiles(char, humRP, player, state)
	local offsets = {
		CFrame.new(-CONFIG.ProjectileOffset, 0, 0),
		CFrame.new( CONFIG.ProjectileOffset, 0, 0),
	}
	for i = 1, CONFIG.ProjectileCount do
		launchSingleProjectile(char, humRP, player, state, offsets[i])
	end
	state.Projectile = false
end

function module.UseSkill(char: Model)
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end

	local userId = player.UserId
	local state  = playerStates[userId]
	if not state then
		setupPlayerState(player)
		state = playerStates[userId]
	end

	if state.Projectile then return end

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
		warn("[Bolg Ability1] Animação 'Ability1' não encontrada")
		return
	end

	state.Projectile = true

	local Handle = char:FindFirstChild("Handle")
	if Handle then Handle.Transparency = 0 end

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

	local fired    = false
	--local fireConn

	local function fire()
		if fired then return end
		fired = true
		--if fireConn then fireConn:Disconnect() end
		launchProjectiles(char, humRP, player, state)

		local Firesfx = Sounds:FindFirstChild("Fire") and Sounds.Fire:Clone()
		if Firesfx then
			Firesfx.Parent = humRP
			Firesfx:Play()
			Firesfx.Ended:Connect(function() Firesfx:Destroy() end)
		end
	end

	task.delay(0.25, fire)

	--fireConn = track:GetMarkerReachedSignal("fire"):Connect(fire)

	track.Stopped:Connect(function()
		local h = char:FindFirstChild("Handle")
		if h then h.Transparency = 1 end

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