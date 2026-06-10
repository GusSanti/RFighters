local MatchModule = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local MatchRemoteEvent = game.ReplicatedStorage.Events.Match.MatchRemoteEvent
local MatchRemoteFunction = game.ReplicatedStorage.Events.Match.MatchRemoteFunction
local MatchBindableEvent = game.ReplicatedStorage.Events.Match.MatchBindableEvent
local MatchBindableFunction = game.ReplicatedStorage.Events.Match.MatchBindableFunction

local function isServer()
	return RunService:IsServer()
end

local function isClient()
	return RunService:IsClient()
end

-- =========================
-- GETTERS (CLIENT PODE)
-- =========================

function MatchModule.GetActiveTeams()
	if isServer() then
		return MatchBindableFunction:Invoke("GetActiveTeams")
	else
		return MatchRemoteFunction:InvokeServer("GetActiveTeams")
	end
end

function MatchModule.GetInMatchPlayers()
	if isServer() then
		return MatchBindableFunction:Invoke("GetInMatchPlayers")
	else
		return MatchRemoteFunction:InvokeServer("GetInMatchPlayers")
	end
end

function MatchModule.GetInMatchTeams()
	if isServer() then
		return MatchBindableFunction:Invoke("GetInMatchTeams")
	else
		return MatchRemoteFunction:InvokeServer("GetInMatchTeams")
	end
end

function MatchModule.FindPlayer(plrName)
	if isServer() then
		return MatchBindableFunction:Invoke("FindPlayer", { PlayerName = plrName })
	else
		return MatchRemoteFunction:InvokeServer("FindPlayer", { PlayerName = plrName })
	end
end

function MatchModule.FindPlayersTeam(plrName)
	if isServer() then
		return MatchBindableFunction:Invoke("FindPlayersTeam", { PlayerName = plrName })
	else
		return MatchRemoteFunction:InvokeServer("FindPlayersTeam", { PlayerName = plrName })
	end
end

function MatchModule.FindTeam(player1Name, player2Name)
	if isServer() then
		return MatchBindableFunction:Invoke("FindTeam", {
			Player1 = player1Name,
			Player2 = player2Name
		})
	else
		return MatchRemoteFunction:InvokeServer("FindTeam", {
			Player1 = player1Name,
			Player2 = player2Name
		})
	end
end

-- =========================
-- GETTERS — POR PLAYER (NOVO)
-- =========================

--- Retorna a match (1v1 ou NvN) em que o player está.
--- Retorno: { Type = "Players"|"Teams", Match = matchData } ou nil
function MatchModule.GetPlayerMatch(player)
	local plrName = typeof(player) == "Instance" and player.Name or tostring(player)
	if isServer() then
		return MatchBindableFunction:Invoke("GetPlayerMatch", { PlayerName = plrName })
	else
		return MatchRemoteFunction:InvokeServer("GetPlayerMatch", { PlayerName = plrName })
	end
end

function MatchModule.GetPlayersArena(player)
	local plrName = typeof(player) == "Instance" and player.Name or tostring(player)

	if isServer() then
		return MatchBindableFunction:Invoke("GetPlayerArena", { PlayerName = plrName })
	else
		return MatchRemoteFunction:InvokeServer("GetPlayerArena", { PlayerName = plrName })
	end
end

--- Retorna o time (ActiveTeams) ao qual o player pertence, com status.
--- Retorno: { Status = "ActiveOnly"|"ActiveAndInMatch", Team = teamData, Match = matchData? } ou nil
function MatchModule.GetPlayerTeam(player)
	local plrName = typeof(player) == "Instance" and player.Name or tostring(player)
	if isServer() then
		return MatchBindableFunction:Invoke("GetPlayerTeam", { PlayerName = plrName })
	else
		return MatchRemoteFunction:InvokeServer("GetPlayerTeam", { PlayerName = plrName })
	end
end

