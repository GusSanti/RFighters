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
	HitboxSize    = Vector3.new(8, 8, 14),
	HitboxOffset  = CFrame.new(0, 0, -8),

	InitialDamage = 10,
	UltGain       = 10,

	PoisonDuration = 5,  -- seconds
	PoisonTickRate = 1,  -- seconds between ticks
	PoisonDamage   = 8,  -- damage per tick

	-- Enemy walks at this fraction of their normal WalkSpeed while poisoned
	SlowMultiplier = 0.45,
}

-- Prevent double-stacking poison on the same target
local activePoisonTargets = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- INTERNAL: apply slow + DoT to an enemy
-- ─────────────────────────────────────────────────────────────────────────────
local function applyPoison(enemyCharacter, attackerPlayer)
	if activePoisonTargets[enemyCharacter] then return end
	activePoisonTargets[enemyCharacter] = true

	local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
	local enemyHumRP    = enemyCharacter:FindFirstChild("HumanoidRootPart")
	if not (enemyHumanoid and enemyHumRP) then
		activePoisonTargets[enemyCharacter] = nil
		return
	end

	-- Slow
	local originalSpeed       = enemyHumanoid.WalkSpeed
	enemyHumanoid.WalkSpeed   = originalSpeed * SKILL_CONFIG.SlowMultiplier

	-- Persistent poison VFX
	if Fx:FindFirstChild("PoisonEffect") then
		CombatReplicator.Enable(enemyHumRP, Fx.PoisonEffect, SKILL_CONFIG.PoisonDuration)
	end

	-- DoT loop
	task.spawn(function()
		local elapsed = 0
		while elapsed < SKILL_CONFIG.PoisonDuration do
			task.wait(SKILL_CONFIG.PoisonTickRate)
			elapsed += SKILL_CONFIG.PoisonTickRate

			if not enemyCharacter.Parent then break end
			if enemyHumanoid.Health <= 0   then break end

			DamageModule.TakeDamage(enemyCharacter, SKILL_CONFIG.PoisonDamage)
			IncreaseUltProgress:Fire(attackerPlayer, 2)
			SendDamageIndicator:FireClient(attackerPlayer)

			DamageIndicator(enemyCharacter, SKILL_CONFIG.PoisonDamage, Color3.fromRGB(0, 200, 50))
			CombatReplicator.Highlight(enemyCharacter, { Color = Color3.fromRGB(0, 220, 60), Duration = 0.3 })

			-- Tick SFX
			if Sounds:FindFirstChild("PoisonTickSFX") then
				local sfx = Sounds.PoisonTickSFX:Clone()
				sfx.Parent = enemyHumRP
				sfx:Play()
				sfx.Ended:Connect(function() sfx:Destroy() end)
			end
		end

		-- Restore speed
		if enemyCharacter.Parent and enemyHumanoid.Health > 0 then
			enemyHumanoid.WalkSpeed = originalSpeed
		end
		activePoisonTargets[enemyCharacter] = nil
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SKILL ENTRY POINT
-- Ability 1 – Stings the opponent with a poison that slows and deals damage over time
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

	local SkillTrack = animator:LoadAnimation(Animations.Ability1) :: AnimationTrack

	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	SkillTrack.Priority = Enum.AnimationPriority.Action2
	SkillTrack:Play()

	if Sounds:FindFirstChild("StingSFX") then
		local sfx = Sounds.StingSFX:Clone()
		sfx.Parent = humRP
		sfx:Play()
		sfx.Ended:Connect(function() sfx:Destroy() end)
	end

	CombatReplicator.Emit(humRP, Fx.Ability1Slashes)

	SkillTrack.Stopped:Connect(function()
		if hitConnection then hitConnection:Disconnect(); hitConnection = nil end
		if mainHitbox    then mainHitbox:Destroy();       mainHitbox    = nil end
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	end)

	task.wait(0.24)

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

			-- Initial damage
			DamageModule.TakeDamage(enemyCharacter, SKILL_CONFIG.InitialDamage, true)
			IncreaseUltProgress:Fire(player, SKILL_CONFIG.UltGain)
			SendDamageIndicator:FireClient(player)
			CombatReplicator.Highlight(enemyCharacter, { Color = Color3.fromRGB(0, 220, 60), Duration = 0.25 })
			DamageIndicator(enemyCharacter, SKILL_CONFIG.InitialDamage, Color3.fromRGB(0, 220, 60))

			-- Slightly stun so they can't immediately act
			StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SLIGHTLY_STUNNED, 0.5)
			StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SKILL_BEING_ATTACKED,0.5)

			-- Apply poison + slow
			applyPoison(enemyCharacter, player)
		end

		mainHitbox:Once()
	end)
end

return module