-- CombatManager (Módulo Principal)
-- Responsável por: receber input, armazenar estado global dos players,
-- coordenar os sub-módulos e rodar o heartbeat geral.

local CombatManager = {}

-- ══════════════════════════════════════════════════════════════
-- SERVIÇOS & EVENTOS
-- ══════════════════════════════════════════════════════════════

local RunService   = game:GetService("RunService")
local Players      = game:GetService("Players")

local RegisterInput            = game.ReplicatedStorage.CombatSystem.Events.SendInput
local ClientRequests           = game.ReplicatedStorage.CombatSystem.Events.ClientRequests
local ServerRequests           = game.ReplicatedStorage.CombatSystem.Events.ServerRequests
local ServerEvents             = game.ReplicatedStorage.CombatSystem.Events.ServerEvents
local DeathConnectionEvent     = game.ReplicatedStorage.CombatSystem.Events.DeathConnectionEvent
local MatchUIInteractions      = game.ReplicatedStorage.Events.Match.MatchUIInteractions
local MatchUsedUltEvent        = game.ReplicatedStorage.Events.Match.MatchUsedUltimate
local IncreaseUltProgressEvent = game.ReplicatedStorage.Events.IcreaseUltProgress

-- ══════════════════════════════════════════════════════════════
-- MÓDULOS
-- ══════════════════════════════════════════════════════════════

local CharacterManager  = require(game.ReplicatedStorage.CombatSystem.CharacterManager)
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local CombatBlock       = require(game.ReplicatedStorage.CombatSystem.CombatBlock)
local CombatUtils       = require(game.ReplicatedStorage.CombatSystem.CombatUtils)
local EffectsHelper     = require(game.ReplicatedStorage.CombatSystem.EffectsHelper)
local PlayAnimation     = require(game.ReplicatedStorage.CombatSystem.PlayAnimationServer)
local CombatReplicator  = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local SkillModule       = require(game.ServerStorage.SkillSystem.SkillModule)

-- Sub-módulos de combate
local StaminaModule   = require(script.StaminaModule)
local ChargeModule    = require(script.ChargeModule)
local ProgressModule  = require(script.ProgressModule)
local HitboxModule    = require(script.HitboxModule)
local AttackModule    = require(script.AttackModule)

-- ══════════════════════════════════════════════════════════════
-- CONSTANTES
-- ══════════════════════════════════════════════════════════════

local INPUT_QUEUE_RUNOUT_TIME         = 0.4
local DOUBLE_INPUT_DASH_WINDOW        = 0.3
local PAST_CHARGE_KOYOTE_TIME         = 0.2
local COMBO_SEQUENCE_DEFAULT_COOLDOWN = 2
local GRAB_COOLDOWN_TIME              = 1.5
local CHARGE_GLOBAL_COOLDOWN_TIME     = 1.5
local BLOCK_COOLDOWN                  = 1.5

local DoubleJumpEffect = {
	Type = 'Emit',
	TargetCharacterBodyPart = 'Left Leg',
	Effect = game.ReplicatedStorage.CombatStorage.GlobalVFX.Land,
}

-- ══════════════════════════════════════════════════════════════
-- ESTADO GLOBAL (compartilhado entre módulos via referência)
-- ══════════════════════════════════════════════════════════════

local InputQueue                     = {}
local INPUT_QUEUE_TIMERS             = {}
local COMPOUND_INPUT_TRIGGER_STORAGE = {}

local COMBO_TIMERS                   = {}
local COMBO_SEQUENCE_COOLDOWN_STORAGE = {}
local HIT_CONFIRM_STORAGE            = {}
local PENDING_ATK_STORAGE            = {}

local DOUBLE_INPUT_DASH_TIMER        = {}
local CAN_DOUBLE_JUMP_STORAGE        = {}
local CAN_JUMP_ATTACK_STORAGE        = {}

local SKILL_COOLDOWN_STORAGE         = {}
local GRAB_COOLDOWN_STORAGE          = {}
local BLOCKING_STORAGE               = {}
local POST_HIT_STORAGE               = {}

-- ══════════════════════════════════════════════════════════════
-- INICIALIZAÇÃO DOS SUB-MÓDULOS
-- ══════════════════════════════════════════════════════════════

HitboxModule.Init(POST_HIT_STORAGE, HIT_CONFIRM_STORAGE)
AttackModule.Init(COMBO_TIMERS, HIT_CONFIRM_STORAGE, PENDING_ATK_STORAGE, COMBO_SEQUENCE_COOLDOWN_STORAGE)

-- Getter de CharacterStorageModule (usado pelos ticks dos sub-módulos)
local function GetCSM(player)
	return CharacterManager.GetModule(player)
end

-- ── Eventos externos ──────────────────────────────────────────
IncreaseUltProgressEvent.Event:Connect(function(player, amount)
	ProgressModule.IncreaseUlt(player, amount)
end)

-- ══════════════════════════════════════════════════════════════
-- DEBUG (comentar em produção)
-- ══════════════════════════════════════════════════════════════

local DEBUG_ULT_ALWAYS_FULL = true

