local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local Assets            = ReplicatedStorage.SkillStorage.IstemiCapy
local Fx                = Assets.FX
local Sounds            = Assets.Sounds
local Animations        = Assets.Animations

local DeathConnectionEvent = game.ReplicatedStorage.CombatSystem.Events.DeathConnectionEvent
local SendDamageIndicator = game.ReplicatedStorage.Events:WaitForChild("SendDamageIndicator")
local CutsceneCameraReplicate = ReplicatedStorage.Events.CutsceneCameraReplicate

local CombatReplicator  = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local Utilities         = require(ReplicatedStorage.Modules.Utilitary.Utils)
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local HitboxModule      = require(ServerStorage.FightModules.HitboxHandler)
local DamageIndicator   = require(ReplicatedStorage.Modules.Shared:WaitForChild("DamageIndicator"))
local CombatBlock       = require(game.ReplicatedStorage.CombatSystem.CombatBlock)
local knockback         = require(game.ReplicatedStorage.CombatSystem.CombatKnockback)
local knockbackProfiles = require(ServerStorage.CombatStorage.GlobalStorage.KnockbackProfiles)
local DamageModule = require(game.ReplicatedStorage.CombatSystem.DamageModule)

local CONFIG = {
	Damage    = 10,
	HitboxSize       = Vector3.new(6, 6, 6),
}

function module.UseSkill(char: Model)
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end

	local humanoid = char:FindFirstChild("Humanoid")
	local humRP    = char:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChild("Animator")
	if not (humanoid and humRP and animator) or humanoid.Health <= 0 then return end

	local getCharacter = StateManager.GET(char)
	if getCharacter and (
		getCharacter[StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED] or
			getCharacter[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED]
		) then return end

	local animObj = Animations:FindFirstChild("Ability3")
	if not animObj then
		warn("[Ultimate] Animação",animObj.Name,Assets,"Não encontrada")
		return
	end

	-- ServerScript
	CutsceneCameraReplicate:FireClient(player, {
		CameraModel     = Fx.Camera,
		Animation       = Animations.Ability3Cutscene,
		CamPartName     = "Cam",
		WeldToCharacter = true,
		WeldC0 = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(180), math.rad(0)),
		WeldC1 = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		RestoreInstant  = true,
	})

	local track = animator:LoadAnimation(animObj)
	track.Priority = Enum.AnimationPriority.Action2
	track:Play()
	
	local mainHitbox = HitboxModule.new()
	mainHitbox:AttachToCharacter(char)
	mainHitbox.Size    = CONFIG.HitboxSize
	mainHitbox:CreateVisualPart(true)
	mainHitbox.HitType = "Multiple"
	
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)


	track.Stopped:Connect(function()
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	end)
	
	task.wait(1)
	
	mainHitbox.OnTouch = function(enemyCharacter)

		local enemyplayer = game.Players:GetPlayerFromCharacter(enemyCharacter)
		local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
		local enemyHumRP    = enemyCharacter:FindFirstChild("HumanoidRootPart")
		if not (enemyHumanoid and enemyHumRP) or enemyHumanoid.Health <= 0 then return end

		local getenemy = StateManager.GET(enemyCharacter)
		if getenemy then
			if getenemy[StateManagerEnums.STATES_ENUM.COMBAT_IFRAME] then return end
		end

		if enemyplayer then
			if CombatBlock.CheckAndApplyCombat(enemyplayer, player, CONFIG.DamagePerHit, false) then return end
		end


		local HitSFX = Sounds:FindFirstChild("HitSFX"):Clone()
		HitSFX.Parent = enemyCharacter.Torso
		HitSFX:Play()
		HitSFX.Ended:Connect(function()
			HitSFX:Destroy()
		end)

		DamageModule.TakeDamage(enemyCharacter, CONFIG.Damage, true)

		SendDamageIndicator:FireClient(player)
		CombatReplicator.Highlight(enemyCharacter, {Color = Color3.fromRGB(255, 0, 0), Duration = 0.2})
		DamageIndicator(enemyCharacter, CONFIG.Damage, Color3.new(1, 0.5, 0))
		knockback.ApplyKnockback({
			Profile = knockbackProfiles.LauncherLight,

			KnockdownInfo = {
				Duration = 1.5,
				InAirAnim = game.ReplicatedStorage.CombatStorage.GlobalAnimations.airlow,
				FallAnim = game.ReplicatedStorage.CombatStorage.GlobalAnimations.fall,
				WakeUpAnim = game.ReplicatedStorage.CombatStorage.GlobalAnimations.wakeup
			}
		}, enemyCharacter)
		
		StateManager.POST_REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_SKILL_BEING_ATTACKED, 0.5)

		CombatReplicator.CameraShake({magnitude = 65, position = enemyCharacter.HumanoidRootPart.Position, radius = 15, duration = 0.2, fadeIn = 0.1, fadeOut = 0.3})
	end

	mainHitbox:Once()
end

return module