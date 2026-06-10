local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local Assets            = ReplicatedStorage.SkillStorage.Shiro
local Fx                = Assets.FX
local Sounds            = Assets.Sounds
local Animations        = Assets.Animations

local DeathConnectionEvent = game.ReplicatedStorage.CombatSystem.Events.DeathConnectionEvent
local SendStreakUpdate = game.ReplicatedStorage.Events:WaitForChild("UpdateStreakInfo")
local CutsceneCameraReplicate = ReplicatedStorage.Events.CutsceneCameraReplicate

local CombatReplicator  = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local Utilities         = require(ReplicatedStorage.Modules.Utilitary.Utils)
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local HitboxModule      = require(ServerStorage.FightModules.HitboxHandler)
local DamageIndicator   = require(ReplicatedStorage.Modules.Shared:WaitForChild("DamageIndicator"))
local knockback         = require(ServerStorage.FightModules.Knockback)
local CombatBlock       = require(game.ReplicatedStorage.CombatSystem.CombatBlock)
local DamageModule = require(game.ReplicatedStorage.CombatSystem.DamageModule)
local UltimateCutsceneUtils = require(ServerStorage.SkillStorage.UltimateCutsceneUtils)

local MatchModule		= require(game.ReplicatedStorage.MatchSystem.MatchModule)
local MatchRemoteEvent  = game.ReplicatedStorage.Events.Match.MatchRemoteEvent

local playerStates = {}

local Damage = 200
local FinalDamage = 334