if DEBUG_ULT_ALWAYS_FULL then
	RunService.Heartbeat:Connect(function()
		for _, player in ipairs(Players:GetPlayers()) do
			if ProgressModule.GetUlt(player) < 100 then
				ProgressModule.IncreaseUlt(player, 100)
			end
		end
	end)
end

-- ══════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════
-- HELPERS LOCAIS
-- ══════════════════════════════════════════════════════════════

local function FindComboInQueue(player, comboSequence)
	local queue = InputQueue[player]
	if not queue or #queue < #comboSequence then return false end
	local comboLen = #comboSequence
	for startIndex = 1, #queue - comboLen + 1 do
		local matched = true
		for i = 1, comboLen do
			if queue[startIndex + i - 1] ~= comboSequence[i] then matched = false; break end
		end
		if matched then return true end
	end
	return false
end

-- Constrói o AttackConfig comprimido a partir do CharacterStorageModule
-- para ataques de sequência (Basic).
local function BuildBasicCfg(csm, sequenceLogic, animSeq, hitAnims, fxSeq, hitFx, sfxSeq, hitSfx, comboType)
	return {
		HitboxTable  = sequenceLogic,
		AttackAnims  = animSeq,
		HitAnims     = hitAnims,
		Effects      = fxSeq,
		HitEffects   = hitFx,
		Sounds       = sfxSeq,
		HitSounds    = hitSfx,
		ParryEffects = { Effect = csm.Visuals.Effects.Hits.PARRY, Sound = csm.Visuals.Sounds.Hits.PARRY },
		ComboType    = comboType,
	}
end

-- Constrói o AttackConfig comprimido para ataques não-combo (NonCombo).
local function BuildNonComboCfg(csm, hitboxLogic, attackAnim, hitAnim, fx, hitFx, sfx, hitSfx, comboName)
	return {
		HitboxTable  = hitboxLogic,
		AttackAnims  = attackAnim,
		HitAnims     = hitAnim,
		Effects      = fx,
		HitEffects   = hitFx,
		Sounds       = sfx,
		HitSounds    = hitSfx,
		ParryEffects = { Effect = csm.Visuals.Effects.Hits.PARRY, Sound = csm.Visuals.Sounds.Hits.PARRY },
		ComboName    = comboName,
	}
end

-- ══════════════════════════════════════════════════════════════
-- CLIENT / SERVER REQUESTS
-- ══════════════════════════════════════════════════════════════

ClientRequests.OnServerInvoke = function(player, request)
	if request == 'GetInputQueue' then
		return InputQueue[player] or nil
	end
	if request == 'GetCharacterStorageVisuals' then
		local m = CharacterManager.GetModule(player)
		return m and m.Visuals or nil
	end
end

ServerRequests.OnInvoke = function(action, args)
	local player = args and args.Player

	if action == 'RequestCanBlock' then
		if not player then return false end
		if BLOCKING_STORAGE[player] and BLOCKING_STORAGE[player].Cooldown then return false end
		local ps = StateManager.GET(player)
		if ps[StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED]  then return false end
		if ps[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED] then return false end
		if ps[StateManagerEnums.STATES_ENUM.COMBAT_DOING_COMBAT]   then return false end
		if ps[StateManagerEnums.STATES_ENUM.COMBAT_BLOCKING]       then return false end
		return true

	elseif action == 'RequestCanBlockHit' then
		if BLOCKING_STORAGE[player] and BLOCKING_STORAGE[player].Cooldown then return false end
		local ps = StateManager.GET(player)
		if ps[StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED]  then return false end
		if ps[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED] then return false end
		if ps[StateManagerEnums.STATES_ENUM.COMBAT_DOING_COMBAT]   then return false end
		if not ps[StateManagerEnums.STATES_ENUM.COMBAT_BLOCKING]   then return false end
		return true

	elseif action == 'SetBlockHolding' then
		if not player then return end
		StateManager.POST(player, StateManagerEnums.STATES_ENUM.COMBAT_BLOCKING)

	elseif action == 'SetParryTimer' then
		if not player then return end
		if not BLOCKING_STORAGE[player] then BLOCKING_STORAGE[player] = {} end
		BLOCKING_STORAGE[player].ParryTimer = args.Timer
		CombatReplicator.Highlight(player.Character, {Color = Color3.fromRGB(0, 255, 0), Duration = args.Timer})

	elseif action == 'RegisterBlockHoldingAnimation' then
		if not player then return end
		if not BLOCKING_STORAGE[player] then BLOCKING_STORAGE[player] = {} end
		BLOCKING_STORAGE[player].HoldingAnimation = args.Animation

	elseif action == 'RequestIsBlocking' then
		if not player then return false end
		if StateManager.GET(player)[StateManagerEnums.STATES_ENUM.COMBAT_BLOCKING] then return true end

	elseif action == 'RemoveBlockHolding' then
		if not player then return end
		while StateManager.GET(player)[StateManagerEnums.STATES_ENUM.COMBAT_BLOCKING] do
			StateManager.REMOVE(player, StateManagerEnums.STATES_ENUM.COMBAT_BLOCKING)
		end

	elseif action == 'RemoveParryTimer' then
		if not player then return end
		if BLOCKING_STORAGE[player] then BLOCKING_STORAGE[player].ParryTimer = nil end

	elseif action == 'GetBlockHoldingAnimation' then
		if not player then return nil end
		return BLOCKING_STORAGE[player] and BLOCKING_STORAGE[player].HoldingAnimation or nil

	elseif action == 'RemoveBlockHoldingAnimation' then
		if not player then return end
		if BLOCKING_STORAGE[player] then BLOCKING_STORAGE[player].HoldingAnimation = nil end

	elseif action == 'AddBlockCooldown' then
		if not player then return end
		if not BLOCKING_STORAGE[player] then BLOCKING_STORAGE[player] = {} end
		BLOCKING_STORAGE[player].Cooldown = BLOCK_COOLDOWN

	elseif action == 'RequestCanParry' then
		if not player then return false end
		local s = BLOCKING_STORAGE[player]
		return s ~= nil and s.ParryTimer ~= nil and s.ParryTimer > 0

	elseif action == 'RequestWillBlockBreak' then
		if not player then return false end
		local s = BLOCKING_STORAGE[player]
		if not s or not s.Charges then return false end
		for i = 1, 3 do if s.Charges[i] == nil then return false end end
		return true

	elseif action == 'RegisterBlockHit' then
		if not player then return end
		if not BLOCKING_STORAGE[player] then BLOCKING_STORAGE[player] = {} end
		if not BLOCKING_STORAGE[player].Charges then BLOCKING_STORAGE[player].Charges = { nil, nil, nil } end
		for i = 1, 3 do
			if BLOCKING_STORAGE[player].Charges[i] == nil then
				BLOCKING_STORAGE[player].Charges[i] = 1.5
				break
			end
		end
	end
