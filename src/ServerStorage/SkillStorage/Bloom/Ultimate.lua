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
local CutsceneCameraReplicate = ReplicatedStorage.Events.CutsceneCameraReplicate

local CombatReplicator = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local HitboxModule      = require(ServerStorage.FightModules.HitboxHandler)
local DamageIndicator   = require(ReplicatedStorage.Modules.Shared:WaitForChild("DamageIndicator"))
local CombatBlock       = require(game.ReplicatedStorage.CombatSystem.CombatBlock)
local KnockbackModule   = require(game.ReplicatedStorage.CombatSystem.CombatKnockback)
local KnockbackProfilexs = require(ServerStorage.CombatStorage.GlobalStorage.KnockbackProfiles)
local DamageModule = require(game.ReplicatedStorage.CombatSystem.DamageModule)
local PlayAnimation = require(game.ReplicatedStorage.CombatSystem.PlayAnimationServer)

local SKILL_CONFIG = {
	HitboxSize         = Vector3.new(8, 8, 8),
	HitboxOffset       = CFrame.new(0, 0, -6),
	Damage             = 25,
	StunTime           = 0.39,
	UltGain            = 15
	
}

function module.UseSkill(char: Model)
	warn('GLADHOR SKILL 2')
	
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end

	local Character = char
	local humanoid  = Character:FindFirstChild("Humanoid")
	local humRP     = Character:FindFirstChild("HumanoidRootPart")
	local animator  = humanoid and humanoid:FindFirstChild("Animator") :: Animator
	
	local mainHitbox    = nil
	local hitConnection = nil
	
	local SkillTrack = animator:LoadAnimation(Animations.Ability3) :: AnimationTrack
	
	StateManager.POST(Character, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	
	SkillTrack.Priority = Enum.AnimationPriority.Action2
	SkillTrack:Play()
	
	CutsceneCameraReplicate:FireClient(player, {
		CameraModel     = Fx.Camera,
		Animation       = Animations.Ability3Cutscene,
		CamPartName     = "Cam",
		WeldToCharacter = true,
		WeldC0 = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(180), math.rad(0)),
		WeldC1 = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		RestoreInstant  = true,
	})
	
	local sfx = Sounds:FindFirstChild("HitSFX"):Clone()
	sfx.Parent = humRP
	sfx:Play()
	sfx.Ended:Connect(function()
		sfx:Destroy()
	end)
	
	task.spawn(function()
		task.wait(0.45)
		CombatReplicator.Emit(humRP, Fx["Super"])
	end)
	
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
	
	task.wait(0.35)
	
	mainHitbox = HitboxModule.new()
	mainHitbox:AttachToCharacter(Character)
	mainHitbox.Size    = SKILL_CONFIG.HitboxSize
	mainHitbox:SetOffset(SKILL_CONFIG.HitboxOffset)
	mainHitbox.HitType = "Single"
	mainHitbox:CreateVisualPart()
	
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
				if getenemy[StateManagerEnums.STATES_ENUM.COMBAT_SLIGHTLY_STUNNED] then return end
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
			KnockbackModule.ApplyKnockback({Profile = KnockbackProfilexs.LauncherLight}, enemyCharacter, 0, Character)
			PlayAnimation.PlayCharacterAnimation(enemyCharacter, ReplicatedStorage.CombatStorage.GlobalAnimations.high)
			
			--CombatReplicator.Emit(enemyHumRP, Fx["Ability 2"])
			StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SLIGHTLY_STUNNED, SKILL_CONFIG.StunTime)
			StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SKILL_BEING_ATTACKED, 0.5)
		end
		
		mainHitbox:Once()
	end)
	
	
end

return module