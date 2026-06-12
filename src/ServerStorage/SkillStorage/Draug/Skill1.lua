local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local Assets            = ReplicatedStorage.SkillStorage.Draug
local Fx                = Assets.FX
local Sounds            = Assets.Sounds
local Animations        = Assets.Animations

local DeathConnectionEvent = game.ReplicatedStorage.CombatSystem.Events.DeathConnectionEvent
local SendStreakUpdate = game.ReplicatedStorage.Events:WaitForChild("UpdateStreakInfo")
local IncreaseUltProgress = game.ReplicatedStorage.Events.IcreaseUltProgress


local CombatReplicator = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local Utilities         = require(ReplicatedStorage.Modules.Utilitary.Utils)

local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local HitboxModule      = require(ServerStorage.FightModules.HitboxHandler)
local DamageIndicator   = require(ReplicatedStorage.Modules.Shared:WaitForChild("DamageIndicator"))
local knockback         = require(ServerStorage.FightModules.Knockback)
local CombatBlock       = require(game.ReplicatedStorage.CombatSystem.CombatBlock)
local DamageModule = require(game.ReplicatedStorage.CombatSystem.DamageModule)

local BARRAGE_CONFIG = {
	DamagePerHit   = 5,
	HitboxSize     = Vector3.new(8, 8, 11),
	HitboxOffset   = CFrame.new(0, 0, -6),
	NormalKnockback = {
		MaxForce           = Vector3.new(2e4, 0, 2e4),
		VelocityMultiplier = 15,
		Duration           = 0.08
	},
	UltimateGainPerHit = 0.5,
}

local playerStates = {}

local function setupPlayerState(player)
	local userId = player.UserId
	if not playerStates[userId] then
		playerStates[userId] = {
			barrageActive = false,
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

local function applyNormalKnockback(character, attackerHumRP)
	local config = BARRAGE_CONFIG.NormalKnockback
	local direction = attackerHumRP.CFrame.LookVector
	knockback:Knockback(character, {
		MaxForce = config.MaxForce,
		Velocity  = direction * config.VelocityMultiplier,
		Duration  = config.Duration
	})
end

local function doHit(mainHitbox, Character, humRP)
	local damage   = BARRAGE_CONFIG.DamagePerHit
	local stunTime = BARRAGE_CONFIG.NormalKnockback.Duration + 0.1
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

		local HitSFX = Sounds:FindFirstChild("HitSFX"):Clone()
		HitSFX.Parent = enemyCharacter.Torso
		HitSFX:Play()
		HitSFX.Ended:Connect(function() HitSFX:Destroy() end)
		
		DamageModule.TakeDamage(enemyCharacter, damage, true, Character)
		
		IncreaseUltProgress:Fire(player, BARRAGE_CONFIG.UltimateGainPerHit)
		SendStreakUpdate:Fire(player)

		CombatReplicator.CameraShake({magnitude = 65, position = enemyHumRP.Position, radius = 15, duration = 0.6, fadeIn = 0.1, fadeOut = 0.3})
		CombatReplicator.Highlight(enemyCharacter, {Color = Color3.fromRGB(255, 0, 0), Duration = 0.6})
		DamageIndicator(enemyCharacter, damage, Color3.new(1, 0.5, 0))
		applyNormalKnockback(enemyCharacter, humRP)

		StateManager.POST(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SKILL_BEING_ATTACKED, 0.5)
		task.delay(stunTime, function()
			StateManager.REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		end)
	end

	mainHitbox:Once()
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
		warn("[Draug Ability1] Animação não encontrada")
		return
	end

	state.barrageActive = true

	char.Humanoid.AutoRotate = false

	local SlamTrack  = animator:LoadAnimation(animObj)
	local mainHitbox    = nil
	local hitConnection = nil
	
	local WindFX = char:FindFirstChild("Windstuffgoeshere")
	local SlamFX = char:FindFirstChild("Slam")

	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	local function cleanup()
		if not state.barrageActive then return end
		state.barrageActive = false

		if hitConnection then
			hitConnection:Disconnect()
			hitConnection = nil
		end

		if mainHitbox then
			mainHitbox:Destroy()
			mainHitbox = nil
		end

		if SlamTrack and SlamTrack.IsPlaying then
			SlamTrack:Stop()
		end

		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		char.Humanoid.AutoRotate = true
	end

	task.spawn(function()
		while state.barrageActive do
			local currentGet = StateManager.GET(char)
			if currentGet and currentGet[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED] then
				SlamTrack:Stop()
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)

	SlamTrack.Priority = Enum.AnimationPriority.Action2
	SlamTrack:Play()

	mainHitbox = HitboxModule.new()
	mainHitbox:AttachToCharacter(char)
	mainHitbox.Size    = BARRAGE_CONFIG.HitboxSize
	mainHitbox:CreateVisualPart(false)
	mainHitbox:SetOffset(BARRAGE_CONFIG.HitboxOffset)
	mainHitbox.HitType = "Multiple"

	SlamTrack:GetMarkerReachedSignal("Wind"):Connect(function()
		Utilities.Particle_Setup({Holder = WindFX, Type = "Emit"})
		local WindSfx = Sounds:FindFirstChild("Wind"):Clone()
		WindSfx.Parent = humRP
		WindSfx:Play()
		WindSfx.Ended:Connect(function()
			WindSfx:Destroy()
		end)
	end)
	
	SlamTrack:GetMarkerReachedSignal("Slam"):Connect(function()
		-- Freeze the animation at the slam pose until the character reaches the
		-- ground, so the hit connects when the slam visually impacts (timeout 2s).
		if humanoid.FloorMaterial == Enum.Material.Air then
			SlamTrack:AdjustSpeed(0)
			local waitStart = os.clock()
			while humanoid.FloorMaterial == Enum.Material.Air do
				if not state.barrageActive then return end
				if os.clock() - waitStart > 2 then break end
				RunService.Heartbeat:Wait()
			end
			SlamTrack:AdjustSpeed(1)
		end

		Utilities.Particle_Setup({Holder = SlamFX, Type = "Emit"})
		doHit(mainHitbox, char, humRP)
		
		local SlamSfx = Sounds:FindFirstChild("Slam"):Clone()
		SlamSfx.Parent = humRP
		SlamSfx:Play()
		SlamSfx.Ended:Connect(function()
			SlamSfx:Destroy()
		end)
	end)

	SlamTrack.Stopped:Connect(function()
		cleanup()
	end)
end

return module