--- Retorna se o player está vivo dentro da sua match NvN atual.
--- Retorno: boolean ou nil se não estiver em match
function MatchModule.IsPlayerAlive(player)
	local plrName = typeof(player) == "Instance" and player.Name or tostring(player)
	if isServer() then
		return MatchBindableFunction:Invoke("IsPlayerAlive", { PlayerName = plrName })
	else
		return MatchRemoteFunction:InvokeServer("IsPlayerAlive", { PlayerName = plrName })
	end
end

--- Retorna o time adversário do player na match NvN atual.
--- Retorno: teamData ou nil
function MatchModule.GetPlayerEnemyTeam(player)
	local plrName = typeof(player) == "Instance" and player.Name or tostring(player)
	if isServer() then
		return MatchBindableFunction:Invoke("GetPlayerEnemyTeam", { PlayerName = plrName })
	else
		return MatchRemoteFunction:InvokeServer("GetPlayerEnemyTeam", { PlayerName = plrName })
	end
end

--- Retorna o adversário de um player em 1v1.
--- Retorno: Player ou nil
function MatchModule.GetPlayer1v1Opponent(player)
	local plrName = typeof(player) == "Instance" and player.Name or tostring(player)
	if isServer() then
		return MatchBindableFunction:Invoke("GetPlayer1v1Opponent", { PlayerName = plrName })
	else
		return MatchRemoteFunction:InvokeServer("GetPlayer1v1Opponent", { PlayerName = plrName })
	end
end

-- =========================
-- TIMES (CLIENT BLOQUEADO)
-- =========================

function MatchModule.CreateTeam(player1, player2)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para criar times.")
		return
	end

	MatchBindableEvent:Fire("CreateTeam", {
		Player1 = player1,
		Player2 = player2
	})
end

function MatchModule.CreateTeamNPlayers(players: {Player})
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para criar times.")
		return
	end

	MatchBindableEvent:Fire('CreateTeam', {
		Players = players
	})
end

function MatchModule.RemoveTeam(player1, player2)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para remover times.")
		return
	end

	MatchBindableEvent:Fire("RemoveTeam", {
		Player1 = player1,
		Player2 = player2
	})
end

function MatchModule.RemoveTeamByPlayer(player)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para remover times.")
		return
	end

	MatchBindableEvent:Fire("RemoveTeamByPlayer", {
		Player = player
	})
end

function MatchModule.UpdateMatchPlayersCurrentRound(player)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para remover times.")
		return
	end

	MatchBindableEvent:Fire("UpdateMatchPlayersCurrentRound", {
		Player = player
	})
end

function MatchModule.UpdateMatchTeamsCurrentRound(player1, player2)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para remover times.")
		return
	end

	MatchBindableEvent:Fire("UpdateMatchTeamsCurrentRound", {
		Player1 = player1,
		Player2 = player2
	})
end

--- (NOVO) Avança o round da match pelo player — funciona para 1v1 e NvN.
function MatchModule.UpdateMatchRoundByPlayer(player)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para atualizar rounds.")
		return
	end

	MatchBindableEvent:Fire("UpdateMatchRoundByPlayer", {
		Player = player
	})
end

function MatchModule.UpdateBurstBar(player, percentage)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para atualizar a barra de burst.")
		return
	end

	MatchBindableEvent:Fire("UpdateBurstBar", {
		Player = player,
		Percentage = percentage
	})
end

function MatchModule.UpdateUltBar(player, percentage)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para atualizar a barra de burst.")
		return
	end

	MatchBindableEvent:Fire("UpdateUltBar", {
		Player = player,
		Percentage = percentage
	})
end

function MatchModule.UpdateStaminaBar(player, percentage)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para atualizar a barra de burst.")
		return
	end

	MatchBindableEvent:Fire("UpdateStaminaBar", {
		Player = player,
		Percentage = percentage
	})
end

-- =========================
-- RESET TIMER (SERVER ONLY)
-- =========================

--- Reseta o timer da match 1v1 pelos dois players.
function MatchModule.ResetMatchTimerPlayers(player1, player2)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para resetar o timer.")
		return
	end
	MatchBindableEvent:Fire("ResetMatchTimerPlayers", {
		Player1 = player1,
		Player2 = player2,
	})
end