local function setupPlayerState(player)
	local userId = player.UserId
	if not playerStates[userId] then
		playerStates[userId] = {
			--Example = false,
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

local function weld(part0, part1, c0, parent)
	if not (part0 and part1 and c0 and parent) then return end

	local weld = Instance.new("Weld")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.C0 = c0
	weld.Parent = parent
	return weld
end

local function destroyWeld(weld)
	if weld and weld.Parent then
		weld:Destroy()
	end
end

local function setMassless(model, state)
	for _, part in pairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Massless = state
		end
	end
end

local preloadedTracks = {} -- cache por animator

local function getTrack(animator, anim)
	local id = animator:GetDebugId() .. anim.Name
	if not preloadedTracks[id] then
		preloadedTracks[id] = animator:LoadAnimation(anim)
	end
	return preloadedTracks[id]
end

local function StoppingProcedure(player, enemyPlayer, char, enemyCharacter, hasDied, shouldKillAfter, _diedEvent, returnPosition, enemyReturnPosition, jointWeld, botLock, ServerEvents, humRP, enemyHumRP, humanoid, enemyHumanoid)
	local safeCharCFrame = UltimateCutsceneUtils.GetStoredFightCFrame(char, returnPosition)
	local safeEnemyCFrame = UltimateCutsceneUtils.GetStoredFightCFrame(enemyCharacter, enemyReturnPosition)

	UltimateCutsceneUtils.ResetCharactersToFightPositions(char, enemyCharacter, jointWeld, safeCharCFrame, safeEnemyCFrame)
	if botLock then botLock.Value = true end
	enemyHumRP.AssemblyLinearVelocity = Vector3.zero
	enemyHumRP.AssemblyAngularVelocity = Vector3.zero
	humRP.AssemblyLinearVelocity = Vector3.zero
	humRP.AssemblyAngularVelocity = Vector3.zero

	-- Resto da limpeza...
	ServerEvents:FireClient(player, "EnablePlayerLock")
	if enemyPlayer then
		ServerEvents:FireClient(enemyPlayer, "EnablePlayerLock")
	end
	humanoid.AutoRotate = true
	enemyHumanoid.AutoRotate = true

	task.wait(0.55)

	if not hasDied then
		MatchRemoteEvent:FireClient(player, "FadeOut")
		MatchRemoteEvent:FireClient(player, "FadeOut")
	end

	StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_IFRAME)

	StateManager.REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	StateManager.REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED)
	StateManager.REMOVE(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_IFRAME)

	if _diedEvent then
		_diedEvent:Disconnect()
		_diedEvent = nil
	end

	-- Mata o inimigo aqui, após a cutscene, se algum dano teria matado durante a skill
	if shouldKillAfter and not hasDied then
		DamageModule.TakeDamage(enemyCharacter, 999999, nil, char)
	end
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

	local humanoid = char:FindFirstChild("Humanoid")
	local humRP    = char:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChild("Animator")
	if not (humanoid and humRP and animator) or humanoid.Health <= 0 then return end

	local StartAnim = Animations:FindFirstChild("Ability3Start")
	local StartTrack = animator:LoadAnimation(StartAnim)
	StartTrack:Play()

	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	StartTrack.Stopped:Connect(function()
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	end)

	task.delay(0.14,function()
		--Hitbox Logic
		local hitbox = HitboxModule.new()
		hitbox.Size    = Vector3.new(4.89, 4.96, 4.12)
		hitbox:AttachToCharacter(char)
		hitbox:CreateVisualPart(false)
		hitbox:SetOffset(CFrame.new(0, 0, -2.5))
		hitbox.HitType = "Single"

		hitbox.OnTouch = function(enemyCharacter)
			local enemyHumRP = enemyCharacter:FindFirstChild("HumanoidRootPart")
			local enemyHumanoid = enemyCharacter:FindFirstChild("Humanoid")
			local enemyAnimator = enemyHumanoid and enemyHumanoid.Animator

			if not (enemyHumanoid and enemyHumRP) or enemyHumanoid.Health <= 0 then return end
			local returnPosition = humRP.CFrame
			local enemyReturnPosition = enemyHumRP.CFrame

			local enemyPlayer = Players:GetPlayerFromCharacter(enemyCharacter)

			-- Desabilita PlayerLock dos dois antes do weld
			local ServerEvents = game.ReplicatedStorage.CombatSystem.Events.ServerEvents
			ServerEvents:FireClient(player, "DisablePlayerLock")
			if enemyPlayer then
				ServerEvents:FireClient(enemyPlayer, "DisablePlayerLock")
			end

			-- Ancora o atacante pra não voar com o weld
			humRP.Anchored = true

			local ArenaBounds = MatchModule.GetPlayersArena(player)
			if ArenaBounds then
				char:PivotTo(CFrame.new(ArenaBounds:GetPivot().X, ArenaBounds:GetPivot().Y - 36.5, ArenaBounds:GetPivot().Z) * CFrame.Angles(0, math.rad(90), 0))
			end

			for _, v in pairs(humanoid.Animator:GetPlayingAnimationTracks()) do
				v:Stop()
			end
			for _, v in pairs(enemyHumanoid.Animator:GetPlayingAnimationTracks()) do
				v:Stop()
			end

			StateManager.POST(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED)
			humanoid.AutoRotate = false
			enemyHumanoid.AutoRotate = false

			local Ability3Anim = Animations:FindFirstChild("Ability3")
			local Ability3Track = animator:LoadAnimation(Ability3Anim)
			Ability3Track:Play()

			local Ability3EnemyAnim = Animations:FindFirstChild("Ability3Enemy")
			local Ability3EnemyTrack = enemyAnimator:LoadAnimation(Ability3EnemyAnim)
			Ability3EnemyTrack:Play()

			local sfx = Sounds:FindFirstChild("Ability3Sound"):Clone()
			sfx.Parent = char.Torso
			sfx:Play()
			Debris:AddItem(sfx, sfx.TimeLength)
			
			local ULTIMATE_DURATION = 13
			MatchModule.PauseMatchTimer(player, ULTIMATE_DURATION)

			CutsceneCameraReplicate:FireClient(player, {
				CameraModel     = Fx.CameraRig,           -- Model com HumanoidRootPart + Humanoid + part "Cam"
				Animation       = Animations.CameraAbility3Anim,
				CamPartName     = "camera2",
				WeldToCharacter = true,
				WeldC0 = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
				WeldC1 = CFrame.new(0, 0, 0),
				RestoreInstant  = true,
			})

			-- Opcional: para o inimigo também ver a câmera
			if enemyPlayer then
				CutsceneCameraReplicate:FireClient(enemyPlayer, {
					CameraModel     = Fx.CameraRig,
					Animation       = Animations.CameraAbility3Anim,
					CamPartName     = "camera2",
					WeldToCharacter = true,
					WeldC0 = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
					WeldC1 = CFrame.new(0, 0, 0),
					RestoreInstant  = true,
				})
			end

			StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
			StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
			StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_IFRAME)

			StateManager.POST(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
			StateManager.POST(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
			StateManager.POST(enemyCharacter, StateManagerEnums.STATES_ENUM.COMBAT_IFRAME)

			local botLock = enemyCharacter:FindFirstChild("LockToggle")
			if botLock then botLock.Value = false end

			local jointWeld = weld(humRP, enemyHumRP, CFrame.new(0, 0, 0), humRP)

			Assets.Events.Replicate:FireAllClients("ShiroUltimate", {Char = char, Enemy = enemyCharacter})
			
			local hasDied = false
			local shouldKillAfter = false
			local _diedEvent 
			local hasStopped = false

			local function finishUltimate()
				if hasStopped then
					return
				end

				hasStopped = true
				if Ability3EnemyTrack.IsPlaying then
					Ability3EnemyTrack:Stop(0)
				end
				StoppingProcedure(player, enemyPlayer, char, enemyCharacter, hasDied, shouldKillAfter, _diedEvent, returnPosition, enemyReturnPosition, jointWeld, botLock, ServerEvents, humRP, enemyHumRP, humanoid, enemyHumanoid)
			end

			-- Aplica dano verificando a vida atual; se mataria, marca flag em vez de matar
			local function applyDamageOrMark(amount)
				if hasDied then return end
				if enemyHumanoid.Health - amount <= 0 then
					shouldKillAfter = true
				else
					DamageModule.TakeDamage(enemyCharacter, amount, nil, char)
					DamageIndicator(enemyCharacter, amount, Color3.new(1, 0, 0))
				end
			end

			_diedEvent = DeathConnectionEvent.Event:Connect(function(chr)
				if chr == enemyCharacter then
					hasDied = true
					Ability3Track:Stop()
					Ability3EnemyTrack:Stop()

					-- Para as cutscene cameras antes do stopping procedure
					CutsceneCameraReplicate:FireClient(player, { Restore = true })
					if enemyPlayer then
						CutsceneCameraReplicate:FireClient(enemyPlayer, { Restore = true })
					end

					finishUltimate()
				end
			end)

			task.delay(2.24, function()
				applyDamageOrMark(Damage)
			end)
			task.delay(4.10, function()
				applyDamageOrMark(Damage)
			end)
			task.delay(7.34, function()
				applyDamageOrMark(Damage)
			end)
			task.delay(8.56, function()
				applyDamageOrMark(FinalDamage)
			end)

			task.delay(12.5, function()
				if not hasDied then
					MatchRemoteEvent:FireClient(player, "FadeIn")
					MatchRemoteEvent:FireClient(player, "FadeIn")
				end
			end)

			Ability3Track.Stopped:Connect(function()
				finishUltimate()
			end)
		end

		hitbox:Once()
	end)

end

return module
