local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

local Assets       = ReplicatedStorage.SkillStorage.Toad
local Fx           = Assets.FX
local Sounds       = Assets.Sounds
local Animations   = Assets.Animations

local SendDamageIndicator = game.ReplicatedStorage.Events:WaitForChild("SendDamageIndicator")
local IncreaseUltProgress = game.ReplicatedStorage.Events.IcreaseUltProgress

local CombatReplicator  = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local HitboxModule      = require(ServerStorage.FightModules.HitboxHandler)
local DamageIndicator   = require(ReplicatedStorage.Modules.Shared:WaitForChild("DamageIndicator"))
local CombatBlock       = require(game.ReplicatedStorage.CombatSystem.CombatBlock)
local DamageModule      = require(game.ReplicatedStorage.CombatSystem.DamageModule)

-- ─────────────────────────────────────────────────────────────────────────────
-- CONFIG
-- ─────────────────────────────────────────────────────────────────────────────
local SKILL_CONFIG = {
	HitboxSize   = Vector3.new(8, 8, 26),
	HitboxOffset = CFrame.new(0, 0, -12),

	InitialDamage = 20,
	UltGain       = 15,

	-- "Confuse" – enemy self-damages for the duration
	ConfuseDuration  = 5,     -- seconds
	ConfuseTickRate  = 1,     -- seconds between self-damage ticks
	ConfuseDamage    = 6,     -- damage the enemy deals to itself each tick
}

