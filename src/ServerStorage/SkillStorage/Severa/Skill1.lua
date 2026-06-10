local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

local Assets     = ReplicatedStorage.SkillStorage.Severa
local Fx         = Assets.FX
local Sounds     = Assets.Sounds
local Animations = Assets.Animations

local SendDamageIndicator = ReplicatedStorage.Events:WaitForChild("SendDamageIndicator")
local IncreaseUltProgress = ReplicatedStorage.Events.IcreaseUltProgress

local CombatReplicator  = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local HitboxModule      = require(ServerStorage.FightModules.HitboxHandler)
local DamageIndicator   = require(ReplicatedStorage.Modules.Shared:WaitForChild("DamageIndicator"))
local CombatBlock       = require(game.ReplicatedStorage.CombatSystem.CombatBlock)
local DamageModule      = require(game.ReplicatedStorage.CombatSystem.DamageModule)
local knockback         = require(ServerStorage.FightModules.Knockback)

local CONFIG = {
	Damage       = 15,
	HitboxSize   = Vector3.new(8, 8, 25),
	HitboxOffset = CFrame.new(0, 0, -14),
	PullDistance = 3,
	PullDuration = 0.3,
	PullForce    = 8e4,
	StunDuration = 0.35,
	UltimateGain = 1.0,
}

local playerStates = {}

local function setupPlayerState(player)
	if not playerStates[player.UserId] then
		playerStates[player.UserId] = { active = false }
	end
end

Players.PlayerAdded:Connect(setupPlayerState)
Players.PlayerRemoving:Connect(function(p) playerStates[p.UserId] = nil end)
for _, p in ipairs(Players:GetPlayers()) do setupPlayerState(p) end

local function pullEnemyToFront(enemyCharacter, casterHumRP)
	local enemyHumRP    = enemyCharacter:FindFirstChild("HumanoidRootPart")
	local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
	if not (enemyHumRP and enemyHumanoid) then return end

	local prevAutoRotate     = enemyHumanoid.AutoRotate
	enemyHumanoid.AutoRotate = false

	local bp    = Instance.new("BodyPosition")
	bp.MaxForce = Vector3.new(CONFIG.PullForce, CONFIG.PullForce, CONFIG.PullForce)
	bp.D        = 500
	bp.Parent   = enemyHumRP

	local elapsed = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		bp.Position = casterHumRP.Position + casterHumRP.CFrame.LookVector * CONFIG.PullDistance
		if elapsed >= CONFIG.PullDuration then
			conn:Disconnect()
			bp:Destroy()
			enemyHumanoid.AutoRotate = prevAutoRotate
		end
	end)
end

function module.UseSkill(char: Model)
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end

	local state = playerStates[player.UserId]
	if not state or state.active then return end

	local humanoid = char:FindFirstChild("Humanoid")
	local humRP    = char:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChild("Animator")
	if not (humanoid and humRP and animator) or humanoid.Health <= 0 then return end

	local charState = StateManager.GET(char)
	if charState and (
		charState[StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED] or
			charState[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED]
		) then return end

	local animObj = Animations:FindFirstChild("Ability1")
	if not animObj then warn("[Severa Ability1] Animação não encontrada") return end

	state.active = true

	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	local track = animator:LoadAnimation(animObj)
	track.Priority = Enum.AnimationPriority.Action2
	track:Play()

	local SFX = Sounds:WaitForChild("Ability1"):Clone()
	SFX.Parent = humRP
	SFX:Play()
	SFX.Ended:Connect(function() SFX:Destroy() end)
	
	CombatReplicator.Emit(char:FindFirstChild("Right Arm"), Fx:FindFirstChild("Ability 1"), {C0 = CFrame.new(0, -0.8, 0), C1 = CFrame.new(0,0,0)})

	local hitbox = HitboxModule.new()
	hitbox:AttachToCharacter(char)
	hitbox.Size    = CONFIG.HitboxSize
	hitbox:CreateVisualPart(false)
	hitbox:SetOffset(CONFIG.HitboxOffset)
	hitbox.HitType = "Multiple"

	hitbox.OnTouch = function(enemyCharacter)
		local enemyPlayer   = Players:GetPlayerFromCharacter(enemyCharacter)
		local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
		local enemyHumRP    = enemyCharacter:FindFirstChild("HumanoidRootPart")
		if not (enemyHumanoid and enemyHumRP) or enemyHumanoid.Health <= 0 then return end

		local getenemy = StateManager.GET(enemyCharacter)
		if getenemy and getenemy[StateManagerEnums.STATES_ENUM.COMBAT_IFRAME]  then return end

		if enemyPlayer and player then
			if CombatBlock.CheckAndApplyCombat(enemyPlayer, player, CONFIG.Damage, false) then return end
		end

		DamageModule.TakeDamage(enemyCharacter, CONFIG.Damage, true)
		IncreaseUltProgress:Fire(player, CONFIG.UltimateGain)
		SendDamageIndicator:FireClient(player)

		local HitSFX = Sounds:FindFirstChild("HitSFX") and Sounds.HitSFX:Clone()
		if HitSFX then
			HitSFX.Parent = enemyCharacter:FindFirstChild("Torso") or enemyHumRP
			HitSFX:Play()
			HitSFX.Ended:Connect(function() HitSFX:Destroy() end)
		end

		CombatReplicator.CameraShake({ magnitude = 65, position = enemyHumRP.Position, radius = 15, duration = 0.5, fadeIn = 0.1, fadeOut = 0.3 })
		CombatReplicator.Highlight(enemyCharacter, { Color = Color3.fromRGB(255, 100, 0), Duration = 0.4 })
		DamageIndicator(enemyCharacter, CONFIG.Damage, Color3.new(1, 0.4, 0))

		StateManager.POST(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		StateManager.POST(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED)

		pullEnemyToFront(enemyCharacter, humRP)
		
		task.delay(CONFIG.PullDuration + 0.05, function()
			StateManager.REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
			StateManager.REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED)
		end)
	end

	local function cleanup()
		if not state.active then return end
		state.active = false
		hitbox:Cleanup()
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	end

	task.spawn(function()
		while state.active do
			local cs = StateManager.GET(char)
			if cs and cs[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED] then
				track:Stop()
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)

	track:GetMarkerReachedSignal("Hit"):Connect(function()
		if not state.active then return end
		hitbox:Once()
	end)

	track.Stopped:Connect(cleanup)
end

return module