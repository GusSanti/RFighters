--[[
	MatchmakingModule
	-----------------
	• Cada servidor só tenta fazer match SE for o "dono" do time A
	  (teamAEntry.serverId == game.JobId). Isso evita que vários servidores
	  publiquem o mesmo "MatchFound" ao mesmo tempo.
	• PlayersInQueue é exportado para o Listener usar como guarda.
--]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService   = game:GetService("MessagingService")
local TeleportService    = game:GetService("TeleportService")
local HttpService        = game:GetService("HttpService")
local Players            = game:GetService("Players")

local PLACE_ID = 91510030565074  -- ⚠️ seu PlaceId
local MAX_SIZE = 5
local EXPIRY   = 120

-- ============================================================
-- TABELA LOCAL: quais players DESTE servidor estão na fila
-- O Listener usa essa tabela para não teleportar quem não pediu
-- ============================================================
local PlayersInQueue = {}   -- [userId: number] = true

local function getQueue(size: number)
	return MemoryStoreService:GetSortedMap("Queue_" .. size)
end

local MatchmakingModule = {}

-- Expõe a tabela para o Listener (mesmo Script pai ou require)
MatchmakingModule.PlayersInQueue = PlayersInQueue

local function generateTeamId()
	return HttpService:GenerateGUID(false)
end

-- ============================================================
-- EnterQueue
-- ============================================================
function MatchmakingModule.EnterQueue(players: {Player}): string
	local size = #players
	assert(size >= 1 and size <= MAX_SIZE, "Time deve ter entre 1 e 5 players")

	local teamId  = generateTeamId()
	local members = {}
	for _, p in ipairs(players) do
		table.insert(members, {
			userId   = p.UserId,
			name     = p.Name,
			serverId = game.JobId,
		})
	end

	local entry = {
		teamId   = teamId,
		size     = size,
		members  = members,
		serverId = game.JobId,   -- servidor dono do time
	}

	local queue = getQueue(size)
	local ok, err = pcall(function()
		queue:SetAsync(teamId, entry, EXPIRY)
	end)

	if not ok then
		warn("Erro ao entrar na fila:", err)
		return nil
	end

	-- Marca os players localmente como "na fila"
	for _, p in ipairs(players) do
		p:SetAttribute("TeamId",   teamId)
		p:SetAttribute("TeamSize", size)
		PlayersInQueue[p.UserId] = true        -- ✅ guarda local
	end

	print(("[Queue_%d] Time %s entrou (%d players)"):format(size, teamId:sub(1,8), size))

	MatchmakingModule.TryMatch(size)
	return teamId
end

-- ============================================================
-- LeaveQueue
-- ============================================================
function MatchmakingModule.LeaveQueue(player: Player)
	local teamId   = player:GetAttribute("TeamId")
	local teamSize = player:GetAttribute("TeamSize")
	if not teamId or not teamSize then return end

	local queue = getQueue(teamSize)
	pcall(function()
		queue:RemoveAsync(teamId)
	end)

	-- Limpa todos os membros do mesmo time
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("TeamId") == teamId then
			PlayersInQueue[p.UserId] = nil     -- ✅ remove da guarda local
			p:SetAttribute("TeamId",   nil)
			p:SetAttribute("TeamSize", nil)
		end
	end

	print(("[Queue_%d] Time %s removido (saída de %s)"):format(
		teamSize, teamId:sub(1,8), player.Name))
end

-- ============================================================
-- TryMatch
-- CORREÇÃO PRINCIPAL: só o servidor dono do time A faz o match.
-- ============================================================
function MatchmakingModule.TryMatch(size: number)
	local queue = getQueue(size)

	local ok, items = pcall(function()
		return queue:GetRangeAsync(Enum.SortDirection.Ascending, 2)
	end)

	if not ok or #items < 2 then return end

	local teamAEntry = items[1].value
	local teamBEntry = items[2].value

	-- ✅ Só age se ESTE servidor é o dono do time A
	-- Evita que múltiplos servidores publiquem a mesma partida
	if teamAEntry.serverId ~= game.JobId then
		return
	end

	-- Remove da fila antes de reservar (evita double-match)
	local removeOk = true
	pcall(function() queue:RemoveAsync(items[1].key) end)
	pcall(function() queue:RemoveAsync(items[2].key) end)

	local reservedCode
	local teleOk, teleErr = pcall(function()
		reservedCode = TeleportService:ReserveServerAsync(PLACE_ID)
	end)

	if not teleOk then
		warn("Erro ao criar servidor reservado:", teleErr)
		-- Devolve os times à fila para não perder jogadores
		pcall(function() queue:SetAsync(items[1].key, teamAEntry, EXPIRY) end)
		pcall(function() queue:SetAsync(items[2].key, teamBEntry, EXPIRY) end)
		return
	end

	local message = {
		reservedCode = reservedCode,
		teamSize     = size,
		teamA        = teamAEntry,
		teamB        = teamBEntry,
	}

	local pubOk, pubErr = pcall(function()
		MessagingService:PublishAsync("MatchFound", HttpService:JSONEncode(message))
	end)

	if not pubOk then
		warn("Erro ao publicar MatchFound:", pubErr)
	else
		print(("[Queue_%d] Partida formada! %s vs %s"):format(
			size, teamAEntry.teamId:sub(1,8), teamBEntry.teamId:sub(1,8)))
	end
end

-- ============================================================
-- Limpeza automática ao desconectar
-- ============================================================
Players.PlayerRemoving:Connect(function(player)
	PlayersInQueue[player.UserId] = nil    -- ✅ garante limpeza
	MatchmakingModule.LeaveQueue(player)
end)

-- ============================================================
-- Loop periódico (só tenta se este servidor tiver alguém na fila)
-- ============================================================
task.spawn(function()
	while true do
		task.wait(5)
		-- Só roda TryMatch se este servidor tem players na fila
		-- (evita trabalho desnecessário em servidores de combate)
		local hasPlayersInQueue = next(PlayersInQueue) ~= nil
		if hasPlayersInQueue then
			for size = 1, MAX_SIZE do
				MatchmakingModule.TryMatch(size)
			end
		end
	end
end)

return MatchmakingModule