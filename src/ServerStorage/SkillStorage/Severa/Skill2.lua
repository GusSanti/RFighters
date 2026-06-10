local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local Assets     = ReplicatedStorage.SkillStorage.Severa
local Fx         = Assets.FX
local Sounds     = Assets.Sounds
local Animations = Assets.Animations

local SendDamageIndicator     = ReplicatedStorage.Events:WaitForChild("SendDamageIndicator")
local IncreaseUltProgress     = ReplicatedStorage.Events.IcreaseUltProgress
local CutsceneCameraReplicate = ReplicatedStorage.Events.CutsceneCameraReplicate

local CombatReplicator  = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local HitboxModule      = require(ServerStorage.FightModules.HitboxHandler)
local DamageIndicator   = require(ReplicatedStorage.Modules.Shared:WaitForChild("DamageIndicator"))
local DamageModule      = require(game.ReplicatedStorage.CombatSystem.DamageModule)
local knockback         = require(game.ReplicatedStorage.CombatSystem.CombatKnockback)
local knockbackProfiles = require(ServerStorage.CombatStorage.GlobalStorage.KnockbackProfiles)

local CONFIG = {
	Damage          = 20,
	HitboxSize      = Vector3.new(6, 6, 6),
	ProjectileSpeed = 60,
	ProjectileLife  = 5,
	MaxRange        = 350,
	KnockbackConfig = {
		MaxForce           = Vector3.new(2e4, 0, 2e4),
		VelocityMultiplier = 20,
		Duration           = 0.1,
	},
	StunDuration    = 0.25,
	UltimateGain    = 1.0,
}

local playerStates = {}

local function setupPlayerState(player)
	if not playerStates[player.UserId] then
		playerStates[player.UserId] = { active = false }
	end
end

Players.PlayerAdded:Connect(setupPlayerState)
Players.PlayerRemoving:Connect(function(p) playerStates[p.UserId] = nil end)
for _, p in ipairs(Players:GetPlayers()) do setupPlayerState(p) end

-- cleanupFn é passado para garantir que os states sejam sempre removidos
local function launchProjectile(char, humRP, player, state, cleanupFn)
	local projFX = Fx:FindFirstChild("Ability 2") and Fx:FindFirstChild("Ability 2"):Clone()
	if not projFX then
		warn("[Severa Ability2] FX 'Ability 2' não encontrado")
		cleanupFn()
		return
	end

	projFX.Parent = workspace.FX
	projFX.CFrame = humRP.CFrame * CFrame.new(0, 0, -2)

	local projHitbox    = HitboxModule.new()
	projHitbox:AttachToPart(projFX)
	projHitbox.Size    = CONFIG.HitboxSize
	projHitbox.HitType = "Multiple"

	local hitCooldowns = {}

	projHitbox.OnTouch = function(enemyCharacter)
		if enemyCharacter == char then return end

		local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
		local enemyHumRP    = enemyCharacter:FindFirstChild("HumanoidRootPart")
		if not (enemyHumanoid and enemyHumRP) or enemyHumanoid.Health <= 0 then return end

		local getenemy = StateManager.GET(enemyCharacter)
		if getenemy and getenemy[StateManagerEnums.STATES_ENUM.COMBAT_IFRAME] then return end

		local enemyId = enemyCharacter.Name
		if hitCooldowns[enemyId] then return end
		hitCooldowns[enemyId] = true
		task.delay(0.15, function() hitCooldowns[enemyId] = nil end)

		DamageModule.TakeDamage(enemyCharacter, CONFIG.Damage, true)
		IncreaseUltProgress:Fire(player, CONFIG.UltimateGain)
		SendDamageIndicator:FireClient(player)

		local HitSFX = Sounds:FindFirstChild("HitSFX") and Sounds.HitSFX:Clone()
		if HitSFX then
			HitSFX.Parent = enemyCharacter:FindFirstChild("Torso") or enemyHumRP
			HitSFX:Play()
			HitSFX.Ended:Connect(function() HitSFX:Destroy() end)
		end

		CombatReplicator.CameraShake({ magnitude = 65, position = enemyHumRP.Position, radius = 15, duration = 0.5, fadeIn = 0.05, fadeOut = 0.25 })
		CombatReplicator.Highlight(enemyCharacter, { Color = Color3.fromRGB(117, 0, 140), Duration = 0.3 })
		DamageIndicator(enemyCharacter, CONFIG.Damage, Color3.new(0.533, 0, 1))

		knockback.ApplyKnockback({
			Profile = knockbackProfiles.LauncherLight,

			KnockdownInfo = {
				Duration = 1.5,
				CanContinueCombo = true,
				InAirAnim = game.ReplicatedStorage.CombatStorage.GlobalAnimations.airlow,
				FallAnim = game.ReplicatedStorage.CombatStorage.GlobalAnimations.fall,
				WakeUpAnim = game.ReplicatedStorage.CombatStorage.GlobalAnimations.wakeup
			}
		}, enemyCharacter)

		StateManager.POST(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SKILL_BEING_ATTACKED, 0.5)
		task.delay(CONFIG.StunDuration, function()
			StateManager.REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		end)
	end

	local bv        = Instance.new("BodyVelocity")
	bv.MaxForce     = Vector3.new(1e5, 1e5, 1e5)
	bv.Velocity     = humRP.CFrame.LookVector * CONFIG.ProjectileSpeed
	bv.Parent       = projFX

	local startPos  = projFX.Position
	local elapsed   = 0
	local cleanedUp = false  -- guard para chamar cleanupFn só uma vez
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt

		local cs        = StateManager.GET(char)
		local cancelled = cs and cs[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED]

		local done = cancelled
			or elapsed >= CONFIG.ProjectileLife
			or (projFX.Position - startPos).Magnitude >= CONFIG.MaxRange
			or not projFX.Parent

		if done then
			conn:Disconnect()
			projHitbox:Cleanup()
			bv:Destroy()
			task.delay(0.2, function()
				if projFX and projFX.Parent then projFX:Destroy() end
			end)

			-- Chama cleanupFn uma única vez para garantir remoção dos states
			if not cleanedUp then
				cleanedUp = true
				cleanupFn()
			end
			return
		end

		projHitbox:CheckHits(nil)
	end)

	Debris:AddItem(projFX, CONFIG.ProjectileLife + 1)
