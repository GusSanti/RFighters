-- AttackModule
-- Responsável por: execução de ataques básicos (combo sequencial) e
-- ataques não-combo (non-sequential), usando AttackConfig comprimido.

local AttackModule = {}

-- ── Módulos ──────────────────────────────────────────────────
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local PlayAnimation     = require(game.ReplicatedStorage.CombatSystem.PlayAnimationServer)
local EffectsHelper     = require(game.ReplicatedStorage.CombatSystem.EffectsHelper)
local CombatUtils       = require(game.ReplicatedStorage.CombatSystem.CombatUtils)
local HitboxModule      = require(script.Parent.HitboxModule)

-- ── Constantes ───────────────────────────────────────────────
local COMBO_RUNOUT_TIME               = 1.5
local COMBO_FINISH_STUN_TIME          = 1
local KOYOTE_WINDOW                   = 0.35
local COMBO_SEQUENCE_DEFAULT_COOLDOWN = 2

-- ── Storage (injetado via Init) ───────────────────────────────
local COMBO_TIMERS                   = nil
local HIT_CONFIRM_STORAGE            = nil
local PENDING_ATK_STORAGE            = nil
local COMBO_SEQUENCE_COOLDOWN_STORAGE = nil

function AttackModule.Init(comboTimers, hitConfirm, pendingAtk, comboSeqCooldown)
	COMBO_TIMERS                    = comboTimers
	HIT_CONFIRM_STORAGE             = hitConfirm
	PENDING_ATK_STORAGE             = pendingAtk
	COMBO_SEQUENCE_COOLDOWN_STORAGE = comboSeqCooldown
end

-- ── Helpers internos ─────────────────────────────────────────
local function KnockbackSelf(hitboxData, attackerCharacter, enemyCharacter)
	if not (hitboxData.Knockback and hitboxData.Knockback.Self) then return end
	local canPlay = not (hitboxData.KnockbackOnlyAir and not CombatUtils.IsCharacterInAir(attackerCharacter))
	if not canPlay then return end

	if CombatUtils.IsCharacterInAir(attackerCharacter) and hitboxData.Knockback.SelfAir then
		if not hitboxData.Knockback.SelfAir.HitOnly then
			HitboxModule.OverrideAndPlayKnockback(hitboxData.Knockback.SelfAir, attackerCharacter, attackerCharacter)
		end
	else
		if not hitboxData.Knockback.Self.HitOnly then
			HitboxModule.OverrideAndPlayKnockback(hitboxData.Knockback.Self, attackerCharacter, attackerCharacter)
		end
	end
end

-- ─────────────────────────────────────────────────────────────
-- AttackConfig (tabela unificada passada pelo CombatManager)
--
--   cfg.HitboxTable      → table de hitbox (sequência ou único)
--   cfg.AttackAnims      → tabela de animações de ataque
--   cfg.HitAnims         → tabela de animações de hit
--   cfg.Effects          → tabela de efeitos do attacker
--   cfg.HitEffects       → tabela de efeitos do hit
--   cfg.Sounds           → tabela de sons do attacker
--   cfg.HitSounds        → tabela de sons do hit
--   cfg.ParryEffects     → { Effect, Sound }
--   cfg.ComboType        → string (ex: 'Light', 'Hard') — só para BasicHit
--   cfg.ComboName        → string — só para NonCombo (para cooldown)
-- ─────────────────────────────────────────────────────────────

-- ── Basic (sequencial, com combo counter) ────────────────────
function AttackModule.ExecuteBasic(player, cfg, noStamina)
	local ComboType   = cfg.ComboType
	local HitboxTable = cfg.HitboxTable

	local firstAttack  = false
	local PlayerCombo  = COMBO_TIMERS[player] and COMBO_TIMERS[player][ComboType]

	if not PlayerCombo then
		if not COMBO_TIMERS[player] then COMBO_TIMERS[player] = {} end
		PlayerCombo = { Timer = COMBO_RUNOUT_TIME, Combo = 1 }
		COMBO_TIMERS[player][ComboType] = PlayerCombo
		firstAttack = true
	end

	local playerState = StateManager.GET(player)
	if playerState['COMBAT_DOING_COMBAT']
		or playerState['COMBAT_IN_COMBO_COOLDOWN']
		or playerState[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED]
		or playerState[StateManagerEnums.STATES_ENUM.COMBAT_SKILL_BEING_ATTACKED]
	then
		PENDING_ATK_STORAGE[player] = {
			Timer = KOYOTE_WINDOW, Type = 'Basic', cfg = cfg, noStamina = noStamina
		}
		return
	end

	if not HitboxTable[PlayerCombo.Combo] then return end

	if not firstAttack then
		if not HIT_CONFIRM_STORAGE[player] then
			COMBO_TIMERS[player] = nil
			return
		end
		HIT_CONFIRM_STORAGE[player] = nil
		PlayerCombo.Timer = COMBO_RUNOUT_TIME
		PlayerCombo.Combo += 1
	end

	local i = PlayerCombo.Combo

	if cfg.Effects[i] and cfg.Effects[i].TargetCharacter == 'Self' then
		EffectsHelper.PlayEffect(cfg.Effects[i], player.Character)
	end
	EffectsHelper.PlaySound(cfg.Sounds[i], player.Character)

	HitboxModule.Create(player.Character, {
		HitboxTable     = HitboxTable[i],
		HitsTable       = cfg.HitAnims,
		HitEffectsTable = cfg.HitEffects,
		HitSoundsTable  = cfg.HitSounds,
		ParryEffects    = cfg.ParryEffects,
		ComboNumber     = i,
	})

	PlayAnimation.PlayCharacterAnimation(player.Character, cfg.AttackAnims[i])
	KnockbackSelf(HitboxTable[i], player.Character, nil)

	local doingCombatTime = HitboxTable[i].DoingCombatTime + (noStamina and 0.9 or 0)
	StateManager.POST_REMOVE(player, StateManagerEnums.STATES_ENUM.COMBAT_DOING_COMBAT, doingCombatTime)

	if not HitboxTable[i + 1] then
		StateManager.POST_REMOVE(player, StateManagerEnums.STATES_ENUM.COMBAT_IN_COMBO_COOLDOWN, COMBO_FINISH_STUN_TIME)
		COMBO_TIMERS[player] = nil
	end
