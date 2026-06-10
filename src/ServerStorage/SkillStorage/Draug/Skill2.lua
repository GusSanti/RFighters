local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local DeathConnectionEvent = game.ReplicatedStorage.CombatSystem.Events.DeathConnectionEvent
local SendStreakUpdate = game.ReplicatedStorage.Events:WaitForChild("UpdateStreakInfo")
local IncreaseUltProgress = game.ReplicatedStorage.Events.IcreaseUltProgress

local Assets            = ReplicatedStorage.SkillStorage.Draug
local Fx                = Assets.FX
local Sounds            = Assets.Sounds
local Animations        = Assets.Animations

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
	HitInterval        = 0.1,
	DamagePerHit       = 2,
	FinalHitDamage     = 8,
	HitboxOffset       = CFrame.new(0, 0, 0),
	NormalKnockback    = {
		MaxForce           = Vector3.new(2e4, 0, 2e4),
		VelocityMultiplier = 15,
		Duration           = 0.08
	},
	UltimateGainPerHit = 0.5,
	FinalUltimateGain  = 3,
	StunDuration       = 2
}

local playerStates = {}

local function setupPlayerState(player)
	local userId = player.UserId
	if not playerStates[userId] then
		playerStates[userId] = {
			barrageActive = false,
			Sfx           = nil,
			barrageHits   = 0
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

	local Character = char
	local humanoid  = Character:FindFirstChild("Humanoid")
	local humRP     = Character:FindFirstChild("HumanoidRootPart")
	local animator  = humanoid and humanoid:FindFirstChild("Animator")

	if not (humanoid and humRP and animator) or humanoid.Health <= 0 then return end

	local getCharacter = StateManager.GET(Character)
	if getCharacter then
		if getCharacter[StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED] or getCharacter[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED] then return end
	end

	local animObj = Animations:FindFirstChild("Ability2")
	if not animObj then
		warn("[Draug Barrage] Animação Ability2 não encontrada em Draug > Animations")
		return
	end

	state.barrageActive = true
	state.barrageHits   = 0
	local cancelled     = false

	local BarrageTrack  = animator:LoadAnimation(animObj)
	local hitConnection = nil
	local mainHitbox    = nil

	StateManager.POST(Character, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	local BarrageFX = Character:FindFirstChild("ROAR")

	local function cleanup()
		if cancelled then return end
		cancelled = true
		state.barrageActive = false

		if hitConnection then
			hitConnection:Disconnect()
			hitConnection = nil
		end

		if mainHitbox then
			mainHitbox:Destroy()
			mainHitbox = nil
		end

		if BarrageTrack and BarrageTrack.IsPlaying then BarrageTrack:Stop() end
		if state.Sfx and state.Sfx.IsPlaying then 
			state.Sfx:Stop()
			state.Sfx:Destroy()
		end

		StateManager.REMOVE(Character, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	end

	-- Monitor de Stun
	task.spawn(function()
		while state.barrageActive and not cancelled do
			local currentGet = StateManager.GET(Character)
			if currentGet and currentGet[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED] then
				cleanup()
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)

	-- Toca a animação
	BarrageTrack.Priority = Enum.AnimationPriority.Action2
	BarrageTrack:Play()

	-- SFX
	if Sounds and Sounds:FindFirstChild("Ability2") then
		state.Sfx = Sounds.Ability2:Clone()
		state.Sfx.Parent = humRP
		state.Sfx:Play()
		state.Sfx.Ended:Connect(function()
			state.Sfx:Destroy()
		end)
	end

	local enemiesHit     = {}
	local lastHitboxTime = 0

	mainHitbox = HitboxModule.new()
	mainHitbox:AttachToCharacter(Character)
	mainHitbox.Size    = BarrageFX.Size
	mainHitbox:CreateVisualPart(false)
	mainHitbox:SetOffset(BARRAGE_CONFIG.HitboxOffset)
	mainHitbox.HitType = "Multiple"
	
	Utilities.Particle_Setup({Holder = BarrageFX, Type = "Emit"})

	hitConnection = RunService.Heartbeat:Connect(function()
		if cancelled or not state.barrageActive then
			cleanup()
			return
		end

		local currentTime = tick()

		if currentTime - lastHitboxTime >= BARRAGE_CONFIG.HitInterval then
			lastHitboxTime = currentTime

			mainHitbox.OnTouch = function(enemyCharacter)
				if cancelled or not state.barrageActive then return end

				local enemyplayer = game.Players:GetPlayerFromCharacter(enemyCharacter)
				local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
				local enemyHumRP    = enemyCharacter:FindFirstChild("HumanoidRootPart")
				if not (enemyHumanoid and enemyHumRP) or enemyHumanoid.Health <= 0  then return end

				local getenemy = StateManager.GET(enemyCharacter)
				if getenemy then
					if getenemy[StateManagerEnums.STATES_ENUM.COMBAT_IFRAME] then return end
				end

				if enemyplayer then
					if CombatBlock.CheckAndApplyCombat(enemyplayer, player, BARRAGE_CONFIG.DamagePerHit, false) then return end
				end

				if not enemiesHit[enemyCharacter] then
					enemiesHit[enemyCharacter] = { totalHits = 0, lastHitTime = 0 }
				end

				local enemyData = enemiesHit[enemyCharacter]

				if currentTime - enemyData.lastHitTime >= BARRAGE_CONFIG.HitInterval then
					enemyData.lastHitTime = currentTime
					enemyData.totalHits  += 1
					state.barrageHits    += 1

					local HitSFX = Sounds:FindFirstChild("HitSFX"):Clone()
					HitSFX.Parent = enemyCharacter.Torso
					HitSFX:Play()
					HitSFX.Ended:Connect(function()
						HitSFX:Destroy()
					end)
					
					DamageModule.TakeDamage(enemyCharacter, BARRAGE_CONFIG.DamagePerHit, true, Character)

					IncreaseUltProgress:Fire(player, BARRAGE_CONFIG.UltimateGainPerHit)
					SendStreakUpdate:Fire(player)
					CombatReplicator.Highlight(enemyCharacter, {Color = Color3.fromRGB(255, 0, 0), Duration = 0.2})
					DamageIndicator(enemyCharacter, BARRAGE_CONFIG.DamagePerHit, Color3.new(1, 0.5, 0))

					CombatReplicator.CameraShake({magnitude = 65,position = enemyCharacter.HumanoidRootPart.Position,radius = 15,duration = 0.2,fadeIn = 0.1,fadeOut = 0.3})

					StateManager.POST(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
					StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SKILL_BEING_ATTACKED, 0.5)
					task.delay(BARRAGE_CONFIG.NormalKnockback.Duration + 0.1, function()
						StateManager.REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
					end)

				end
			end

			mainHitbox:Once()
		end
	end)

	-- Duração = até a animação terminar naturalmente
	BarrageTrack.Stopped:Connect(function()
		if not cancelled then
			local finalHitbox = HitboxModule.new()
			finalHitbox:AttachToCharacter(Character)
			finalHitbox.Size    = BarrageFX.Size
			finalHitbox:SetOffset(BARRAGE_CONFIG.HitboxOffset)
			finalHitbox.HitType = "Multiple"

			finalHitbox.OnTouch = function(enemyCharacter)
				if cancelled or not state.barrageActive then return end

				local enemyplayer = game.Players:GetPlayerFromCharacter(enemyCharacter)
				local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
				local enemyHumRP    = enemyCharacter:FindFirstChild("HumanoidRootPart")
				if not (enemyHumanoid and enemyHumRP) or enemyHumanoid.Health <= 0  then return end

				local getenemy = StateManager.GET(enemyCharacter)
				if getenemy then
					if getenemy[StateManagerEnums.STATES_ENUM.COMBAT_IFRAME] then return end
				end

				if enemyplayer then
					if CombatBlock.CheckAndApplyCombat(enemyplayer, player, BARRAGE_CONFIG.FinalHitDamage, false) then return end
				end
				
				DamageModule.TakeDamage(enemyCharacter, BARRAGE_CONFIG.FinalHitDamage, true, Character)

				IncreaseUltProgress:Fire(player, BARRAGE_CONFIG.FinalUltimateGain)
				SendStreakUpdate:Fire(player)
				DamageIndicator(enemyCharacter, BARRAGE_CONFIG.FinalHitDamage, Color3.new(1, 0, 0))

				CombatReplicator.Highlight(enemyCharacter, {Color = Color3.fromRGB(255, 0, 0), Duration = 0.6})

				StateManager.POST(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
				task.delay(BARRAGE_CONFIG.StunDuration, function()
					StateManager.REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
				end)
			end

			finalHitbox:Once()

			task.delay(0.2, function()
				finalHitbox:Destroy()
			end)
		end

		cleanup()
	end)
end

return module