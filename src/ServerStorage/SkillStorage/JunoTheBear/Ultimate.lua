local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local Assets            = ReplicatedStorage.SkillStorage.JunoTheBear
local Fx                = Assets.FX
local Sounds            = Assets.Sounds
local Animations        = Assets.Animations

local DeathConnectionEvent = game.ReplicatedStorage.CombatSystem.Events.DeathConnectionEvent
local SendDamageIndicator = game.ReplicatedStorage.Events:WaitForChild("SendDamageIndicator")
local CutsceneCameraReplicate = ReplicatedStorage.Events.CutsceneCameraReplicate


local CombatReplicator  = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local Utilities         = require(ReplicatedStorage.Modules.Utilitary.Utils)
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local HitboxModule      = require(ServerStorage.FightModules.HitboxHandler)
local DamageIndicator   = require(ReplicatedStorage.Modules.Shared:WaitForChild("DamageIndicator"))
local knockback         = require(ServerStorage.FightModules.Knockback)
local CombatBlock       = require(game.ReplicatedStorage.CombatSystem.CombatBlock)
local DamageModule = require(game.ReplicatedStorage.CombatSystem.DamageModule)

local CONFIG = {
	DamagePerTick    = 10,
	TickRate         = 0.15,
	HitboxSize       = Vector3.new(6, 6, 6),
	ProjectileSpeed  = 50,
	ProjectileLife   = 4,
	MaxRange         = 300,
	KnockbackConfig  = {
		MaxForce           = Vector3.new(2e4, 0, 2e4),
		VelocityMultiplier = 20,
		Duration           = 0.1,
	},
	StunDuration     = 0.2,
}

local playerStates = {}

local function setupPlayerState(player)
	local userId = player.UserId
	if not playerStates[userId] then
		playerStates[userId] = {
			Projectile = false,
		}
	end
end

Players.PlayerAdded:Connect(setupPlayerState)
Players.PlayerRemoving:Connect(function(player)
	playerStates[player.UserId] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayerState(player)
end

local function launchProjectile(char, humRP, player, state)
	local projFX = Fx:FindFirstChild("Super"):Clone()
	if not projFX then
		warn("[Juno Ulimate] FX 'Ability 3' não encontrado em Assets.FX")
		state.Projectile = false
		return
	end

	projFX.Parent = workspace.FX
	projFX.CFrame = humRP.CFrame * CFrame.new(0, 0, -2)

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
		task.delay(CONFIG.TickRate, function()
			hitCooldowns[enemyId] = nil
		end)

		if enemyPlayer and player then
			if CombatBlock.CheckAndApplyCombat(enemyPlayer, player, CONFIG.DamagePerTick, false) then return end
		end

		local damage = CONFIG.DamagePerTick

		DamageModule.TakeDamage(enemyCharacter, damage, true)

		local HitSFX = Sounds:FindFirstChild("HitSFX") and Sounds.HitSFX:Clone()
		if HitSFX then
			HitSFX.Parent = enemyCharacter:FindFirstChild("Torso") or enemyHumRP
			HitSFX:Play()
			HitSFX.Ended:Connect(function() HitSFX:Destroy() end)
		end

		SendDamageIndicator:FireClient(player)

		CombatReplicator.CameraShake({magnitude = 65, position = enemyHumRP.Position,radius = 15, duration = 0.4, fadeIn = 0.05, fadeOut = 0.2})
		CombatReplicator.Highlight(enemyCharacter, {Color = Color3.fromRGB(117, 0, 140), Duration = 0.3})
		DamageIndicator(enemyCharacter, damage, Color3.new(0.533333, 0, 1))

		local dir = (enemyHumRP.Position - projFX.Position).Unit
		knockback:Knockback(enemyCharacter, {
			MaxForce = CONFIG.KnockbackConfig.MaxForce,
			Velocity  = dir * CONFIG.KnockbackConfig.VelocityMultiplier,
			Duration  = CONFIG.KnockbackConfig.Duration,
		})

		StateManager.POST(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		task.delay(CONFIG.StunDuration, function()
			StateManager.REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		end)
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
			state.Projectile = false
			return
		end

		projHitbox:CheckHits(nil)
	end)

	Debris:AddItem(projFX, CONFIG.ProjectileLife + 1)
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

	local animObj = Animations:FindFirstChild("Ability3")
	if not animObj then
		warn("[Shiro Ability3] Animação 'Ability3' não encontrada")
		return
	end

	state.Projectile = true

	-- ServerScript
	CutsceneCameraReplicate:FireClient(player, {
		CameraModel     = Fx.Camera,
		Animation       = Animations.Ability3Cutscene,
		CamPartName     = "Cam",
		WeldToCharacter = true,
		WeldC0 = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(180), math.rad(0)),
		WeldC1 = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		RestoreInstant  = true,
	})

	local track = animator:LoadAnimation(animObj)
	track.Priority = Enum.AnimationPriority.Action2
	track:Play()

	local ChargeSFX = Sounds:FindFirstChild("Charge") and Sounds.Charge:Clone()
	if ChargeSFX then
		ChargeSFX.Parent = humRP
		ChargeSFX:Play()
		ChargeSFX.Ended:Connect(function() ChargeSFX:Destroy() end)
	end

	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	local RightArm    = char:FindFirstChild("Right Arm")
	local chargeFX   = Fx:FindFirstChild("ChargeEffect"):Clone()
	chargeFX.Parent = workspace.FX

	local chargeWeld = Instance.new("Weld")
	chargeWeld.Part0  = RightArm
	chargeWeld.Part1  = chargeFX
	chargeWeld.C0     = CFrame.new(0, -0.8, 0)
	chargeWeld.Parent = chargeFX

	local fireConn
	local fired = false

	local function fire()
		if fired then return end
		fired = true
		if fireConn then fireConn:Disconnect() end

		if chargeFX and chargeFX.Parent then
			chargeFX:Destroy()
		end

		local fireSFX = Sounds:FindFirstChild("Fire") and Sounds.Fire:Clone()
		if fireSFX then
			fireSFX.Parent = humRP
			fireSFX:Play()
			fireSFX.Ended:Connect(function() fireSFX:Destroy() end)
		end

		launchProjectile(char, humRP, player, state)
	end

	fireConn = track:GetMarkerReachedSignal("fire"):Connect(fire)

	track.Stopped:Connect(function()
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	end)
end

return module