end

-- ── Non-combo (ataque único, com cooldown por nome) ──────────
function AttackModule.ExecuteNonCombo(player, cfg, noStamina)
	local HitboxInfo = cfg.HitboxTable
	local ComboName  = cfg.ComboName

	local playerState = StateManager.GET(player)
	if playerState['COMBAT_DOING_COMBAT']
		or playerState['COMBAT_BEING_ATTACKED']
		or playerState[StateManagerEnums.STATES_ENUM.COMBAT_SKILL_BEING_ATTACKED]
	then
		if not COMBO_SEQUENCE_COOLDOWN_STORAGE[player] then COMBO_SEQUENCE_COOLDOWN_STORAGE[player] = {} end
		if ComboName and not COMBO_SEQUENCE_COOLDOWN_STORAGE[player][ComboName] then
			PENDING_ATK_STORAGE[player] = {
				Timer = KOYOTE_WINDOW, Type = 'NonCombo', cfg = cfg, noStamina = noStamina
			}
		end
		return
	end

	if playerState['COMBAT_INSKILL'] then return end

	if cfg.Effects and cfg.Effects.TargetCharacter == 'Self' then
		EffectsHelper.PlayEffect(cfg.Effects, player.Character)
	end
	EffectsHelper.PlaySound(cfg.Sounds, player.Character)

	HitboxModule.Create(player.Character, {
		HitboxTable     = HitboxInfo,
		HitsTable       = { [1] = cfg.HitAnims },
		HitEffectsTable = { [1] = cfg.HitEffects },
		HitSoundsTable  = { [1] = cfg.HitSounds },
		ParryEffects    = cfg.ParryEffects,
		ComboNumber     = 1,
	})

	KnockbackSelf(HitboxInfo, player.Character, nil)
	PlayAnimation.PlayCharacterAnimation(player.Character, cfg.AttackAnims)

	local doingCombatTime = HitboxInfo.DoingCombatTime + (noStamina and 0.9 or 0)
	StateManager.POST_REMOVE(player, StateManagerEnums.STATES_ENUM.COMBAT_DOING_COMBAT, doingCombatTime)
end

-- ── Tick (resolve PENDING_ATK_STORAGE) ───────────────────────
-- Chamado no Heartbeat do CombatManager.
function AttackModule.Tick(dt, chargeDataGetter)
	for player, pending in pairs(PENDING_ATK_STORAGE) do
		pending.Timer -= dt
		if pending.Timer <= 0 then
			PENDING_ATK_STORAGE[player] = nil
			continue
		end

		local ps = StateManager.GET(player)
		local stillBlocked = ps['COMBAT_DOING_COMBAT']
			or ps['COMBAT_IN_COMBO_COOLDOWN']
			or ps[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED]
			or ps[StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED]
			or ps[StateManagerEnums.STATES_ENUM.COMBAT_INSKILL]

		if not stillBlocked then
			local cfg       = pending.cfg
			local comboName = cfg.ComboName

			if comboName then
				if not COMBO_SEQUENCE_COOLDOWN_STORAGE[player] then COMBO_SEQUENCE_COOLDOWN_STORAGE[player] = {} end
				if COMBO_SEQUENCE_COOLDOWN_STORAGE[player][comboName] then
					PENDING_ATK_STORAGE[player] = nil
					continue
				end
				local csm     = chargeDataGetter(player)
				local Content = csm and csm.Logic.Combos[comboName]
				local cooldown = (Content and Content.ComboAttack and Content.ComboAttack.Cooldown)
					or (Content and Content.Cooldown)
					or COMBO_SEQUENCE_DEFAULT_COOLDOWN
				COMBO_SEQUENCE_COOLDOWN_STORAGE[player][comboName] = cooldown
			end

			PENDING_ATK_STORAGE[player] = nil

			if pending.Type == 'Basic' then
				AttackModule.ExecuteBasic(player, cfg, pending.noStamina)
			elseif pending.Type == 'NonCombo' then
				AttackModule.ExecuteNonCombo(player, cfg, pending.noStamina)
			end
		end
	end

	-- Combo timers (runout)
	for player, types in pairs(COMBO_TIMERS) do
		for comboType in pairs(types) do
			COMBO_TIMERS[player][comboType].Timer -= dt
			if COMBO_TIMERS[player][comboType].Timer <= 0 then
				COMBO_TIMERS[player][comboType] = nil
			end
		end
	end

	-- Combo sequence cooldowns
	for player, combos in pairs(COMBO_SEQUENCE_COOLDOWN_STORAGE) do
		for comboName in pairs(combos) do
			COMBO_SEQUENCE_COOLDOWN_STORAGE[player][comboName] -= dt
			if COMBO_SEQUENCE_COOLDOWN_STORAGE[player][comboName] <= 0 then
				COMBO_SEQUENCE_COOLDOWN_STORAGE[player][comboName] = nil
			end
		end
	end
end

return AttackModule