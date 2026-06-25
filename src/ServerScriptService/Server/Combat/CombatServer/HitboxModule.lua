-- HitboxModule
-- Responsável por: criação de hitboxes, detecção de hit normal e detecção de grab.

local HitboxModule = {}

-- ── Serviços ─────────────────────────────────────────────────
local RunService = game:GetService("RunService")
local Debris     = game:GetService("Debris")
local Players    = game:GetService("Players")

-- ── Events ───────────────────────────────────────────────────
local ServerEvents     = game.ReplicatedStorage.CombatSystem.Events.ServerEvents
local SendStreakUpdate = game.ReplicatedStorage.Events:WaitForChild("UpdateStreakInfo")

-- ── Módulos ──────────────────────────────────────────────────
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local CombatReplicator  = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local CombatBlock       = require(game.ReplicatedStorage.CombatSystem.CombatBlock)
local DamageModule      = require(game.ReplicatedStorage.CombatSystem.DamageModule)
local CombatKnockback   = require(game.ReplicatedStorage.CombatSystem.CombatKnockback)
local KnockbackProfiles = require(game.ServerStorage.CombatStorage.GlobalStorage.KnockbackProfiles)
local CombatFreeze      = require(game.ReplicatedStorage.CombatSystem.CombatFreeze)
local PlayAnimation     = require(game.ReplicatedStorage.CombatSystem.PlayAnimationServer)
local EffectsHelper     = require(game.ReplicatedStorage.CombatSystem.EffectsHelper)
local CombatUtils       = require(game.ReplicatedStorage.CombatSystem.CombatUtils)
local ProgressModule    = require(script.Parent.ProgressModule)

-- ── Constantes ───────────────────────────────────────────────
local VISIBLE_HITBOXES = false
local GRAB_CATCH_SOUND_DELAY = 0
local GRAB_GROUND_IMPACT_DELAY = 0.05

local GrabCatchSound = Instance.new("Sound")
GrabCatchSound.Name = "GrabCatchSoundTemplate"
GrabCatchSound.SoundId = "rbxassetid://131051744133255"
GrabCatchSound.Volume = 1
GrabCatchSound.PlaybackSpeed = 1

local GrabGroundImpactSound = Instance.new("Sound")
GrabGroundImpactSound.Name = "GrabGroundImpactTemplate"
GrabGroundImpactSound.SoundId = "rbxassetid://118068869072073"
GrabGroundImpactSound.Volume = 1
GrabGroundImpactSound.PlaybackSpeed = 1

-- ── Storage (compartilhado com CombatManager via setter) ──────
local POST_HIT_STORAGE  = nil   -- injetado via Init
local HIT_CONFIRM_STORAGE = nil -- injetado via Init

-- Injeta as tabelas de storage do CombatManager para evitar duplicação
function HitboxModule.Init(postHitStorage, hitConfirmStorage)
	POST_HIT_STORAGE    = postHitStorage
	HIT_CONFIRM_STORAGE = hitConfirmStorage
end

local function PlayDelayedGrabSound(character, soundTemplate, delayTime)
	task.delay(delayTime, function()
		if not (character and character.Parent) then return end

		local impactPart = character:FindFirstChild("Head")
			or character:FindFirstChild("HumanoidRootPart")
			or character:FindFirstChild("Torso")
		if not impactPart then return end

		EffectsHelper.PlaySound({
			Sound = soundTemplate,
			TargetCharacterBodyPart = impactPart.Name,
		}, character)
	end)
end

local function PlayGrabCatchSound(character)
	PlayDelayedGrabSound(character, GrabCatchSound, GRAB_CATCH_SOUND_DELAY)
end

local function PlayGrabGroundImpact(character)
	PlayDelayedGrabSound(character, GrabGroundImpactSound, GRAB_GROUND_IMPACT_DELAY)
end

-- ── Helpers ───────────────────────────────────────────────────
local function OverrideAndPlayKnockback(KnockbackTable, VictimCharacter, AttackerCharacter)
	if not KnockbackTable then return end
	local Profile = table.clone(KnockbackTable.Profile)
	if KnockbackTable.Override then
		for key, value in pairs(KnockbackTable.Override) do
			if Profile[key] then Profile[key] = value end
		end
	end
	CombatKnockback.ApplyKnockback(KnockbackTable, VictimCharacter, KnockbackTable.Delay or 0, AttackerCharacter)
end

HitboxModule.OverrideAndPlayKnockback = OverrideAndPlayKnockback

-- ── Hit normal ────────────────────────────────────────────────