end

-- ══════════════════════════════════════════════════════════════
-- INPUT HANDLER
-- ══════════════════════════════════════════════════════════════

RegisterInput.OnServerEvent:Connect(function(player, input, state)
	local csm = CharacterManager.GetModule(player)
	if not csm then return end

	-- ── Charge input detection (antes dos state guards) ─────────
	if state == 'Began' and input == 'CHARGEATK' then
		if not ChargeModule.HasGlobalCooldown(player) then
			if not ProgressModule.IsBurstInputActive(player) then
				ProgressModule.StartBurstInputTimer(player)
			end
		end
	end

	-- ── Burst (LIGHTATK / HARDATK / GRAB com barra cheia) ───────
	if state == 'Began' then
		local isBurstInput = input == 'LIGHTATK' or input == 'HARDATK' or input == 'GRAB'
		if isBurstInput
			and ProgressModule.IsBurstInputActive(player)
			and ProgressModule.GetBurst(player) == 100
		then
			ProgressModule.ConsumeBurst(player)
			ProgressModule.ClearBurstInputTimer(player)
			ChargeModule.Cancel(player)

			AttackModule.ExecuteNonCombo(player, BuildNonComboCfg(csm,
				csm.Logic.CompoundInputs.BURST,
				csm.Visuals.Animations.CompoundInputs.BURST,
				csm.Visuals.Animations.Hits.BURST,
				csm.Visuals.Effects.BURST,
				csm.Visuals.Effects.Hits.BURST,
				csm.Visuals.Sounds.CompoundInputs.BURST,
				csm.Visuals.Sounds.Hits.BURST,
				'Burst'
				))
			return
		end
	end

	-- ── Block Ended ──────────────────────────────────────────────
	if state == 'Ended' and input == 'BLOCK' then
		if BLOCKING_STORAGE[player] and BLOCKING_STORAGE[player].HoldingAnimation == nil then return end
		CombatBlock.DisableBlock(player)
		return
	end

	-- ── Crouch Ended ─────────────────────────────────────────────
	if state == 'Ended' and input == 'CROUCH' then
		COMPOUND_INPUT_TRIGGER_STORAGE[player]['CROUCH'] = false
		StateManager.REMOVE(player, StateManagerEnums.STATES_ENUM.COMBAT_CROUCHING)
	end

	-- ── State guard ──────────────────────────────────────────────
	local playerState = StateManager.GET(player)
	if playerState[StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED]
		or playerState[StateManagerEnums.STATES_ENUM.COMBAT_INSKILL]
		or playerState[StateManagerEnums.STATES_ENUM.COMBAT_COUNTDOWN_STUNNED]
		or playerState[StateManagerEnums.STATES_ENUM.COMBAT_BLOCKING]
		or playerState[StateManagerEnums.STATES_ENUM.COMBAT_FROZEN_STUNNED]
	then return end

	-- ══════════════════════════════════════════════════════════════
	-- BEGAN
	-- ══════════════════════════════════════════════════════════════
	if state == 'Began' then
		InputQueue[player] = InputQueue[player] or {}
		if not COMPOUND_INPUT_TRIGGER_STORAGE[player] then COMPOUND_INPUT_TRIGGER_STORAGE[player] = {} end
		table.insert(InputQueue[player], input)
		INPUT_QUEUE_TIMERS[player] = INPUT_QUEUE_RUNOUT_TIME

		-- ── Combos de sequência de teclas ────────────────────────
		for ComboName, Content in pairs(csm.Logic.Combos) do
			if not FindComboInQueue(player, Content.Combo) then continue end
			if not COMBO_SEQUENCE_COOLDOWN_STORAGE[player] then COMBO_SEQUENCE_COOLDOWN_STORAGE[player] = {} end
			if COMBO_SEQUENCE_COOLDOWN_STORAGE[player][ComboName] then continue end

			if Content.ComboType == 'CombatAttack' then
				local cooldown = (Content.ComboAttack and Content.ComboAttack.Cooldown) or COMBO_SEQUENCE_DEFAULT_COOLDOWN
				COMBO_SEQUENCE_COOLDOWN_STORAGE[player][ComboName] = cooldown
				AttackModule.ExecuteNonCombo(player, BuildNonComboCfg(csm,
					Content.ComboAttack,
					csm.Visuals.Animations.Combos[ComboName],
					csm.Visuals.Animations.Hits.Combos[ComboName],
					csm.Visuals.Effects.Combos[ComboName],
					csm.Visuals.Effects.Hits.Combos[ComboName],
					csm.Visuals.Sounds.Combos[ComboName],
					csm.Visuals.Sounds.Hits.Combos[ComboName],
					ComboName
					))
			elseif Content.ComboType == 'Skill' then
				local cooldown = Content.Cooldown or COMBO_SEQUENCE_DEFAULT_COOLDOWN
				COMBO_SEQUENCE_COOLDOWN_STORAGE[player][ComboName] = cooldown
				SkillModule.UseSkill(Content.ModuleLocation, player.Character)
			end
			return
		end

		-- ── DASH ─────────────────────────────────────────────────
		if input == 'RIGHT' or input == 'LEFT' then
			local dir = input
			if DOUBLE_INPUT_DASH_TIMER[player] and DOUBLE_INPUT_DASH_TIMER[player][dir] then
				if not StaminaModule.Has(player, StaminaModule.Costs.DASH) then
					ServerEvents:FireClient(player, "StaminaInsufficient")
				else
					StaminaModule.Spend(player, StaminaModule.Costs.DASH)
					ServerEvents:FireClient(player, 'ExecuteDash', dir)
					EffectsHelper.PlaySound({Sound = game.ReplicatedStorage.CombatStorage.GlobalSFX.Dash, TargetCharacterBodyPart = "Torso"}, player.Character)
				end
			else
				if not DOUBLE_INPUT_DASH_TIMER[player] then DOUBLE_INPUT_DASH_TIMER[player] = {} end
				DOUBLE_INPUT_DASH_TIMER[player][dir] = { Timer = DOUBLE_INPUT_DASH_WINDOW }
			end
		end

		-- ── JUMP / DOUBLE JUMP ───────────────────────────────────
		if input == 'JUMP' then
			if not CAN_JUMP_ATTACK_STORAGE[player] then CAN_JUMP_ATTACK_STORAGE[player] = {} end
			CAN_JUMP_ATTACK_STORAGE[player].State = true
			CAN_JUMP_ATTACK_STORAGE[player].Timer = 0.3
			EffectsHelper.PlaySound({Sound = game.ReplicatedStorage.CombatStorage.GlobalSFX.Jump, TargetCharacterBodyPart = "Torso"}, player.Character)

			if CombatUtils.IsCharacterInAir(player.Character) then
				if CAN_DOUBLE_JUMP_STORAGE[player] == nil then CAN_DOUBLE_JUMP_STORAGE[player] = true end
				if CAN_DOUBLE_JUMP_STORAGE[player] == false then return end
				CAN_DOUBLE_JUMP_STORAGE[player] = false
				EffectsHelper.PlayEffect(DoubleJumpEffect, player.Character)
				PlayAnimation.PlayCharacterAnimation(player.Character, csm.Visuals.Animations.BasicInputs.DOUBLE_JUMP)
				HitboxModule.OverrideAndPlayKnockback(csm.Logic.BasicInputs.DOUBLE_JUMP.Knockback.Self, player.Character, player.Character)
			end
		end

		-- ── CROUCH ───────────────────────────────────────────────
		if input == 'CROUCH' then
			COMPOUND_INPUT_TRIGGER_STORAGE[player]['CROUCH'] = true
			StateManager.POST(player, StateManagerEnums.STATES_ENUM.COMBAT_CROUCHING)
		end

		-- ── BLOCK ────────────────────────────────────────────────
		if input == 'BLOCK' then
			CombatBlock.EnableBlock(player)
		end

		-- ── GRAB ─────────────────────────────────────────────────
		if input == 'GRAB' then
			ChargeModule.Cancel(player)
			if not GRAB_COOLDOWN_STORAGE[player] then GRAB_COOLDOWN_STORAGE[player] = {} end
			if GRAB_COOLDOWN_STORAGE[player].Timer then return end
			GRAB_COOLDOWN_STORAGE[player].Timer = GRAB_COOLDOWN_TIME
			AttackModule.ExecuteNonCombo(player, BuildNonComboCfg(csm,
				csm.Logic.BasicInputs.GRAB,
				csm.Visuals.Animations.BasicInputs.GRAB,
				nil, nil, nil, nil, nil, 'Grab'
				))
		end

		-- ── CHARGE ATK ───────────────────────────────────────────
		if input == 'CHARGEATK' then
			if ChargeModule.IsCharging(player) then return end
			if ChargeModule.HasGlobalCooldown(player) then return end
			ChargeModule.StartCharge(player)
			PlayAnimation.PlayCharacterAnimation(player.Character, csm.Visuals.Animations.BasicInputs.CHARGEATK.Charge)
			EffectsHelper.PlayEffect(csm.Visuals.Effects.BasicInputs.CHARGEATK.Charge, player.Character)
			EffectsHelper.PlaySound(csm.Visuals.Sounds.BasicInputs.CHARGEATK.Charge, player.Character)
		end

		-- ── LIGHT ATK ────────────────────────────────────────────
		if input == 'LIGHTATK' then
			ChargeModule.Cancel(player)

			-- Air
			if CombatUtils.IsCharacterInAir(player.Character) and CAN_JUMP_ATTACK_STORAGE[player] and CAN_JUMP_ATTACK_STORAGE[player].State == true then
				if not StaminaModule.Has(player, StaminaModule.Costs.AIR_ATK) then
					ServerEvents:FireClient(player, "StaminaInsufficient"); return
				end
				StaminaModule.Spend(player, StaminaModule.Costs.AIR_ATK)
				AttackModule.ExecuteNonCombo(player, BuildNonComboCfg(csm,
					csm.Logic.CompoundInputs.AIRLIGHTATK,
					csm.Visuals.Animations.CompoundInputs.AIRLIGHTATK,
					csm.Visuals.Animations.Hits.AIRLIGHTATK,
					csm.Visuals.Effects.CompoundInputs.AIRLIGHTATK,
					csm.Visuals.Effects.Hits.AIRLIGHTATK,
					csm.Visuals.Sounds.CompoundInputs.AIRLIGHTATK,
					csm.Visuals.Sounds.Hits.AIRLIGHTATK,
					'AirAttack'
					))
				return
			end

			-- Crouch
			if COMPOUND_INPUT_TRIGGER_STORAGE[player]['CROUCH'] then
				AttackModule.ExecuteNonCombo(player, BuildNonComboCfg(csm,
					csm.Logic.CompoundInputs.CROUCHLIGHTATK,
					csm.Visuals.Animations.CompoundInputs.CROUCHLIGHTATK,
					csm.Visuals.Animations.Hits.CROUCHLIGHTATK,
					csm.Visuals.Effects.CompoundInputs.CROUCHLIGHTATK,
					csm.Visuals.Effects.Hits.CROUCHLIGHTATK,
					csm.Visuals.Sounds.CompoundInputs.CROUCHLIGHTATK,
					csm.Visuals.Sounds.Hits.CROUCHLIGHTATK,
					'Poke'
					))
				return
			end

			local noStamina = not StaminaModule.Has(player, StaminaModule.Costs.LIGHT_ATK)
			StaminaModule.Spend(player, StaminaModule.Costs.LIGHT_ATK)
			AttackModule.ExecuteBasic(player, BuildBasicCfg(csm,
				csm.Logic.Sequences.LightAtks,
				csm.Visuals.Animations.Sequences.LightAtks,
				csm.Visuals.Animations.Hits.LightAtks,
				csm.Visuals.Effects.Sequences.LightAtks,
				csm.Visuals.Effects.Hits.LightAtks,
				csm.Visuals.Sounds.Sequences.LightAtks,
				csm.Visuals.Sounds.Hits.LightAtks,
				'Light'
				), noStamina)
		end

		-- ── HARD ATK ─────────────────────────────────────────────
		if input == 'HARDATK' then
			ChargeModule.Cancel(player)

			-- Air
			if CombatUtils.IsCharacterInAir(player.Character) and CAN_JUMP_ATTACK_STORAGE[player] and CAN_JUMP_ATTACK_STORAGE[player].State == true then
				if not StaminaModule.Has(player, StaminaModule.Costs.AIR_ATK) then
					ServerEvents:FireClient(player, "StaminaInsufficient"); return
				end
				StaminaModule.Spend(player, StaminaModule.Costs.AIR_ATK)
				AttackModule.ExecuteNonCombo(player, BuildNonComboCfg(csm,
					csm.Logic.CompoundInputs.AIRHARDATK,
					csm.Visuals.Animations.CompoundInputs.AIRHARDATK,
					csm.Visuals.Animations.Hits.AIRHARDATK,
					csm.Visuals.Effects.CompoundInputs.AIRHARDATK,
					csm.Visuals.Effects.Hits.AIRHARDATK,
					csm.Visuals.Sounds.CompoundInputs.AIRHARDATK,
					csm.Visuals.Sounds.Hits.AIRHARDATK,
					'AirHardAttack'
					))
				return
			end

			-- Crouch
			if COMPOUND_INPUT_TRIGGER_STORAGE[player]['CROUCH'] then
				if not StaminaModule.Has(player, StaminaModule.Costs.HARD_ATK) then
					ServerEvents:FireClient(player, "StaminaInsufficient"); return
				end
				StaminaModule.Spend(player, StaminaModule.Costs.HARD_ATK)
				AttackModule.ExecuteBasic(player, BuildBasicCfg(csm,
					csm.Logic.Sequences.HardAtks.Crouching,
					csm.Visuals.Animations.Sequences.HardAtks.Crouching,
					csm.Visuals.Animations.Hits.HardAtks.Crouching,
					csm.Visuals.Effects.Sequences.HardAtks.Crouching,
					csm.Visuals.Effects.Hits.HardAtks.Crouching,
					csm.Visuals.Sounds.Sequences.HardAtks.Crouching,
					csm.Visuals.Sounds.Hits.HardAtks.Crouching,
					'Hard'
					))
				return
			end

			local noStamina = not StaminaModule.Has(player, StaminaModule.Costs.LIGHT_ATK)
			StaminaModule.Spend(player, StaminaModule.Costs.HARD_ATK)
			AttackModule.ExecuteBasic(player, BuildBasicCfg(csm,
				csm.Logic.Sequences.HardAtks.Standing,
				csm.Visuals.Animations.Sequences.HardAtks.Standing,
				csm.Visuals.Animations.Hits.HardAtks.Standing,
				csm.Visuals.Effects.Sequences.HardAtks.Standing,
				csm.Visuals.Effects.Hits.HardAtks.Standing,
				csm.Visuals.Sounds.Sequences.HardAtks.Standing,
				csm.Visuals.Sounds.Hits.HardAtks.Standing,
				'Hard'
				), noStamina)
		end

		-- ── ULTIMATE ─────────────────────────────────────────────
		if input == 'ULTIMATE' then
			if ProgressModule.GetUlt(player) >= 100 then
				ProgressModule.ConsumeUlt(player)
				SkillModule.UseSkill(csm.Logic.Skills.Ultimate.ModuleLocation, player.Character)
				MatchUsedUltEvent:Fire(player)
			end
		end

		-- ── SKILL 1 ──────────────────────────────────────────────
		if input == 'SKILL1' and csm.Logic.Skills.Skill1.InputType == 'Began' then
			if not SKILL_COOLDOWN_STORAGE[player] then SKILL_COOLDOWN_STORAGE[player] = {} end
			if SKILL_COOLDOWN_STORAGE[player]['Skill1'] then return end
			if not StaminaModule.Has(player, StaminaModule.Costs.SKILL) then
				ServerEvents:FireClient(player, "StaminaInsufficient"); return
			end
			if StateManager.GET(player)[StateManagerEnums.STATES_ENUM.COMBAT_CROUCHING] then
				StateManager.REMOVE(player, StateManagerEnums.STATES_ENUM.COMBAT_CROUCHING)
				ServerEvents:FireClient(player, 'DisableCrouchAnimation')
			end
			StaminaModule.Spend(player, StaminaModule.Costs.SKILL)
			SKILL_COOLDOWN_STORAGE[player]['Skill1'] = csm.Logic.Skills.Skill1.Cooldown or 5
			MatchUIInteractions:FireClient(player, 'SkillCooldown', 'Skill1', SKILL_COOLDOWN_STORAGE[player]['Skill1'])
			SkillModule.UseSkill(csm.Logic.Skills.Skill1.ModuleLocation, player.Character)
		end

		-- ── SKILL 2 ──────────────────────────────────────────────
		if input == 'SKILL2' and csm.Logic.Skills.Skill2.InputType == 'Began' then
			if not SKILL_COOLDOWN_STORAGE[player] then SKILL_COOLDOWN_STORAGE[player] = {} end
			if SKILL_COOLDOWN_STORAGE[player]['Skill2'] then return end
			if not StaminaModule.Has(player, StaminaModule.Costs.SKILL) then
				ServerEvents:FireClient(player, "StaminaInsufficient"); return
			end
			if StateManager.GET(player)[StateManagerEnums.STATES_ENUM.COMBAT_CROUCHING] then
				StateManager.REMOVE(player, StateManagerEnums.STATES_ENUM.COMBAT_CROUCHING)
				ServerEvents:FireClient(player, 'DisableCrouchAnimation')
			end
			StaminaModule.Spend(player, StaminaModule.Costs.SKILL)
			SKILL_COOLDOWN_STORAGE[player]['Skill2'] = csm.Logic.Skills.Skill2.Cooldown or 5
			MatchUIInteractions:FireClient(player, 'SkillCooldown', 'Skill2', SKILL_COOLDOWN_STORAGE[player]['Skill2'])
			SkillModule.UseSkill(csm.Logic.Skills.Skill2.ModuleLocation, player.Character)
		end
	end

	-- ══════════════════════════════════════════════════════════════
	-- ENDED
	-- ══════════════════════════════════════════════════════════════
	if state == 'Ended' then
		if not COMPOUND_INPUT_TRIGGER_STORAGE[player] then COMPOUND_INPUT_TRIGGER_STORAGE[player] = {} end

		if input == 'CROUCH' then
			COMPOUND_INPUT_TRIGGER_STORAGE[player]['CROUCH'] = false
			StateManager.REMOVE(player, StateManagerEnums.STATES_ENUM.COMBAT_CROUCHING)
		end

		if input == 'BLOCK' then
			CombatBlock.DisableBlock(player)
		end

		-- ── CHARGE release ───────────────────────────────────────
		if input == 'CHARGEATK' then
			ProgressModule.ClearBurstInputTimer(player)
			if not ChargeModule.IsCharging(player) then return end

			local timer = ChargeModule.EndCharge(player, CHARGE_GLOBAL_COOLDOWN_TIME)
			local HitboxTableCopy = table.clone(csm.Logic.BasicInputs.CHARGEATK)
			HitboxTableCopy.Damage = math.map(timer, 0, HitboxTableCopy.ChargeTime, HitboxTableCopy.MinDamage, HitboxTableCopy.MaxDamage)

			if not StaminaModule.Has(player, StaminaModule.Costs.CHARGE_ATK) then
				ServerEvents:FireClient(player, "StaminaInsufficient")
				return
			end
			StaminaModule.Spend(player, StaminaModule.Costs.CHARGE_ATK)

			AttackModule.ExecuteNonCombo(player, BuildNonComboCfg(csm,
				HitboxTableCopy,
				csm.Visuals.Animations.BasicInputs.CHARGEATK.Release,
				csm.Visuals.Animations.Hits.CHARGEATK,
				csm.Visuals.Effects.BasicInputs.CHARGEATK.Release,
				csm.Visuals.Effects.Hits.CHARGEATK,
				csm.Visuals.Sounds.BasicInputs.CHARGEATK.Release,
				csm.Visuals.Sounds.Hits.CHARGEATK,
				'ChargeAttack'
				))
		end

		-- ── SKILL 1 Ended ────────────────────────────────────────
		if input == 'SKILL1' and csm.Logic.Skills.Skill1.InputType == 'Ended' then
			if not SKILL_COOLDOWN_STORAGE[player] then SKILL_COOLDOWN_STORAGE[player] = {} end
			if SKILL_COOLDOWN_STORAGE[player]['Skill1'] then return end
			if not StaminaModule.Has(player, StaminaModule.Costs.SKILL) then
				ServerEvents:FireClient(player, "StaminaInsufficient"); return
			end
			if StateManager.GET(player)[StateManagerEnums.STATES_ENUM.COMBAT_CROUCHING] then
				StateManager.REMOVE(player, StateManagerEnums.STATES_ENUM.COMBAT_CROUCHING)
				ServerEvents:FireClient(player, 'DisableCrouchAnimation')
			end
			StaminaModule.Spend(player, StaminaModule.Costs.SKILL)
			SKILL_COOLDOWN_STORAGE[player]['Skill1'] = csm.Logic.Skills.Skill1.Cooldown or 5
			MatchUIInteractions:FireClient(player, 'SkillCooldown', 'Skill1', SKILL_COOLDOWN_STORAGE[player]['Skill1'])
			SkillModule.UseSkill(csm.Logic.Skills.Skill1.ModuleLocation, player.Character)
		end

		-- ── SKILL 2 Ended ────────────────────────────────────────
		if input == 'SKILL2' and csm.Logic.Skills.Skill2.InputType == 'Ended' then
			if not SKILL_COOLDOWN_STORAGE[player] then SKILL_COOLDOWN_STORAGE[player] = {} end
			if SKILL_COOLDOWN_STORAGE[player]['Skill2'] then return end
			if not StaminaModule.Has(player, StaminaModule.Costs.SKILL) then
				ServerEvents:FireClient(player, "StaminaInsufficient"); return
			end
			if StateManager.GET(player)[StateManagerEnums.STATES_ENUM.COMBAT_CROUCHING] then
				StateManager.REMOVE(player, StateManagerEnums.STATES_ENUM.COMBAT_CROUCHING)
				ServerEvents:FireClient(player, 'DisableCrouchAnimation')
			end
			StaminaModule.Spend(player, StaminaModule.Costs.SKILL)
			SKILL_COOLDOWN_STORAGE[player]['Skill2'] = csm.Logic.Skills.Skill2.Cooldown or 5
			MatchUIInteractions:FireClient(player, 'SkillCooldown', 'Skill2', SKILL_COOLDOWN_STORAGE[player]['Skill2'])
			SkillModule.UseSkill(csm.Logic.Skills.Skill2.ModuleLocation, player.Character)
		end
	end
end)