--- Reseta o timer da match pelo player — funciona para 1v1 e NvN.
function MatchModule.ResetMatchTimerByPlayer(player)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para resetar o timer.")
		return
	end
	MatchBindableEvent:Fire("ResetMatchTimer", {
		Player = player,
	})
end

--- Reseta o timer da match NvN pelos dois times.
function MatchModule.ResetMatchTimerTeams(team1, team2)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para resetar o timer.")
		return
	end
	MatchBindableEvent:Fire("ResetMatchTimerTeams", {
		Team1 = team1,
		Team2 = team2,
	})
end

-- =========================
-- PAUSE TIMER (SERVER ONLY)
-- =========================

--- Pausa o decremento do timer da match daquele player por `duration` segundos.
function MatchModule.PauseMatchTimer(player, duration)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para pausar o timer.")
		return
	end
	MatchBindableEvent:Fire("PauseMatchTimer", {
		Player   = player,
		Duration = duration,
	})
end

-- =========================
-- PARTIDAS OFFLINE
-- =========================

if isServer() then
	function MatchModule.StartOffline1v1Match(player, map)
		MatchBindableEvent:Fire("StartOffline1v1Match", {
			Player = player,
			Map = map
		})
	end
else
	function MatchModule.StartOffline1v1Match(map)
		local localPlayer = Players.LocalPlayer

		MatchRemoteEvent:FireServer("StartOffline1v1Match", {
			Player = localPlayer,
			Map = map
		})
	end
end

function MatchModule.StartOffline2v2Match(team)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para iniciar 2v2 offline.")
		return
	end

	MatchBindableEvent:Fire("StartOffline2v2Match", {
		Team = team
	})
end

-- =========================
-- PARTIDAS ONLINE (CLIENT BLOQUEADO)
-- =========================

function MatchModule.SetMatchReady(player)
	if isServer() then
		MatchBindableEvent:Fire("SetMatchReady", { Player = player })
	else
		MatchRemoteEvent:FireServer("SetMatchReady", { Player = player })
	end
end

function MatchModule.Start1v1Match(player1, player2, map)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para iniciar 1v1 online.")
		return
	end

	MatchBindableEvent:Fire("Start1v1Match", {
		Player1 = player1,
		Player2 = player2,
		Map = map
	})
end

function MatchModule.Start2v2Match(team1, team2, map)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para iniciar 2v2 online.")
		return
	end

	print('FIRING 2v2')
	MatchBindableEvent:Fire("Start2v2Match", {
		Team1 = team1,
		Team2 = team2,
		Map = map
	})
end

function MatchModule.Stop2v2Match(team1, team2)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para terminar 2v2 online.")
		return
	end

	print('FIRING 2v2')
	MatchBindableEvent:Fire("Stop2v2Match", {
		Team1 = team1,
		Team2 = team2
	})
end

function MatchModule.Stop1v1Match(player1, player2)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para terminar 2v2 online.")
		return
	end

	print('FIRING 1v1')
	MatchBindableEvent:Fire("Stop1v1Match", {
		Player1 = player1,
		Player2 = player2
	})
end

-- =========================
-- STOP — POR PLAYER (NOVO)
-- =========================

--- Para a match (1v1 ou NvN) de um player, sem precisar do parceiro/time completo.
function MatchModule.StopMatchByPlayer(player)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para terminar matches.")
		return
	end

	MatchBindableEvent:Fire("StopMatchByPlayer", {
		Player = player
	})
end

--- Marca um player como morto dentro da sua match NvN.
function MatchModule.SetPlayerDead(player)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para alterar estado de vida.")
		return
	end

	MatchBindableEvent:Fire("SetPlayerDead", {
		Player = player
	})
end

--- Marca um player como vivo dentro da sua match NvN (ex: revival/round reset).
function MatchModule.SetPlayerAlive(player)
	if not isServer() then
		warn("[MatchModule] Client não tem permissão para alterar estado de vida.")
		return
	end

	MatchBindableEvent:Fire("SetPlayerAlive", {
		Player = player
	})
end

return MatchModule