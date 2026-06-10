-- ProgressModule
-- Responsável por: progresso de Burst e Ultimate de cada player.

local ProgressModule = {}

-- ── Módulos ──────────────────────────────────────────────────
local MatchModule = require(game.ReplicatedStorage.MatchSystem.MatchModule)

-- ── Storage ──────────────────────────────────────────────────
local BURST_PROGRESS_STORAGE = {}   -- [player] = 0..100
local ULT_PROGRESS_STORAGE   = {}   -- [player] = 0..100
local BURST_INPUT_TIMER      = {}   -- [player] = { Timer, Active }

-- ── API pública ──────────────────────────────────────────────

function ProgressModule.GetBurst(player)
	return BURST_PROGRESS_STORAGE[player] or 0
end

function ProgressModule.GetUlt(player)
	return ULT_PROGRESS_STORAGE[player] or 0
end

function ProgressModule.IncreaseBurst(player, amount)
	local new = math.min((BURST_PROGRESS_STORAGE[player] or 0) + amount, 100)
	BURST_PROGRESS_STORAGE[player] = new
	MatchModule.UpdateBurstBar(player, new)
end

function ProgressModule.IncreaseUlt(player, amount)
	local new = math.min((ULT_PROGRESS_STORAGE[player] or 0) + amount, 100)
	ULT_PROGRESS_STORAGE[player] = new
	MatchModule.UpdateUltBar(player, new)
end

function ProgressModule.ConsumeBurst(player)
	BURST_PROGRESS_STORAGE[player] = nil
	MatchModule.UpdateBurstBar(player, 0)
end

function ProgressModule.ConsumeUlt(player)
	ULT_PROGRESS_STORAGE[player] = nil
	MatchModule.UpdateUltBar(player, 0)
end

-- Burst input timer: ativa janela de burst antes de liberar o input
function ProgressModule.StartBurstInputTimer(player)
	BURST_INPUT_TIMER[player] = { Timer = 0, Active = true }
end

function ProgressModule.ClearBurstInputTimer(player)
	BURST_INPUT_TIMER[player] = nil
end

function ProgressModule.IsBurstInputActive(player)
	return BURST_INPUT_TIMER[player] ~= nil and BURST_INPUT_TIMER[player].Active == true
end

function ProgressModule.Cleanup(player)
	BURST_PROGRESS_STORAGE[player] = nil
	ULT_PROGRESS_STORAGE[player]   = nil
	BURST_INPUT_TIMER[player]      = nil
end

-- chargeDataGetter(player) → CharacterStorageModule
-- pastKoyoteTime → PAST_CHARGE_KOYOTE_TIME
function ProgressModule.Tick(dt, chargeDataGetter, pastKoyoteTime)
	for player, data in pairs(BURST_INPUT_TIMER) do
		if data and data.Active then
			BURST_INPUT_TIMER[player].Timer += dt
			local csm = chargeDataGetter(player)
			if csm then
				local maxTime = csm.Logic.BasicInputs.CHARGEATK.ChargeTime + pastKoyoteTime
				if BURST_INPUT_TIMER[player].Timer >= maxTime then
					BURST_INPUT_TIMER[player] = nil
				end
			end
		end
	end
end

return ProgressModule