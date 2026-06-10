local module = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

local Assets        = ReplicatedStorage.SkillStorage.Molten
local Fx            = Assets.FX
local Sounds        = Assets.Sounds
local Animations    = Assets.Animations

local SendDamageIndicator = ReplicatedStorage.Events:WaitForChild("SendDamageIndicator")
local IncreaseUltProgress = ReplicatedStorage.Events.IcreaseUltProgress

local CombatReplicator  = require(ReplicatedStorage.CombatSystem.EffectsReplicator)
local StateManager      = require(ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(ReplicatedStorage.StateManager.ENUM)
local HitboxModule      = require(ServerStorage.FightModules.HitboxHandler)
local DamageIndicator   = require(ReplicatedStorage.Modules.Shared:WaitForChild("DamageIndicator"))
local knockback         = require(game.ReplicatedStorage.CombatSystem.CombatKnockback)
local knockbackProfiles = require(ServerStorage.CombatStorage.GlobalStorage.KnockbackProfiles)
local CombatBlock       = require(ReplicatedStorage.CombatSystem.CombatBlock)
local DamageModule      = require(ReplicatedStorage.CombatSystem.DamageModule)

-- CONFIG
local CONFIG = {
	IceFXName           = "IceFX",
	IceSpawnOffset      = CFrame.new(0, 4, -5),

	IceFreezeHitDamage  = 8,
	IceContactDamage    = 3,
	IceContactInterval  = 0.4,

	IceStunDuration     = 3.5,
	IceHitboxSize       = Vector3.new(18.358, 18.358, 18.358),

	UltGainOnFreeze     = 1.0,
	UltGainOnContact    = 0.2,

	DamagePerHit   = 5,
	HitboxSize     = Vector3.new(8, 8, 11),
	HitboxOffset   = CFrame.new(0, 0, -6),
	NormalKnockback = {
		MaxForce           = Vector3.new(2e4, 2e6, 2e4),
		VelocityMultiplier = 15,
		Duration           = 0.5
	},
	UltimateGainPerHit = 100,
}

-- PLAYER STATE
local playerStates = {}

local function setupPlayerState(player)
	playerStates[player.UserId] = playerStates[player.UserId] or {
		skillActive = false
	}
end

Players.PlayerAdded:Connect(setupPlayerState)
Players.PlayerRemoving:Connect(function(p)
	playerStates[p.UserId] = nil
end)

for _, p in ipairs(Players:GetPlayers()) do
	setupPlayerState(p)
end

-- STUN
local frozenEnemies = {}

local function applyIceStun(enemyCharacter, enemyHumRP)
	if frozenEnemies[enemyCharacter] then return end
	frozenEnemies[enemyCharacter] = true

	StateManager.POST(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	local iceFX = Fx:FindFirstChild(CONFIG.IceFXName)
	if iceFX then
		iceFX = iceFX:Clone()
		iceFX.Parent = workspace.FX

		local weld = Instance.new("Weld")
		weld.Part0 = enemyCharacter.Torso
		weld.Part1 = iceFX
		weld.Parent = iceFX
	end

	local freezeSFX = Sounds:FindFirstChild("frostice")
	if freezeSFX then
		freezeSFX = freezeSFX:Clone()
		freezeSFX.Parent = enemyHumRP
		freezeSFX:Play()
		freezeSFX.Ended:Connect(function()
			freezeSFX:Destroy()
		end)
	end

	task.delay(CONFIG.IceStunDuration, function()
		if iceFX and iceFX.Parent then
			iceFX:Destroy()
		end

		StateManager.REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		frozenEnemies[enemyCharacter] = nil
	end)
end


local function doHit(mainHitbox, Character, humRP)
	local damage   = CONFIG.DamagePerHit
	local stunTime = CONFIG.NormalKnockback.Duration + 0.1
	local player   = Players:GetPlayerFromCharacter(Character)

	mainHitbox.OnTouch = function(enemyCharacter)
		local enemyplayer   = Players:GetPlayerFromCharacter(enemyCharacter)
		local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
		local enemyHumRP    = enemyCharacter:FindFirstChild("HumanoidRootPart")
		if not (enemyHumanoid and enemyHumRP) or enemyHumanoid.Health <= 0 then return end

		local getenemy = StateManager.GET(enemyCharacter)
		if getenemy and getenemy[StateManagerEnums.STATES_ENUM.COMBAT_IFRAME] then return end

		if enemyplayer and player then
			if CombatBlock.CheckAndApplyCombat(enemyplayer, player, damage, false) then return end
		end

		Sounds:FindFirstChild("HitSFX"):Play()
		--HitSFX.Parent = enemyCharacter.Torso
		--HitSFX:Play()
		--print('HIT SFX')
		--HitSFX.Ended:Connect(function() HitSFX:Destroy() end)

		DamageModule.TakeDamage(enemyCharacter, damage, true)

		IncreaseUltProgress:Fire(player, CONFIG.UltimateGainPerHit)
		SendDamageIndicator:FireClient(player)

		CombatReplicator.CameraShake({magnitude = 65, position = enemyHumRP.Position, radius = 15, duration = 0.6, fadeIn = 0.1, fadeOut = 0.3})
		CombatReplicator.Highlight(enemyCharacter, {Color = Color3.fromRGB(255, 0, 0), Duration = 0.6})
		DamageIndicator(enemyCharacter, damage, Color3.new(1, 0.5, 0))
		--applyNormalKnockback(enemyCharacter, humRP)
		
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
		
		CombatReplicator.Emit(enemyHumRP, Fx:FindFirstChild('Ability 1'))

		StateManager.POST(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SKILL_BEING_ATTACKED, 0.5)
		task.delay(stunTime, function()
			StateManager.REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

			--if BarrageFX and BarrageFX.Parent then
			--	task.delay(4, function() BarrageFX:Destroy() end)
			--end
		end)
	end

	mainHitbox:Once()
end

-- ENTRY
function module.UseSkill(char: Model)
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end

	setupPlayerState(player)
	local state = playerStates[player.UserId]

	if state.skillActive then return end

	local humanoid = char:FindFirstChild("Humanoid")
	local humRP    = char:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChild("Animator")

	if not (humanoid and humRP and animator) or humanoid.Health <= 0 then return end

	local cur = StateManager.GET(char)
	if cur and (
		cur[StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED] or
			cur[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED]
		) then return end

	local anim = Animations:FindFirstChild("Ability2")
	if not anim then return end

	state.skillActive = true

	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action2
	track:Play()
	
	local mainHitbox    = nil

	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	mainHitbox = HitboxModule.new()
	mainHitbox:AttachToCharacter(char)
	mainHitbox.Size    = CONFIG.HitboxSize
	mainHitbox:SetOffset(CONFIG.HitboxOffset)
	mainHitbox.HitType = "Single"

	Sounds:FindFirstChild("Hit"):Play()

	task.delay(0.4, function() 
		doHit(mainHitbox, char, humRP)
		--Utilities.Particle_Setup({Holder = BarrageFX, Type = "Emit"})
	end)
	
	track.Stopped:Connect(function()
		state.skillActive = false
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	end)

	task.spawn(function()
		while track.IsPlaying do
			local curState = StateManager.GET(char)
			if curState and curState[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED] then
				track:Stop()
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

return module