end

function module.UseSkill(char: Model)
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end

	local state = playerStates[player.UserId]
	if not state or state.active then return end

	local humanoid = char:FindFirstChild("Humanoid")
	local humRP    = char:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChild("Animator")
	if not (humanoid and humRP and animator) or humanoid.Health <= 0 then return end

	local charState = StateManager.GET(char)
	if charState and (
		charState[StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED] or
			charState[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED]
		) then return end

	local animObj = Animations:FindFirstChild("Ability2")
	if not animObj then warn("[Severa Ability2] Animação não encontrada") return end

	state.active = true

	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	local track = animator:LoadAnimation(animObj)
	track.Priority = Enum.AnimationPriority.Action2
	track:Play()

	local ChargeSFX = Sounds:FindFirstChild("Ability2") and Sounds.Ability2:Clone()
	if ChargeSFX then
		ChargeSFX.Parent = humRP
		ChargeSFX:Play()
		ChargeSFX.Ended:Connect(function() ChargeSFX:Destroy() end)
	end

	local chargeFX = Fx:FindFirstChild("Ability 2") and Fx:FindFirstChild("Ability 2"):Clone()
	if chargeFX then
		chargeFX.Parent = workspace.FX
		local w  = Instance.new("Weld")
		w.Part0  = char:FindFirstChild("Right Arm")
		w.Part1  = chargeFX
		w.C0     = CFrame.new(0, -0.8, 0)
		w.Parent = chargeFX
	end

	local cleanedUp = false  -- guard para chamar cleanup só uma vez

	-- CORREÇÃO PRINCIPAL: cleanup sempre remove os states,
	-- independente do valor de state.active
	local function cleanup()
		if cleanedUp then return end
		cleanedUp = true
		state.active = false
		if chargeFX and chargeFX.Parent then chargeFX:Destroy() end
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	end

	-- Cancela animação se caster tomar dano
	task.spawn(function()
		while state.active do
			local cs = StateManager.GET(char)
			if cs and cs[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED] then
				track:Stop()
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)

	local fired = false
	track:GetMarkerReachedSignal("fire"):Connect(function()
		if not state.active or fired then return end
		fired = true

		if chargeFX and chargeFX.Parent then chargeFX:Destroy() end

		local fireSFX = Sounds:FindFirstChild("Fireball") and Sounds.Fireball:Clone()
		if fireSFX then
			fireSFX.Parent = humRP
			fireSFX:Play()
			fireSFX.Ended:Connect(function() fireSFX:Destroy() end)
		end

		-- Passa cleanup para o projectile gerenciar o fim do estado
		launchProjectile(char, humRP, player, state, cleanup)
	end)

	track.Stopped:Connect(function()
		-- Sempre chama cleanup ao parar, mesmo que o projectile já tenha chamado
		-- O guard `cleanedUp` dentro do cleanup previne double-cleanup
		cleanup()
	end)
end

return module