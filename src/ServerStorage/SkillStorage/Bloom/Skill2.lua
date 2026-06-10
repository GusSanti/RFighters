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
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local HitboxModule      = require(ServerStorage.FightModules.HitboxHandler)
local DamageIndicator   = require(ReplicatedStorage.Modules.Shared:WaitForChild("DamageIndicator"))
local knockback         = require(game.ReplicatedStorage.CombatSystem.CombatKnockback)
local knockbackProfiles = require(ServerStorage.CombatStorage.GlobalStorage.KnockbackProfiles)
local CombatBlock       = require(game.ReplicatedStorage.CombatSystem.CombatBlock)
local DamageModule = require(game.ReplicatedStorage.CombatSystem.DamageModule)

local SKILL_CONFIG = {
	HitboxSize         = Vector3.new(8, 8, 26),
	HitboxOffset       = CFrame.new(0, 0, -12),
	Damage             = 25,
	StunTime           = 10,
	UltGain            = 15,

	DamageTick         = 3,
	DamageTickRate     = 1,
}

function module.UseSkill(char: Model)
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end

	local Character = char
	local humanoid  = Character:FindFirstChild("Humanoid")
	local humRP     = Character:FindFirstChild("HumanoidRootPart")
	local animator  = humanoid and humanoid:FindFirstChild("Animator") :: Animator

	local hitConnection = nil

	local SkillTrack = animator:LoadAnimation(Animations.Ability2) :: AnimationTrack

	StateManager.POST(Character, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	SkillTrack.Priority = Enum.AnimationPriority.Action2
	SkillTrack:Play()

	--CombatReplicator.Emit(humRP, Fx.Ability2Slashes)
	local SkillFX = Fx["Ability 2"]:Clone()
	SkillFX.Parent = humRP
	
	local Weld = Instance.new("Weld")
	Weld.Part0 = SkillFX
	Weld.Part1 = humRP
	Weld.Parent = SkillFX

	SkillTrack.Stopped:Connect(function()
		if hitConnection then
			hitConnection:Disconnect()
			hitConnection = nil
		end

		StateManager.REMOVE(Character, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	end)

	task.wait(0.4)

	task.spawn(function()

		local elapsed = 0

		while elapsed < SKILL_CONFIG.StunTime do
			task.wait(SKILL_CONFIG.DamageTickRate)
			elapsed += SKILL_CONFIG.DamageTickRate

			local tickDamage = SKILL_CONFIG.DamageTick

			-- cura o atacante
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = math.min(
					humanoid.Health + tickDamage,
					humanoid.MaxHealth
				)
			end

			CombatReplicator.Highlight(Character, {Color = Color3.fromRGB(47, 255, 0), Duration = 0.5})
		end
		
		SkillFX:Destroy()
		Weld:Destroy()
	end)
end

return module