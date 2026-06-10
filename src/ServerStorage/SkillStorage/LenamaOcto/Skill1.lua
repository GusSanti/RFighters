local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local Assets            = ReplicatedStorage.SkillStorage.LenamaOcto
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
local knockback         = require(ServerStorage.FightModules.Knockback)
local CombatBlock       = require(game.ReplicatedStorage.CombatSystem.CombatBlock)
local DamageModule = require(game.ReplicatedStorage.CombatSystem.DamageModule)

local SKILL_CONFIG = {
	HitboxSize         = Vector3.new(8, 8, 26),
	HitboxOffset       = CFrame.new(0, 0, -12),
	Damage             = 25,
	StunTime           = 5,
	UltGain            = 15,
}

function module.UseSkill(char: Model)
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end

	local Character = char
	local humanoid  = Character:FindFirstChild("Humanoid")
	local humRP     = Character:FindFirstChild("HumanoidRootPart")
	local animator  = humanoid and humanoid:FindFirstChild("Animator") :: Animator
	
	local mainHitbox    = nil
	local hitConnection = nil
	
	local SkillTrack = animator:LoadAnimation(Animations.Ability1) :: AnimationTrack
	
	StateManager.POST(Character, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	
	SkillTrack.Priority = Enum.AnimationPriority.Action2
	SkillTrack:Play()
	
	CombatReplicator.Emit(humRP, Fx.Explosion)
	
	SkillTrack.Stopped:Connect(function()
		if hitConnection then
			hitConnection:Disconnect()
			hitConnection = nil
		end

		if mainHitbox then
			mainHitbox:Destroy()
			mainHitbox = nil
		end
		
		StateManager.REMOVE(Character, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	end)
	
	task.wait(0.4)
	
	mainHitbox = HitboxModule.new()
	mainHitbox:AttachToCharacter(Character)
	mainHitbox.Size    = SKILL_CONFIG.HitboxSize
	mainHitbox:CreateVisualPart(false)              -- 1º cria a part
	mainHitbox:SetOffset(SKILL_CONFIG.HitboxOffset)  -- 2º conecta (agora VisualPart já existe)
	mainHitbox.HitType = "Multiple"
	
	hitConnection = RunService.Heartbeat:Connect(function()
		mainHitbox.OnTouch = function(enemyCharacter)
			print('Hit')
			local enemyplayer = game.Players:GetPlayerFromCharacter(enemyCharacter)
			local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
			local enemyHumRP    = enemyCharacter:FindFirstChild("HumanoidRootPart")
			if not (enemyHumanoid and enemyHumRP) or enemyHumanoid.Health <= 0  then return end

			local getenemy = StateManager.GET(enemyCharacter)
			if getenemy then
				if getenemy[StateManagerEnums.STATES_ENUM.COMBAT_IFRAME] then return end
				if getenemy[StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED] then return end
			end

			if enemyplayer then
				if CombatBlock.CheckAndApplyCombat(enemyplayer, player, SKILL_CONFIG.Damage, false) then return end
			end
			
			local HitSFX = Sounds:FindFirstChild("HitSFX"):Clone()
			HitSFX.Parent = enemyCharacter.Torso
			HitSFX:Play()
			HitSFX.Ended:Connect(function()
				HitSFX:Destroy()
			end)

			DamageModule.TakeDamage(enemyCharacter, SKILL_CONFIG.Damage, true)

			IncreaseUltProgress:Fire(player, SKILL_CONFIG.UltGain)
			SendDamageIndicator:FireClient(player)
			CombatReplicator.Highlight(enemyCharacter, {Color = Color3.fromRGB(255, 0, 0), Duration = 0.2})
			DamageIndicator(enemyCharacter, SKILL_CONFIG.Damage, Color3.new(1, 0.5, 0))
			StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SKILL_BEING_ATTACKED, 0.5)
			
			CombatReplicator.Enable(enemyHumRP, Fx.ChargeEffect, SKILL_CONFIG.StunTime)
			StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED, SKILL_CONFIG.StunTime)
		end
		
		mainHitbox:Once()
	end)
end

return module