-- ChargeModule
-- Responsável por: criação/atualização/destruição da barra de charge,
-- estado de charging e timer de charge de cada player.

local ChargeModule = {}

-- ── Serviços & Assets ────────────────────────────────────────
local Debris           = game:GetService("Debris")
local ChargeBarTemplate = game.ReplicatedStorage.CombatSystem.ManagerAssets.Charge

-- ── Módulos ──────────────────────────────────────────────────
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)

-- ── Storage ──────────────────────────────────────────────────
local CHARGE_ATKS_TIMER              = {}   -- [player] = { Timer }
local CHARGE_GLOBAL_COOLDOWN_STORAGE = {}   -- [player] = { Timer }
local CHARGE_BAR_STORAGE             = {}   -- [player] = { Part, Gradient }

-- ── Bar internals ────────────────────────────────────────────
local function CreateBar(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil, nil end

	local part = ChargeBarTemplate:Clone()
	part.Anchored   = false
	part.CanCollide = false
	part.Massless   = true
	part.CastShadow = false
	part.Parent     = workspace

	local weld = Instance.new("Weld")
	weld.Part0  = hrp
	weld.Part1  = part
	weld.C0     = CFrame.new(0, 3.2, 0)
	weld.Parent = part

	local barrinha = part:FindFirstChild("BillboardGui")
		and part.BillboardGui:FindFirstChild("HUD")
		and part.BillboardGui.HUD:FindFirstChild("Barrinha")

	if not barrinha then part:Destroy(); return nil, nil end

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 0
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	gradient.Parent = barrinha
	return part, gradient
end

local function UpdateBar(gradient, progress)
	local fill = math.clamp(progress, 0.001, 0.999)
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,                           Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(fill,                        Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(math.min(fill + 0.001, 1),  Color3.fromRGB(0, 0, 0)),
		ColorSequenceKeypoint.new(1,                           Color3.fromRGB(0, 0, 0)),
	})
end

-- ── API pública ──────────────────────────────────────────────

function ChargeModule.IsCharging(player)
	return CHARGE_ATKS_TIMER[player] ~= nil
end

function ChargeModule.HasGlobalCooldown(player)
	return CHARGE_GLOBAL_COOLDOWN_STORAGE[player]
		and CHARGE_GLOBAL_COOLDOWN_STORAGE[player].Timer ~= nil
end

function ChargeModule.GetTimer(player)
	return CHARGE_ATKS_TIMER[player] and CHARGE_ATKS_TIMER[player].Timer or 0
end

function ChargeModule.StartCharge(player)
	CHARGE_ATKS_TIMER[player] = { Timer = 0 }
	local part, gradient = CreateBar(player.Character)
	if part then
		CHARGE_BAR_STORAGE[player] = { Part = part, Gradient = gradient }
	end
	StateManager.POST(player, StateManagerEnums.STATES_ENUM.COMBAT_CHARGING_ATTACK)
end

function ChargeModule.DestroyBar(player)
	if CHARGE_BAR_STORAGE[player] then
		local part = CHARGE_BAR_STORAGE[player].Part
		if part and part.Parent then part:Destroy() end
		CHARGE_BAR_STORAGE[player] = nil
	end
end

function ChargeModule.Cancel(player)
	if not CHARGE_ATKS_TIMER[player] then return end
	CHARGE_ATKS_TIMER[player] = nil
	StateManager.REMOVE(player, StateManagerEnums.STATES_ENUM.COMBAT_CHARGING_ATTACK)
	StateManager.REMOVE(player, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	ChargeModule.DestroyBar(player)
end

function ChargeModule.EndCharge(player, globalCooldownTime)
	local timer = CHARGE_ATKS_TIMER[player] and CHARGE_ATKS_TIMER[player].Timer or 0
	CHARGE_ATKS_TIMER[player] = nil
	StateManager.REMOVE(player, StateManagerEnums.STATES_ENUM.COMBAT_CHARGING_ATTACK)
	ChargeModule.DestroyBar(player)
	-- aplica global cooldown
	if not CHARGE_GLOBAL_COOLDOWN_STORAGE[player] then
		CHARGE_GLOBAL_COOLDOWN_STORAGE[player] = {}
	end
	CHARGE_GLOBAL_COOLDOWN_STORAGE[player].Timer = globalCooldownTime
	return timer
end

function ChargeModule.StartGlobalCooldown(player, time)
	if not CHARGE_GLOBAL_COOLDOWN_STORAGE[player] then
		CHARGE_GLOBAL_COOLDOWN_STORAGE[player] = {}
	end
	CHARGE_GLOBAL_COOLDOWN_STORAGE[player].Timer = time
end

function ChargeModule.Cleanup(player)
	ChargeModule.DestroyBar(player)
	CHARGE_ATKS_TIMER[player]              = nil
	CHARGE_GLOBAL_COOLDOWN_STORAGE[player] = nil
end

-- Chamado no Heartbeat do CombatManager
-- chargeDataGetter(player) deve retornar o CharacterStorageModule do player
-- pastKoyoteTime é a constante PAST_CHARGE_KOYOTE_TIME
function ChargeModule.Tick(dt, chargeDataGetter, pastKoyoteTime)
	for player, charge in pairs(CHARGE_ATKS_TIMER) do
		local csm = chargeDataGetter(player)
		if not csm then continue end

		CHARGE_ATKS_TIMER[player].Timer += dt

		if CHARGE_BAR_STORAGE[player] and CHARGE_BAR_STORAGE[player].Gradient then
			local chargeTime = csm.Logic.BasicInputs.CHARGEATK.ChargeTime
			local progress   = math.clamp(CHARGE_ATKS_TIMER[player].Timer / chargeTime, 0, 1)
			UpdateBar(CHARGE_BAR_STORAGE[player].Gradient, progress)
		end

		if CHARGE_ATKS_TIMER[player].Timer >= csm.Logic.BasicInputs.CHARGEATK.ChargeTime + pastKoyoteTime then
			StateManager.REMOVE(player, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
			StateManager.REMOVE(player, StateManagerEnums.STATES_ENUM.COMBAT_CHARGING_ATTACK)
			CHARGE_ATKS_TIMER[player] = nil
			ChargeModule.DestroyBar(player)
		end
	end

	for player, data in pairs(CHARGE_GLOBAL_COOLDOWN_STORAGE) do
		if data.Timer then
			CHARGE_GLOBAL_COOLDOWN_STORAGE[player].Timer -= dt
			if CHARGE_GLOBAL_COOLDOWN_STORAGE[player].Timer <= 0 then
				CHARGE_GLOBAL_COOLDOWN_STORAGE[player].Timer = nil
			end
		end
	end
end

return ChargeModule