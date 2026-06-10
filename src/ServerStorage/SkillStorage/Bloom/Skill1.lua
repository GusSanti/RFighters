local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local Assets            = ReplicatedStorage.SkillStorage.Bloom
local Fx                = Assets.FX
local Sounds            = Assets.Sounds
local Animations        = Assets.Animations

local DeathConnectionEvent = game.ReplicatedStorage.CombatSystem.Events.DeathConnectionEvent
local SendDamageIndicator = game.ReplicatedStorage.Events:WaitForChild("SendDamageIndicator")
local IncreaseUltProgress = game.ReplicatedStorage.Events.IcreaseUltProgress

local CombatReplicator = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local Utilities         = require(ReplicatedStorage.Modules.Utilitary.Utils)

local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local HitboxModule      = require(ServerStorage.FightModules.HitboxHandler)
local DamageIndicator   = require(ReplicatedStorage.Modules.Shared:WaitForChild("DamageIndicator"))
local knockback         = require(game.ReplicatedStorage.CombatSystem.CombatKnockback)
local knockbackProfiles = require(ServerStorage.CombatStorage.GlobalStorage.KnockbackProfiles)
local CombatBlock       = require(game.ReplicatedStorage.CombatSystem.CombatBlock)
local DamageModule      = require(game.ReplicatedStorage.CombatSystem.DamageModule)

local BARRAGE_CONFIG = {
	DamagePerHit        = 5,
	HitboxSize          = Vector3.new(8, 8, 11),
	HitboxOffset        = CFrame.new(0, 0, -6),
	NormalKnockback = {
		MaxForce           = Vector3.new(2e4, 0, 2e4),
		VelocityMultiplier = 15,
		Duration           = 0.08
	},
	UltimateGainPerHit  = 100,
	MineDuration        = 30, -- segundos que a mina fica viva
}

local playerStates = {}

local function setupPlayerState(player)
	local userId = player.UserId
	if not playerStates[userId] then
		playerStates[userId] = {
			barrageActive = false,
			Sfx           = nil,
			Sfx2          = nil,
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

local function spawnMine(ownerChar, ownerPlayer, spawnCFrame)
	local damage   = BARRAGE_CONFIG.DamagePerHit
	local stunTime = BARRAGE_CONFIG.NormalKnockback.Duration + 0.1
	local duration = BARRAGE_CONFIG.MineDuration

	local BarrageFX = Fx:FindFirstChild("Ability 1"):Clone()
	BarrageFX.Anchored = true
	BarrageFX.CFrame   = spawnCFrame
	BarrageFX.Parent   = workspace.FX

	local mineHitbox = HitboxModule.new()
	mineHitbox:AttachToPart(BarrageFX)
	mineHitbox:AddToIgnore(ownerChar)
	mineHitbox.Size    = BARRAGE_CONFIG.HitboxSize
	mineHitbox.HitType = "Multiple"
	--mineHitbox:CreateVisualPart(true)
	--mineHitbox:ConnectToTarget()

	local triggered = false

	local function destroyMine()
		if triggered then return end
		triggered = true

		if mineHitbox then
			mineHitbox:Cleanup()
		end

		if BarrageFX and BarrageFX.Parent then
			BarrageFX:Destroy()
		end
	end
	
	task.delay(30, destroyMine)

	mineHitbox.OnTouch = function(enemyCharacter)
		if triggered then return end
		if enemyCharacter == ownerChar then return end

		local enemyPlayer   = Players:GetPlayerFromCharacter(enemyCharacter)
		local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
		local enemyHumRP    = enemyCharacter:FindFirstChild("HumanoidRootPart")

		if not (enemyHumanoid and enemyHumRP) or enemyHumanoid.Health <= 0 then return end

		local getenemy = StateManager.GET(enemyCharacter)
		if getenemy and getenemy[StateManagerEnums.STATES_ENUM.COMBAT_IFRAME] then return end

		if enemyPlayer and ownerPlayer then
			if CombatBlock.CheckAndApplyCombat(enemyPlayer, ownerPlayer, damage, false) then return end
		end

		destroyMine()

		Sounds:FindFirstChild("HitSFX"):Play()
		DamageModule.TakeDamage(enemyCharacter, damage, true)
		IncreaseUltProgress:Fire(ownerPlayer, BARRAGE_CONFIG.UltimateGainPerHit)
		SendDamageIndicator:FireClient(ownerPlayer)

		CombatReplicator.CameraShake({magnitude = 65,position  = enemyHumRP.Position,radius = 15,duration  = 0.6,fadeIn    = 0.1,fadeOut   = 0.3})
		CombatReplicator.Highlight(enemyCharacter, {Color = Color3.fromRGB(255, 0, 0), Duration = 0.6})
		DamageIndicator(enemyCharacter, damage, Color3.new(1, 0.5, 0))
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
		task.delay(stunTime, function()
			StateManager.REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		end)
	end

	task.spawn(function()
		local elapsed = 0
		while not triggered do
			local dt = RunService.Heartbeat:Wait()
			elapsed += dt

			if elapsed >= duration then
				destroyMine()
				break
			end

			-- passa nil pra não acumular sessionHits entre frames
			mineHitbox:CheckHits(nil)
		end
	end)
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

	if state.barrageActive then return end

	local humanoid = char:FindFirstChild("Humanoid")
	local humRP    = char:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChild("Animator")

	if not (humanoid and humRP and animator) or humanoid.Health <= 0 then return end

	local getCharacter = StateManager.GET(char)
	if getCharacter and getCharacter[StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED] or getCharacter[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED] then return end

	local animObj = Animations:FindFirstChild("Ability1")
	if not animObj then
		warn("[TomTheTitanShark] Animação não encontrada")
		return
	end

	state.barrageActive = true
	char.Humanoid.AutoRotate = false

	local BarrageTrack = animator:LoadAnimation(animObj)

	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	local function cleanup()
		if not state.barrageActive then return end
		state.barrageActive = false

		if BarrageTrack and BarrageTrack.IsPlaying then
			BarrageTrack:Stop()
		end

		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		char.Humanoid.AutoRotate = true
	end

	-- Monitor: se o player for stunado, cancela a animação
	task.spawn(function()
		while state.barrageActive do
			local currentGet = StateManager.GET(char)
			if currentGet and currentGet[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED] then
				BarrageTrack:Stop()
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)

	BarrageTrack.Priority = Enum.AnimationPriority.Action2
	BarrageTrack:Play()

	Sounds:FindFirstChild("Hit"):Play()

	-- Captura a posição do pé do jogador no momento do cast
	task.delay(0.3, function()
		if not state.barrageActive then return end

		-- Pé do jogador = HumRP.Position - metade da altura do personagem (~3 studs)
		local footPosition = humRP.Position - Vector3.new(0, 3, 0)
		local mineCFrame   = CFrame.new(footPosition)

		spawnMine(char, player, mineCFrame)
	end)

	BarrageTrack.Stopped:Connect(function()
		cleanup()
	end)
end

return module