local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

local Assets            = ReplicatedStorage.SkillStorage.Grimm
local Fx                = Assets.FX
local Sounds            = Assets.Sounds
local Animations        = Assets.Animations

local SendStreakUpdate    = game.ReplicatedStorage.Events:WaitForChild("UpdateStreakInfo")
local IncreaseUltProgress = game.ReplicatedStorage.Events.IcreaseUltProgress

local CombatReplicator  = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local HitboxModule      = require(ServerStorage.FightModules.HitboxHandler)
local DamageIndicator   = require(ReplicatedStorage.Modules.Shared:WaitForChild("DamageIndicator"))
local knockback         = require(game.ReplicatedStorage.CombatSystem.CombatKnockback)
local knockbackProfiles = require(ServerStorage.CombatStorage.GlobalStorage.KnockbackProfiles)
local CombatBlock       = require(game.ReplicatedStorage.CombatSystem.CombatBlock)
local DamageModule      = require(game.ReplicatedStorage.CombatSystem.DamageModule)

local SKILL_CONFIG = {
	HitboxSize    = Vector3.new(8, 8, 26),
	HitboxOffset  = CFrame.new(0, 0, -12),
	Damage        = 25,
	StunTime      = 5,
	UltGain       = 15,

	-- Drain tick
	DamageTick    = 3,
	DamageTickRate = 1,
}

function module.UseSkill(char: Model)
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end

	local humanoid = char:FindFirstChild("Humanoid")
	local humRP    = char:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChild("Animator") :: Animator
	if not (humanoid and humRP and animator) then return end

	local mainHitbox    = nil
	local hitConnection = nil

	local SkillTrack = animator:LoadAnimation(Animations.Ability2) :: AnimationTrack

	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	SkillTrack.Priority = Enum.AnimationPriority.Action2
	SkillTrack:Play()

	CombatReplicator.Emit(humRP, Fx.Ability2Slashes)

	SkillTrack.Stopped:Connect(function()
		if hitConnection then
			hitConnection:Disconnect()
			hitConnection = nil
		end
		if mainHitbox then
			mainHitbox:Destroy()
			mainHitbox = nil
		end
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	end)

	task.wait(0.4)

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
				if getenemy[StateManagerEnums.STATES_ENUM.COMBAT_IFRAME] then return end
				if getenemy[StateManagerEnums.STATES_ENUM.COMBAT_SLIGHTLY_STUNNED] then return end
			end

			if enemyPlayer then
				if CombatBlock.CheckAndApplyCombat(enemyPlayer, player, SKILL_CONFIG.Damage, false) then return end
			end

			local HitSFX = Sounds:FindFirstChild("HitSFX"):Clone()
			HitSFX.Parent = enemyCharacter:FindFirstChild("Torso") or enemyHumRP
			HitSFX:Play()
			HitSFX.Ended:Connect(function() HitSFX:Destroy() end)

			-- FIX: era TakeDamage(enemyCharacter, SKILL_CONFIG.Damage, true, Character)
			-- 'true' era o padrão antigo; atualizado para {StopDelay}
			DamageModule.TakeDamage(enemyCharacter, SKILL_CONFIG.Damage, {StopDelay = SKILL_CONFIG.StunTime}, char)

			IncreaseUltProgress:Fire(player, SKILL_CONFIG.UltGain)
			SendStreakUpdate:Fire(player)
			CombatReplicator.Highlight(enemyCharacter, {Color = Color3.fromRGB(255, 0, 0), Duration = 0.2})
			DamageIndicator(enemyCharacter, SKILL_CONFIG.Damage, Color3.new(1, 0.5, 0))

			knockback.ApplyKnockback({
				Profile = knockbackProfiles.LauncherUp,
				KnockdownInfo = {
					Duration = 0.35,
					CanContinueCombo = true,
					WakeUpKnockback = knockbackProfiles.WakeUpBackKnockback,
					InAirAnim = game.ReplicatedStorage.CombatStorage.GlobalAnimations.airlow,
					FallAnim = game.ReplicatedStorage.CombatStorage.GlobalAnimations.fall,
					GroundAnim = game.ReplicatedStorage.CombatStorage.GlobalAnimations.falled,
					WakeUpAnim = game.ReplicatedStorage.CombatStorage.GlobalAnimations.backroll
				}
			}, enemyCharacter)

			CombatReplicator.Enable(enemyHumRP, Fx.Ab2Stun, SKILL_CONFIG.StunTime)
			StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SLIGHTLY_STUNNED, 0.5)
			StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SKILL_BEING_ATTACKED, 0.5)

			-- ── Drain tick (lifesteal) ─────────────────────────────────────
			task.spawn(function()
				local elapsed = 0

				while elapsed < SKILL_CONFIG.StunTime do
					task.wait(SKILL_CONFIG.DamageTickRate)
					elapsed += SKILL_CONFIG.DamageTickRate

					-- Para se o inimigo morreu ou o atacante morreu
					if enemyHumanoid.Health <= 0 then break end
					if humanoid.Health <= 0 then break end

					-- Não leva o inimigo abaixo de 1 HP via tick
					if enemyHumanoid.Health <= 1 then continue end

					-- FIX: era TakeDamage(enemyCharacter, tickDamage, nil, Character)
					-- nil era o padrão antigo; mantido como nil pois é tick sem stun extra
					DamageModule.TakeDamage(enemyCharacter, SKILL_CONFIG.DamageTick, nil, char)

					-- Cura o atacante
					humanoid.Health = math.min(
						humanoid.Health + SKILL_CONFIG.DamageTick,
						humanoid.MaxHealth
					)

					local TickSFX = Sounds:FindFirstChild("HitSFX"):Clone()
					TickSFX.Parent = enemyCharacter:FindFirstChild("Torso") or enemyHumRP
					TickSFX:Play()
					TickSFX.Ended:Connect(function() TickSFX:Destroy() end)

					DamageIndicator(enemyCharacter, SKILL_CONFIG.DamageTick, Color3.new(1, 0, 0))
					CombatReplicator.Highlight(enemyCharacter, {Color = Color3.fromRGB(255, 0, 0), Duration = 0.5})
					CombatReplicator.Highlight(char, {Color = Color3.fromRGB(47, 255, 0), Duration = 0.5})
				end
			end)
		end

		mainHitbox:Once()
	end)
end

return module