-- Prevent double-confuse on the same target
local activeConfuseTargets = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- INTERNAL: make enemy attack itself (self-damage loop)
-- ─────────────────────────────────────────────────────────────────────────────
local function applyConfuse(enemyCharacter, attackerPlayer)
	if activeConfuseTargets[enemyCharacter] then return end
	activeConfuseTargets[enemyCharacter] = true

	local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
	local enemyHumRP    = enemyCharacter:FindFirstChild("HumanoidRootPart")
	if not (enemyHumanoid and enemyHumRP) then
		activeConfuseTargets[enemyCharacter] = nil
		return
	end

	-- Persistent confuse VFX (reuse or use a dedicated one)
	if Fx:FindFirstChild("ConfuseEffect") then
		CombatReplicator.Enable(enemyHumRP, Fx.ConfuseEffect, SKILL_CONFIG.ConfuseDuration)
	elseif Fx:FindFirstChild("Ab2Stun") then
		CombatReplicator.Enable(enemyHumRP, Fx.Ab2Stun, SKILL_CONFIG.ConfuseDuration)
	end

	task.spawn(function()
		local elapsed = 0
		while elapsed < SKILL_CONFIG.ConfuseDuration do
			task.wait(SKILL_CONFIG.ConfuseTickRate)
			elapsed += SKILL_CONFIG.ConfuseTickRate

			if not enemyCharacter.Parent then break end
			if enemyHumanoid.Health <= 0  then break end
			-- Stop at 1 HP – never finish the enemy via self-damage
			if enemyHumanoid.Health <= 1  then continue end

			local actualDamage = math.min(SKILL_CONFIG.ConfuseDamage, enemyHumanoid.Health - 1)

			-- Self-damage: enemy hurts itself
			DamageModule.TakeDamage(enemyCharacter, actualDamage)

			-- Visual feedback on the confused enemy (purple = confuse)
			DamageIndicator(enemyCharacter, actualDamage, Color3.fromRGB(180, 0, 255))
			CombatReplicator.Highlight(enemyCharacter, { Color = Color3.fromRGB(180, 0, 255), Duration = 0.3 })

			-- Small ult gain per tick for attacker
			IncreaseUltProgress:Fire(attackerPlayer, 1)
			SendDamageIndicator:FireClient(attackerPlayer)

			if Sounds:FindFirstChild("HitSFX") then
				local sfx = Sounds.HitSFX:Clone()
				sfx.Parent = enemyHumRP
				sfx:Play()
				sfx.Ended:Connect(function() sfx:Destroy() end)
			end
		end

		activeConfuseTargets[enemyCharacter] = nil
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SKILL ENTRY POINT
-- Ability 2 – Shoots a poison dart that causes the opponent to attack itself for 5 s
-- ─────────────────────────────────────────────────────────────────────────────
function module.UseSkill(char: Model)
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end

	local humanoid = char:FindFirstChild("Humanoid")
	local humRP    = char:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChild("Animator") :: Animator

	if not (humanoid and humRP and animator) or humanoid.Health <= 0 then return end

	local mainHitbox    = nil
	local hitConnection = nil

	local SkillTrack = animator:LoadAnimation(Animations.Ability2) :: AnimationTrack

	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	SkillTrack.Priority = Enum.AnimationPriority.Action2
	SkillTrack:Play()

	-- Dart shoot SFX
	if Sounds:FindFirstChild("DartSFX") then
		local sfx = Sounds.DartSFX:Clone()
		sfx.Parent = humRP
		sfx:Play()
		sfx.Ended:Connect(function() sfx:Destroy() end)
	end

	CombatReplicator.Emit(humRP, Fx.Ability2Slashes)

	SkillTrack.Stopped:Connect(function()
		if hitConnection then hitConnection:Disconnect(); hitConnection = nil end
		if mainHitbox    then mainHitbox:Destroy();       mainHitbox    = nil end
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	end)

	task.wait(0.30)

	mainHitbox = HitboxModule.new()
	mainHitbox:AttachToCharacter(char)
	mainHitbox.Size    = SKILL_CONFIG.HitboxSize
	mainHitbox:CreateVisualPart(false)
	mainHitbox:SetOffset(SKILL_CONFIG.HitboxOffset)
	mainHitbox.HitType = "Multiple"

	hitConnection = RunService.Heartbeat:Connect(function()
		mainHitbox.OnTouch = function(enemyCharacter)
			local enemyPlayer   = Players:GetPlayerFromCharacter(enemyCharacter)
			local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
			local enemyHumRP    = enemyCharacter:FindFirstChild("HumanoidRootPart")

			if not (enemyHumanoid and enemyHumRP) or enemyHumanoid.Health <= 0 then return end

			local getenemy = StateManager.GET(enemyCharacter)
			if getenemy then
				if getenemy[StateManagerEnums.STATES_ENUM.COMBAT_IFRAME]           then return end
				if getenemy[StateManagerEnums.STATES_ENUM.COMBAT_SLIGHTLY_STUNNED] then return end
			end

			if enemyPlayer then
				if CombatBlock.CheckAndApplyCombat(enemyPlayer, player, SKILL_CONFIG.InitialDamage, false) then return end
			end

			-- Hit SFX
			if Sounds:FindFirstChild("HitSFX") then
				local sfx = Sounds.HitSFX:Clone()
				sfx.Parent = enemyCharacter:FindFirstChild("Torso") or enemyHumRP
				sfx:Play()
				sfx.Ended:Connect(function() sfx:Destroy() end)
			end

			-- Initial dart damage
			DamageModule.TakeDamage(enemyCharacter, SKILL_CONFIG.InitialDamage, true)
			IncreaseUltProgress:Fire(player, SKILL_CONFIG.UltGain)
			SendDamageIndicator:FireClient(player)
			CombatReplicator.Highlight(enemyCharacter, { Color = Color3.fromRGB(180, 0, 255), Duration = 0.2 })
			DamageIndicator(enemyCharacter, SKILL_CONFIG.InitialDamage, Color3.fromRGB(180, 0, 255))

			-- Slight stun on hit
			StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SLIGHTLY_STUNNED, 0.5)
			StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SKILL_BEING_ATTACKED,0.5)

			-- Apply confuse (self-attack loop)
			applyConfuse(enemyCharacter, player)
		end

		mainHitbox:Once()
	end)
end

return module