--[[
	HitConfig = {
		HitboxTable     = HitboxTable[comboIndex],
		HitsTable       = HitAnimationTable,        -- [comboIndex] → anim
		HitEffectsTable = HitEffectsTable,           -- [comboIndex] → effect
		HitSoundsTable  = HitSoundsTable,            -- [comboIndex] → sound
		ParryEffects    = { Effect, Sound },
		ComboNumber     = comboIndex,
	}
]]
local function NormalHitDetection(Hitbox, HitConfig, AttackerCharacter)
	local HitboxTable     = HitConfig.HitboxTable
	local HitsTable       = HitConfig.HitsTable
	local HitEffectsTable = HitConfig.HitEffectsTable
	local HitSoundsTable  = HitConfig.HitSoundsTable
	local ParryEffects    = HitConfig.ParryEffects
	local ComboNumber     = HitConfig.ComboNumber

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { AttackerCharacter, workspace.Map:GetChildren() }

	local HitCharacters = {}

	task.spawn(function()
		while Hitbox.Parent do
			local hrp = AttackerCharacter:FindFirstChild("HumanoidRootPart")
			if not hrp then break end

			local worldCFrame = hrp.CFrame * CFrame.new(HitboxTable.RelativeHitboxPos)
			local parts = workspace:GetPartBoundsInBox(worldCFrame, HitboxTable.Hitbox, params)

			for _, part in ipairs(parts) do
				local HitCharacter = part:FindFirstAncestorOfClass("Model")
				if not HitCharacter
					or HitCharacter == AttackerCharacter
					or not HitCharacter:FindFirstChild("Humanoid")
					or HitCharacters[HitCharacter]
				then continue end

				HitCharacters[HitCharacter] = true

				local victimPlayer   = Players:GetPlayerFromCharacter(HitCharacter)
				local attackerPlayer = Players:GetPlayerFromCharacter(AttackerCharacter)

				local hitState = StateManager.GET(HitCharacter)
				if hitState and hitState['COMBAT_IFRAME'] then
					EffectsHelper.PlayEffect(ParryEffects.Effect, HitCharacter)
					EffectsHelper.PlaySound(ParryEffects.Sound, HitCharacter)
					continue
				end

				if victimPlayer and POST_HIT_STORAGE[victimPlayer] then
					OverrideAndPlayKnockback({Profile = KnockbackProfiles.WakeUpBackKnockback}, HitCharacter)
					OverrideAndPlayKnockback({Profile = KnockbackProfiles.WakeUpBackKnockback}, AttackerCharacter)
					EffectsHelper.PlayEffect({
						Type = 'Emit', TargetCharacterBodyPart = 'Torso', Delay = 0,
						Effect = game.ReplicatedStorage.CombatStorage.GlobalVFX.Clash
					}, HitCharacter)
					EffectsHelper.PlaySound({
						Sound = game.ReplicatedStorage.CombatStorage.GlobalSFX.Clash,
						TargetCharacterBodyPart = "Torso"
					}, HitCharacter)
					continue
				end

				if victimPlayer then
					if CombatBlock.CheckAndApplyCombat(victimPlayer, attackerPlayer, HitboxTable.Damage) then continue end
				end

				StateManager.POST_REMOVE(HitCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED, HitboxTable.HitStun)
				PlayAnimation.PlayCharacterAnimation(HitCharacter, HitsTable[ComboNumber], HitboxTable.HitStun)

				if HitEffectsTable[ComboNumber].TargetCharacter == 'Enemy' then
					EffectsHelper.PlayEffect(HitEffectsTable[ComboNumber], HitCharacter)
				end
				if HitEffectsTable[ComboNumber].TargetCharacter == 'Self' then
					EffectsHelper.PlayEffect(HitEffectsTable[ComboNumber], AttackerCharacter)
				end

				EffectsHelper.PlaySound(HitSoundsTable[ComboNumber], HitCharacter)
				CombatFreeze.Freeze(AttackerCharacter, 0.06)
				CombatFreeze.Freeze(HitCharacter, 0.06)

				ServerEvents:FireClient(attackerPlayer, "ApplyCameraZoom", {Zoom = 0.3})
				if victimPlayer then ServerEvents:FireClient(victimPlayer, "ApplyCameraZoom", {Zoom = 0.3}) end

				-- Knockback Enemy
				if HitboxTable.Knockback and HitboxTable.Knockback.Enemy then
					local canPlay = not (HitboxTable.KnockbackOnlyAir and not CombatUtils.IsCharacterInAir(HitCharacter))
					if canPlay then
						if CombatUtils.IsCharacterInAir(HitCharacter) and CombatUtils.IsCharacterInAir(AttackerCharacter) and HitboxTable.Knockback.EnemyAir then
							OverrideAndPlayKnockback(HitboxTable.Knockback.EnemyAir, HitCharacter, AttackerCharacter)
						else
							OverrideAndPlayKnockback(HitboxTable.Knockback.Enemy, HitCharacter, AttackerCharacter)
						end
					end
				end

				-- Knockback Self
				if HitboxTable.Knockback and HitboxTable.Knockback.Self then
					local canPlay = not (HitboxTable.KnockbackOnlyAir and not CombatUtils.IsCharacterInAir(AttackerCharacter))
					if canPlay then
						if CombatUtils.IsCharacterInAir(HitCharacter) and CombatUtils.IsCharacterInAir(AttackerCharacter) and HitboxTable.Knockback.SelfAir then
							if HitboxTable.Knockback.SelfAir.HitOnly then
								OverrideAndPlayKnockback(HitboxTable.Knockback.SelfAir, AttackerCharacter, AttackerCharacter)
							end
						else
							if HitboxTable.Knockback.Self.HitOnly then
								OverrideAndPlayKnockback(HitboxTable.Knockback.Self, AttackerCharacter, AttackerCharacter)
							end
						end
					end
				end

				DamageModule.TakeDamage(HitCharacter, HitboxTable.Damage, nil, AttackerCharacter)

				if attackerPlayer then
					POST_HIT_STORAGE[attackerPlayer] = 0.5
					HIT_CONFIRM_STORAGE[attackerPlayer] = true
				end

				CombatReplicator.CameraShake({
					magnitude = 5, position = HitCharacter.HumanoidRootPart.Position,
					radius = 30, duration = 0.15, fadeIn = 0.01, fadeOut = 0.1,
				})
				CombatReplicator.Highlight(HitCharacter, {Color = Color3.fromRGB(255, 0, 0), Duration = 0.2})

				SendStreakUpdate:Fire(attackerPlayer)
				ProgressModule.IncreaseBurst(attackerPlayer, 10)
				ProgressModule.IncreaseUlt(attackerPlayer, 3)

				Hitbox:Destroy()
			end

			RunService.Heartbeat:Wait()
		end
	end)
