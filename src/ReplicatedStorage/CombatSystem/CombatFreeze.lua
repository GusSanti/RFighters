--[[
	FreezeAnimations (Server Module)
	Coloque em: ReplicatedStorage.FreezeAnimations (ModuleScript)

	USO no servidor:
		local FreezeAnimations = require(game.ReplicatedStorage.FreezeAnimations)

		-- Congela por N segundos (volta automático)
		FreezeAnimations.Freeze(player, 5)

		-- Congela indefinidamente
		FreezeAnimations.Freeze(player, math.huge)

		-- Descongela manualmente
		FreezeAnimations.Unfreeze(player)

		-- Checa se está congelado
		FreezeAnimations.IsFrozen(player) --> boolean

	ACEITA tanto Player quanto Character (Model):
		FreezeAnimations.Freeze(player, 5)
		FreezeAnimations.Freeze(player.Character, 5)
--]]

local RunService  = game:GetService("RunService")
local Players     = game:GetService("Players")

assert(RunService:IsServer(), "[FreezeAnimations] O módulo server deve ser usado apenas no servidor!")

-- ─────────────────────────────────────────────
-- Setup dos RemoteEvents
-- ─────────────────────────────────────────────

local remoteFolder = game.ReplicatedStorage.CombatSystem.Events
if not remoteFolder then
	error("[FreezeAnimations Client] Pasta de remotes não encontrada. Verifique se o módulo server está ativo.")
end

local remoteFreeze   = remoteFolder:WaitForChild("AnimationFreeze", 10)
local remoteUnfreeze = remoteFolder:WaitForChild("AnimationUnfreeze", 10)


-- ─────────────────────────────────────────────
-- Estado interno
-- ─────────────────────────────────────────────

-- [player] = { thread, cleanupConn }
local frozenPlayers = {}

local function safeCancelThread(thread)
	if thread then
		pcall(task.cancel, thread)
	end
end

-- Resolve o Player a partir de um Player ou de um Character (Model)
local function resolvePlayer(target)
	if target:IsA("Player") then
		return target
	elseif target:IsA("Model") then
		return Players:GetPlayerFromCharacter(target)
	end
	return nil
end

local function cleanupEntry(player)
	local data = frozenPlayers[player]
	if not data then return end
	safeCancelThread(data.thread)
	if data.cleanupConn then data.cleanupConn:Disconnect() end
	frozenPlayers[player] = nil
end

-- ─────────────────────────────────────────────
-- API pública
-- ─────────────────────────────────────────────

local FreezeAnimations = {}

function FreezeAnimations.Freeze(target, duration, delay)
	assert(typeof(target) == "Instance", "[FreezeAnimations] 'target' deve ser um Player ou Character.")
	assert(type(duration) == "number" and duration > 0, "[FreezeAnimations] 'duration' deve ser um número positivo.")

	local player = resolvePlayer(target)
	if not player then
		warn("[FreezeAnimations] Não foi possível encontrar o Player para o target:", target)
		return
	end

	-- Se já estava congelado, apenas reinicia o timer (cliente já está pausado)
	local isAlreadyFrozen = frozenPlayers[player] ~= nil
	cleanupEntry(player) -- limpa thread/conn anteriores

	if not isAlreadyFrozen then
		-- Primeira vez: manda o cliente pausar as animações
		remoteFreeze:FireClient(player)
	end
	-- Se já estava congelado, não manda Freeze de novo (cliente já está pausado)

	-- Timer automático
	local timerThread = nil
	if duration ~= math.huge then
		timerThread = task.delay(duration, function()
			local data = frozenPlayers[player]
			if data then data.thread = nil end
			FreezeAnimations.Unfreeze(player)
		end)
	end

	-- Limpeza se o player sair do jogo
	local cleanupConn = Players.PlayerRemoving:Connect(function(removedPlayer)
		if removedPlayer == player then
			cleanupEntry(player)
		end
	end)

	frozenPlayers[player] = {
		thread     = timerThread,
		cleanupConn = cleanupConn,
	}
end

function FreezeAnimations.Unfreeze(target)
	local player = resolvePlayer(target)
	if not player then return end

	local data = frozenPlayers[player]
	if not data then return end

	safeCancelThread(data.thread)
	if data.cleanupConn then data.cleanupConn:Disconnect() end
	frozenPlayers[player] = nil

	-- Manda o cliente restaurar as animações
	remoteUnfreeze:FireClient(player)
end

function FreezeAnimations.IsFrozen(target)
	local player = resolvePlayer(target)
	if not player then return false end
	return frozenPlayers[player] ~= nil
end

return FreezeAnimations