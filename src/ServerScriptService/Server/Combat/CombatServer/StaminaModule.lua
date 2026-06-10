-- StaminaModule
-- Responsável por: armazenamento de stamina, gasto, regen e replicação via MatchModule.

local StaminaModule = {}

-- ── Serviços & Módulos ───────────────────────────────────────
local MatchModule = require(game.ReplicatedStorage.MatchSystem.MatchModule)

-- ── Constantes ───────────────────────────────────────────────
local STAMINA_MAX        = 100
local STAMINA_REGEN_DELAY = 2    -- segundos sem gastar para começar regen
local STAMINA_REGEN_RATE  = 25   -- % por segundo

-- Custos exportados para uso externo (CombatManager, etc.)
StaminaModule.Costs = {
	LIGHT_ATK  = 3,
	HARD_ATK   = 5,
	AIR_ATK    = 5,
	CHARGE_ATK = 15,
	DASH       = 50,
	SKILL      = 25,
}

-- ── Storage ──────────────────────────────────────────────────
local STAMINA_STORAGE = {}   -- [player] = { Current, LastSpendTime }

-- ── Funções internas ─────────────────────────────────────────
local function GetData(player)
	if not STAMINA_STORAGE[player] then
		STAMINA_STORAGE[player] = { Current = STAMINA_MAX, LastSpendTime = -math.huge }
	end
	return STAMINA_STORAGE[player]
end

-- ── API pública ──────────────────────────────────────────────

function StaminaModule.Has(player, amount)
	return GetData(player).Current >= amount
end

function StaminaModule.Spend(player, amount)
	local data = GetData(player)
	data.Current       = math.max(data.Current - amount, 0)
	data.LastSpendTime = os.clock()
	MatchModule.UpdateStaminaBar(player, data.Current / STAMINA_MAX * 100)
end

function StaminaModule.Cleanup(player)
	STAMINA_STORAGE[player] = nil
end

-- Chamado no Heartbeat do CombatManager
function StaminaModule.Tick(dt)
	for player, data in pairs(STAMINA_STORAGE) do
		if data.Current < STAMINA_MAX then
			if os.clock() - data.LastSpendTime >= STAMINA_REGEN_DELAY then
				local newStamina = math.min(data.Current + STAMINA_REGEN_RATE * dt, STAMINA_MAX)
				STAMINA_STORAGE[player].Current = newStamina
				MatchModule.UpdateStaminaBar(player, newStamina / STAMINA_MAX * 100)
			end
		end
	end
end

return StaminaModule