end

-- ── Hit grab ─────────────────────────────────────────────────

local function GrabHitDetection(Hitbox, HitboxTable, AttackerCharacter)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { AttackerCharacter, workspace.Map:GetChildren() }

	local function LockCharacter(character)
		local h = character:FindFirstChildOfClass("Humanoid")
		if h then h.WalkSpeed = 0; h.JumpPower = 0; h.AutoRotate = false end
	end
	local function UnlockCharacter(character)
		local h = character:FindFirstChildOfClass("Humanoid")
		if h then h.WalkSpeed = 16; h.JumpPower = 50; h.AutoRotate = true end
	end

	task.spawn(function()
		local Grabbed          = false
		local GrabbedCharacter = nil

		EffectsHelper.PlayEffect(HitboxTable.GrabInfo.Effects.Try, AttackerCharacter)

		while Hitbox.Parent and not Grabbed do
			local attackerHRP = AttackerCharacter:FindFirstChild("HumanoidRootPart")
			if not attackerHRP then break end

			local worldCFrame = attackerHRP.CFrame * CFrame.new(HitboxTable.RelativeHitboxPos)
			local parts = workspace:GetPartBoundsInBox(worldCFrame, HitboxTable.Hitbox, params)

			for _, part in ipairs(parts) do
				local HitCharacter = part:FindFirstAncestorOfClass("Model")
				if not HitCharacter or HitCharacter == AttackerCharacter or not HitCharacter:FindFirstChild("Humanoid") then continue end
				local hitState = StateManager.GET(HitCharacter)
				if hitState and hitState["COMBAT_BEING_ATTACKED"] then continue end
				if hitState and hitState["COMBAT_IFRAME"]         then continue end
				StateManager.POST_REMOVE(HitCharacter, StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED, HitboxTable.HitStun)
				Grabbed = true; GrabbedCharacter = HitCharacter
				break
			end
			RunService.Heartbeat:Wait()
		end

		if not (Grabbed and GrabbedCharacter) then return end

		local player1 = Players:GetPlayerFromCharacter(AttackerCharacter)
		local player2 = Players:GetPlayerFromCharacter(GrabbedCharacter)

		local function FireDisable(p, character)
			if p then ServerEvents:FireClient(p, "DisablePlayerLock")
			else local t = character:FindFirstChild("LockToggle"); if t and t:IsA("BoolValue") then t.Value = false end end
		end
		local function FireEnable(p, character)
			if p then ServerEvents:FireClient(p, "EnablePlayerLock")
			else local t = character:FindFirstChild("LockToggle"); if t and t:IsA("BoolValue") then t.Value = true end end
		end

		FireDisable(player1, AttackerCharacter)
		FireDisable(player2, GrabbedCharacter)
		LockCharacter(AttackerCharacter)
		LockCharacter(GrabbedCharacter)
		StateManager.POST(AttackerCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
		AttackerCharacter.HumanoidRootPart.Anchored = true

		local Weld = Instance.new("Weld")
		Weld.Part0  = AttackerCharacter:FindFirstChild(HitboxTable.GrabInfo.Weld.AttackerBodyPart)
		Weld.Part1  = GrabbedCharacter:FindFirstChild(HitboxTable.GrabInfo.Weld.VictimBodyPart)
		Weld.C0     = HitboxTable.GrabInfo.Weld.C0
		Weld.C1     = HitboxTable.GrabInfo.Weld.C1
		Weld.Parent = Weld.Part0
		Debris:AddItem(Weld, HitboxTable.GrabInfo.Weld.Lifetime)

		PlayAnimation.PlayCharacterAnimation(AttackerCharacter, HitboxTable.GrabInfo.ThrowAnimation)
		PlayAnimation.PlayCharacterAnimation(GrabbedCharacter,  HitboxTable.GrabInfo.VictimGrabbedAnimation)
		EffectsHelper.PlayEffect(HitboxTable.GrabInfo.Effects.Catch, GrabbedCharacter)

		task.delay(HitboxTable.GrabInfo.DamageTime, function()
			DamageModule.TakeDamage(GrabbedCharacter, HitboxTable.Damage, nil, AttackerCharacter)
			PlayGrabCatchSound(GrabbedCharacter)
			PlayGrabGroundImpact(GrabbedCharacter)
			CombatReplicator.CameraShake({
				magnitude = 65, position = GrabbedCharacter.HumanoidRootPart.Position,
				radius = 5, duration = 0.2, fadeIn = 0.1, fadeOut = 0.3,
			})
			CombatReplicator.Highlight(GrabbedCharacter, {Color = Color3.fromRGB(255, 0, 0), Duration = 0.6})
			SendStreakUpdate:Fire(player1)
			ProgressModule.IncreaseBurst(player1, 10)
			ProgressModule.IncreaseUlt(player1, 3)
		end)

		task.delay(HitboxTable.GrabInfo.Weld.Lifetime, function()
			UnlockCharacter(AttackerCharacter)
			UnlockCharacter(GrabbedCharacter)
			StateManager.REMOVE(AttackerCharacter, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
			AttackerCharacter.HumanoidRootPart.Anchored = false
			FireEnable(player1, AttackerCharacter)
			FireEnable(player2, GrabbedCharacter)
			OverrideAndPlayKnockback(HitboxTable.Knockback.Enemy, GrabbedCharacter, AttackerCharacter)
		end)

		Hitbox:Destroy()
	end)
end

-- ── Criação de hitbox ─────────────────────────────────────────

--[[
	HitConfig (para hitbox normal):
	{
		HitboxTable     = HitboxTable[comboIndex],
		HitsTable       = HitAnimationTable,
		HitEffectsTable = HitEffectsTable,
		HitSoundsTable  = HitSoundsTable,
		ParryEffects    = { Effect, Sound },
		ComboNumber     = comboIndex,
	}
	
	Para grab, apenas HitboxTable é necessário (GrabInfo presente).
]]
function HitboxModule.Create(AttackerCharacter, HitConfig)
	local HitboxTable = HitConfig.HitboxTable

	task.delay(HitboxTable.HitboxSpawnTimeOffset, function()
		local Hitbox = Instance.new('Part')
		Hitbox.Size        = HitboxTable.Hitbox
		Hitbox.Anchored    = false
		Hitbox.CanCollide  = false
		Hitbox.Massless    = true
		Hitbox.CanTouch    = false
		Hitbox.CanQuery    = false
		Hitbox.Transparency = VISIBLE_HITBOXES and 0 or 1
		Hitbox.Parent = workspace

		local Weld = Instance.new('Weld')
		Weld.Part0  = AttackerCharacter:WaitForChild('HumanoidRootPart')
		Weld.Part1  = Hitbox
		Weld.C0     = CFrame.new(HitboxTable.RelativeHitboxPos)
		Weld.Parent = Hitbox

		Debris:AddItem(Hitbox, HitboxTable.HitboxLifetime)

		if HitboxTable.GrabInfo then
			GrabHitDetection(Hitbox, HitboxTable, AttackerCharacter)
		else
			NormalHitDetection(Hitbox, HitConfig, AttackerCharacter)
		end
	end)
end

return HitboxModule