-- ══════════════════════════════════════════════════════════════
-- HEARTBEAT (timers locais + tick dos sub-módulos)
-- ══════════════════════════════════════════════════════════════

RunService.Heartbeat:Connect(function(dt)
	-- Input queue
	for player in pairs(INPUT_QUEUE_TIMERS) do
		INPUT_QUEUE_TIMERS[player] -= dt
		if INPUT_QUEUE_TIMERS[player] <= 0 then
			InputQueue[player]        = nil
			INPUT_QUEUE_TIMERS[player] = nil
		end
	end

	-- Double input dash
	for player in pairs(DOUBLE_INPUT_DASH_TIMER) do
		for _, dir in ipairs({"RIGHT", "LEFT"}) do
			if DOUBLE_INPUT_DASH_TIMER[player][dir] then
				DOUBLE_INPUT_DASH_TIMER[player][dir].Timer -= dt
				if DOUBLE_INPUT_DASH_TIMER[player][dir].Timer <= 0 then
					DOUBLE_INPUT_DASH_TIMER[player][dir] = nil
				end
			end
		end
	end

	-- Double jump reset
	for player, state in pairs(CAN_DOUBLE_JUMP_STORAGE) do
		if player.Character and not CombatUtils.IsCharacterInAir(player.Character) and state == false then
			CAN_DOUBLE_JUMP_STORAGE[player] = true
		end
	end

	-- Jump attack window
	for player, content in pairs(CAN_JUMP_ATTACK_STORAGE) do
		if player.Character and not CombatUtils.IsCharacterInAir(player.Character) and content.State == true and content.Timer <= 0 then
			CAN_JUMP_ATTACK_STORAGE[player].State = false
			CAN_JUMP_ATTACK_STORAGE[player].Timer = 0
		elseif content.Timer > 0 then
			content.Timer -= dt
		end
	end

	-- Skill cooldowns
	for player, skills in pairs(SKILL_COOLDOWN_STORAGE) do
		for skillKey, remaining in pairs(skills) do
			SKILL_COOLDOWN_STORAGE[player][skillKey] -= dt
			local newRemaining = SKILL_COOLDOWN_STORAGE[player][skillKey]
			if newRemaining <= 0 then
				SKILL_COOLDOWN_STORAGE[player][skillKey] = nil
				MatchUIInteractions:FireClient(player, 'SkillCooldownReady', {Key = skillKey})
			elseif math.floor(remaining) ~= math.floor(newRemaining) then
				MatchUIInteractions:FireClient(player, 'SkillCooldownUpdate', {Key = skillKey, Remaining = newRemaining})
			end
		end
	end

	-- Grab cooldown
	for player, data in pairs(GRAB_COOLDOWN_STORAGE) do
		if data.Timer then
			GRAB_COOLDOWN_STORAGE[player].Timer -= dt
			if GRAB_COOLDOWN_STORAGE[player].Timer <= 0 then
				GRAB_COOLDOWN_STORAGE[player].Timer = nil
			end
		end
	end

	-- Post-hit window
	for player in pairs(POST_HIT_STORAGE) do
		POST_HIT_STORAGE[player] -= dt
		if POST_HIT_STORAGE[player] <= 0 then
			POST_HIT_STORAGE[player] = nil
		end
	end

	-- Block system
	for player, data in pairs(BLOCKING_STORAGE) do
		if data.ParryTimer then
			BLOCKING_STORAGE[player].ParryTimer -= dt
			if BLOCKING_STORAGE[player].ParryTimer <= 0 then BLOCKING_STORAGE[player].ParryTimer = nil end
		end
		if data.Cooldown then
			BLOCKING_STORAGE[player].Cooldown -= dt
			if BLOCKING_STORAGE[player].Cooldown <= 0 then BLOCKING_STORAGE[player].Cooldown = nil end
		end
		if data.Charges then
			for i = 1, 3 do
				if data.Charges[i] ~= nil then
					data.Charges[i] -= dt
					if data.Charges[i] <= 0 then data.Charges[i] = nil end
				end
			end
		end
	end

	-- Sub-módulo ticks
	StaminaModule.Tick(dt)
	ChargeModule.Tick(dt, GetCSM, PAST_CHARGE_KOYOTE_TIME)
	ProgressModule.Tick(dt, GetCSM, PAST_CHARGE_KOYOTE_TIME)
	AttackModule.Tick(dt, GetCSM)
end)

-- ══════════════════════════════════════════════════════════════
-- CLEANUP
-- ══════════════════════════════════════════════════════════════

local function CleanupPlayer(player)
	InputQueue[player]                      = nil
	INPUT_QUEUE_TIMERS[player]              = nil
	COMPOUND_INPUT_TRIGGER_STORAGE[player]  = nil
	COMBO_TIMERS[player]                    = nil
	COMBO_SEQUENCE_COOLDOWN_STORAGE[player] = nil
	HIT_CONFIRM_STORAGE[player]             = nil
	PENDING_ATK_STORAGE[player]             = nil
	DOUBLE_INPUT_DASH_TIMER[player]         = nil
	CAN_DOUBLE_JUMP_STORAGE[player]         = nil
	CAN_JUMP_ATTACK_STORAGE[player]         = nil
	SKILL_COOLDOWN_STORAGE[player]          = nil
	GRAB_COOLDOWN_STORAGE[player]           = nil
	BLOCKING_STORAGE[player]                = nil
	POST_HIT_STORAGE[player]                = nil
	StaminaModule.Cleanup(player)	
	ChargeModule.Cleanup(player)
	ProgressModule.Cleanup(player)
end

Players.PlayerRemoving:Connect(CleanupPlayer)

return CombatManager