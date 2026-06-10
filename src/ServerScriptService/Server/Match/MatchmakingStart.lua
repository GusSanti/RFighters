local module = {}

-- MatchServer.lua
-- Roda no servidor reservado. Espera os dois times chegarem,
-- reconstrói os objetos Team e dispara o sistema existente.

local Players         = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local MatchBindableEvent    = game.ReplicatedStorage.Events.Match.MatchBindableEvent
local MatchBindableFunction = game.ReplicatedStorage.Events.Match.MatchBindableFunction
local NotificationModule    = require(game.ReplicatedStorage.Modules.NotificationModule)

local TIMEOUT  = 15
local PLACE_ID = 91510030565074  -- ⚠️ seu PlaceId (lobby)

-- ============================================================
-- ESTADO LOCAL
-- ============================================================

local matchData      = nil
local arrivedPlayers = {}   -- [userId] = Player
local matchStarted   = false
local matchCancelled = false

local team1Obj = nil
local team2Obj = nil

-- ============================================================
-- HELPERS
-- ============================================================

local function getExpectedUserIds(): { number }
	if not matchData then return {} end
	local ids = {}
	for _, m in ipairs(matchData.teamA.members) do table.insert(ids, m.userId) end
	for _, m in ipairs(matchData.teamB.members) do table.insert(ids, m.userId) end
	return ids
end

local function countExpected(): number
	return #getExpectedUserIds()
end

local function allArrived(): boolean
	-- Se ainda não temos matchData, nunca podemos estar prontos
	if not matchData then return false end

	local expected = getExpectedUserIds()
	if #expected == 0 then return false end

	for _, userId in ipairs(expected) do
		if not arrivedPlayers[userId] then return false end
	end
	return true
end

local function resolvePlayers(teamData): { Player }
	local resolved = {}
	for _, member in ipairs(teamData.members) do
		local player = arrivedPlayers[member.userId]
		if player then
			table.insert(resolved, player)
		end
	end
	return resolved
end

-- ============================================================
-- TENTAR EXTRAIR matchData DE QUALQUER PLAYER QUE CHEGAR
-- ============================================================

-- CORREÇÃO PRINCIPAL: tenta extrair de QUALQUER player, não só o primeiro.
-- Para de tentar assim que encontrar dados válidos.
local function tryLoadMatchData(player: Player)
	if matchData then return end  -- já temos, não precisa

	local ok, data = pcall(function()
		return player:GetJoinData().TeleportData
	end)

	if not ok or not data then
		warn(("[MatchServer] %s chegou sem TeleportData"):format(player.Name))
		return
	end

	if type(data) ~= "table" or not data.teamA or not data.teamB then
		warn(("[MatchServer] %s: TeleportData inválido"):format(player.Name))
		return
	end

	matchData = data
	print(("[MatchServer] Dados recebidos de %s. Esperando %d players..."):format(
		player.Name, countExpected()))
end

-- ============================================================
-- CANCELAR PARTIDA
-- ============================================================

local function cancelMatch(reason: string)
	if matchCancelled then return end
	matchCancelled = true

	warn("[MatchServer] Partida cancelada:", reason)

	if team1Obj and team2Obj then
		MatchBindableEvent:Fire('StopNvNMatch', { Team1 = team1Obj, Team2 = team2Obj })
		task.wait()
		MatchBindableEvent:Fire('RemoveTeam', { Players = team1Obj.Players })
		MatchBindableEvent:Fire('RemoveTeam', { Players = team2Obj.Players })
	end

	for _, player in ipairs(Players:GetPlayers()) do
		NotificationModule.SendMessageToClient(player, "Match was cancelled: " .. reason)
	end

	task.wait(2)

	for _, player in ipairs(Players:GetPlayers()) do
		local ok, err = pcall(function()
			TeleportService:Teleport(PLACE_ID, player)
		end)
		if not ok then warn("[MatchServer] Erro ao teleportar de volta:", err) end
	end
end

-- ============================================================
-- INICIAR PARTIDA
-- ============================================================

local function startMatch()
	if matchStarted or matchCancelled then return end
	matchStarted = true

	local size = matchData.teamSize

	local playersA = resolvePlayers(matchData.teamA)
	local playersB = resolvePlayers(matchData.teamB)

	if #playersA ~= size or #playersB ~= size then
		cancelMatch("Couldn't resolve all players")
		return
	end

	MatchBindableEvent:Fire('CreateTeam', { Players = playersA })
	MatchBindableEvent:Fire('CreateTeam', { Players = playersB })

	task.wait()

	local activeTeams = MatchBindableFunction:Invoke('GetActiveTeams')

	local function findTeamByPlayers(playerList)
		for _, team in ipairs(activeTeams) do
			if #team.Players == #playerList then
				local matched = true
				for _, p in ipairs(playerList) do
					local found = false
					for _, tp in ipairs(team.Players) do
						if tp == p then found = true; break end
					end
					if not found then matched = false; break end
				end
				if matched then return team end
			end
		end
		return nil
	end

	team1Obj = findTeamByPlayers(playersA)
	team2Obj = findTeamByPlayers(playersB)

	if not team1Obj or not team2Obj then
		cancelMatch("Couldn't find teams in ActiveTeams")
		return
	end

	local matchTypeMap = {
		[1] = 'Start1v1Match',
		[2] = 'Start2v2Match',
		[3] = 'Start3v3Match',
		[4] = 'Start4v4Match',
		[5] = 'Start5v5Match',
	}
	local action = matchTypeMap[size]

	if size == 1 then
		MatchBindableEvent:Fire(action, {
			Player1 = playersA[1],
			Player2 = playersB[1],
		})
	else
		MatchBindableEvent:Fire(action, {
			Team1 = team1Obj,
			Team2 = team2Obj,
		})
	end

	print(("[MatchServer] Partida %dvs%d iniciada!"):format(size, size))
end

-- ============================================================
-- PLAYER ADDED / REMOVING
-- ============================================================

-- Players que já estavam no servidor quando o script carregou
-- (raro, mas possível — garante que não perdemos ninguém)
for _, player in ipairs(Players:GetPlayers()) do
	tryLoadMatchData(player)
	arrivedPlayers[player.UserId] = player
end

Players.PlayerAdded:Connect(function(player)
	-- CORREÇÃO: tenta carregar matchData de qualquer player que chegar
	tryLoadMatchData(player)

	arrivedPlayers[player.UserId] = player

	local arrived = 0
	for _ in pairs(arrivedPlayers) do arrived += 1 end

	print(("[MatchServer] %s chegou. %d/%d players"):format(
		player.Name, arrived, countExpected()))

	if allArrived() then
		startMatch()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if not matchStarted and not matchCancelled then
		cancelMatch(player.Name .. " left before the match started")
	end
	-- Se já começou, o MatchServer principal cuida via PlayerRemoving dele
end)

-- ============================================================
-- TIMEOUT
-- ============================================================

task.delay(TIMEOUT, function()
	if matchStarted or matchCancelled then return end

	-- ✅ Só cancela se realmente havia uma partida esperada
	-- (matchData nil = nenhum player desta partida chegou aqui)
	if not matchData then
		-- Servidor reservado órfão — ninguém chegou com dados válidos.
		-- Não dispara warn de "partida cancelada", só fecha silenciosamente.
		warn("[MatchServer] Servidor reservado sem dados após timeout. Ignorando.")
		matchCancelled = true
		return
	end

	local arrived = 0
	for _ in pairs(arrivedPlayers) do arrived += 1 end
	cancelMatch(("Timeout — %d/%d players arrived"):format(arrived, countExpected()))
end)

return module
