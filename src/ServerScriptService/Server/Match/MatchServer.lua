local module = {}

----------------- TYPES -----------------

type Team = {
	Players         : {Player},
	Player1         : Player,
	Player2         : Player,
	PlayerN         : Player,
	PlayersAlive    : {[Player]: boolean},
	Player1Alive    : boolean,
	Player2Alive    : boolean,
	Size            : number,
}

type MatchPlayers = {
	Player1       : Player,
	Player2       : Player,
	ArenaID       : number,
	TimeLeft      : number,
	CurrentRound  : number,
	Ready         : boolean,
}

type MatchTeams = {
	Team1         : Team,
	Team2         : Team,
	ArenaID       : number,
	TimeLeft      : number,
	CurrentRound  : number,
	Ready         : boolean,
	TeamSize      : number,
}

----------------- SERVICES -----------------

local RunService = game:GetService("RunService")

----------------- GLOBAL STORAGE -----------------
local ActiveTeams    = {}
local InMatchPlayers = {}
local InMatchTeams   = {}

-- FIX: índices para lookup O(1) em vez de loops O(n)
local PlayerToMatch  = {}  -- [player] = match (Players ou Teams)
local PlayerToStatus = {}  -- [player] = "InMatchPlayers" | "InMatchTeams" | "ActiveTeams"
local TeamIndex      = {}  -- chave = hash do time, value = team

----------------- EVENTS -----------------
local MatchRemoteEvent      = game.ReplicatedStorage.Events.Match.MatchRemoteEvent
local MatchRemoteFunction   = game.ReplicatedStorage.Events.Match.MatchRemoteFunction
local MatchBindableEvent    = game.ReplicatedStorage.Events.Match.MatchBindableEvent
local MatchBindableFunction = game.ReplicatedStorage.Events.Match.MatchBindableFunction
local MatchUIInteractions   = game.ReplicatedStorage.Events.Match.MatchUIInteractions

----------------- MODULES -----------------
local MatchInteractionsManager = require(script.Parent.MatchInteractions)
local NotificationModule       = require(game.ReplicatedStorage.Modules.NotificationModule)

----------------- CONSTS -----------------
local MatchTime        = 90
local OfflineMatchTime = 999

-- FIX: throttle da stamina — só envia se mudou pelo menos 1 ponto percentual
local StaminaLastSent = {}  -- [player] = last percentage sent (integer)

-- ============================================================
-- TEAM HELPERS
-- ============================================================

local function RebuildTeamAliases(team)
	for i, p in ipairs(team.Players) do
		team["Player" .. i] = p
	end
	for i, p in ipairs(team.Players) do
		team["Player" .. i .. "Alive"] = team.PlayersAlive[p]
	end
end

local function SetPlayerAliveInternal(team, player, alive: boolean)
	team.PlayersAlive[player] = alive
	for i, p in ipairs(team.Players) do
		if p == player then
			team["Player" .. i .. "Alive"] = alive
			break
		end
	end
end

local function GetAlivePlayers(team): {any}
	local alive = {}
	for _, p in ipairs(team.Players) do
		if team.PlayersAlive[p] then
			table.insert(alive, p)
		end
	end
	return alive
end

local function TeamHasAlive(team): boolean
	return #GetAlivePlayers(team) > 0
end

-- ============================================================
-- TYPE FACTORY FUNCTIONS
-- ============================================================

local function CreateTeam(...)
	local args = { ... }
	local team = {
		Players      = {},
		PlayersAlive = {},
		Size         = 0,
	}
	for i, p in ipairs(args) do
		team.Players[i]               = p
		team.PlayersAlive[p]          = true
		team["Player" .. i]           = p
		team["Player" .. i .. "Alive"] = true
	end
	team.Size = #args
	return team
end

local function CreateMatchPlayers(Player1, Player2, TimeLeft, ArenaID)
	local newMatch = {}
	newMatch.Player1      = Player1
	newMatch.Player2      = Player2
	newMatch.TimeLeft     = TimeLeft or MatchTime
	newMatch.ArenaID      = ArenaID
	newMatch.CurrentRound = 1
	newMatch.Ready        = false
	newMatch.IsOffline    = false
	return newMatch
end

local function CreateMatchTeams(Team1, Team2, TimeLeft, ArenaID)
	local newMatch = {}
	newMatch.Team1        = Team1
	newMatch.Team2        = Team2
	newMatch.TimeLeft     = TimeLeft or MatchTime
	newMatch.ArenaID      = ArenaID
	newMatch.CurrentRound = 1
	newMatch.Ready        = false
	newMatch.TeamSize     = Team1.Size
	return newMatch
end

-- ============================================================
-- FIX: ÍNDICE RÁPIDO — atualiza lookup tables ao inserir/remover
-- ============================================================

local function IndexMatchPlayers(match)
	if match.Player1 then
		PlayerToMatch[match.Player1]  = match
		PlayerToStatus[match.Player1] = "InMatchPlayers"
	end
	if match.Player2 then
		PlayerToMatch[match.Player2]  = match
		PlayerToStatus[match.Player2] = "InMatchPlayers"
	end
end

local function UnindexMatchPlayers(match)
	if match.Player1 then
		PlayerToMatch[match.Player1]  = nil
		PlayerToStatus[match.Player1] = nil
	end
	if match.Player2 then
		PlayerToMatch[match.Player2]  = nil
		PlayerToStatus[match.Player2] = nil
	end
end

local function IndexMatchTeams(match)
	for _, team in ipairs({ match.Team1, match.Team2 }) do
		for _, p in ipairs(team.Players) do
			PlayerToMatch[p]  = match
			PlayerToStatus[p] = "InMatchTeams"
		end
	end
end

local function UnindexMatchTeams(match)
	for _, team in ipairs({ match.Team1, match.Team2 }) do
		for _, p in ipairs(team.Players) do
			PlayerToMatch[p]  = nil
			PlayerToStatus[p] = nil
		end
	end
end

local function IndexActiveTeam(team)
	for _, p in ipairs(team.Players) do
		PlayerToStatus[p] = "ActiveTeams"
	end
end

local function UnindexActiveTeam(team)
	for _, p in ipairs(team.Players) do
		if PlayerToStatus[p] == "ActiveTeams" then
			PlayerToStatus[p] = nil
		end
	end
end

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

-- FIX: FindPlayer agora é O(1) via lookup table
local function FindPlayer(plr)
	local player
	if typeof(plr) == 'string' then
		player = game.Players:FindFirstChild(plr)
	elseif typeof(plr) == 'Instance' and plr:IsA('Player') then
		player = plr
	end
	if not player then return nil end

	local status = PlayerToStatus[player]
	if status then return status end

	-- Fallback: verifica se é FreePlayer
	for _, freePlr in ipairs(game.Players:GetPlayers()) do
		if freePlr == player then return "FreePlayer" end
	end
	return nil
end

local function SameTeam(team, ...)
	local args = { ... }
	local checkList
	if type(args[1]) == 'table' and args[1].Players then
		checkList = args[1].Players
	else
		checkList = args
	end
	if #team.Players ~= #checkList then return false end
	local function nameOf(p)
		if typeof(p) == 'Instance' then return p.Name end
		return tostring(p)
	end
	local teamNames = {}
	for _, p in ipairs(team.Players) do teamNames[nameOf(p)] = true end
	for _, p in ipairs(checkList) do
		if not teamNames[nameOf(p)] then return false end
	end
	return true
end

local function FindTeam(...)
	local args = { ... }
	local inActive  = false
	local inMatch   = false
	local foundTeam = nil

	for _, team in ipairs(ActiveTeams) do
		if SameTeam(team, table.unpack(args)) then
			inActive  = true
			foundTeam = team
			break
		end
	end
	if not inActive then return nil end

	for _, match in ipairs(InMatchTeams) do
		if SameTeam(match.Team1, table.unpack(args))
			or SameTeam(match.Team2, table.unpack(args)) then
			inMatch = true
			break
		end
	end

	return {
		Status = inMatch and "ActiveAndInMatch" or "ActiveOnly",
		Team   = foundTeam,
	}
end

local function FindPlayersTeam(playerName: string)
	local player = game.Players:FindFirstChild(playerName)
	if not player then return nil end

	local foundTeam  = nil
	local inMatch    = false
	local foundMatch = nil

	for _, team in ipairs(ActiveTeams) do
		for _, p in ipairs(team.Players) do
			if p.Name == playerName then foundTeam = team; break end
		end
		if foundTeam then break end
	end

	if not foundTeam then
		for _, match in ipairs(InMatchTeams) do
			for _, team in ipairs({ match.Team1, match.Team2 }) do
				for _, p in ipairs(team.Players) do
					if p.Name == playerName then foundTeam = team; break end
				end
				if foundTeam then break end
			end
			if foundTeam then break end
		end
	end

	if not foundTeam then return nil end

	for _, match in ipairs(InMatchTeams) do
		if SameTeam(match.Team1, foundTeam) or SameTeam(match.Team2, foundTeam) then
			inMatch    = true
			foundMatch = match
			break
		end
	end

	if inMatch then
		return { Status = "ActiveAndInMatch", Team = foundTeam, Match = foundMatch }
	else
		return { Status = "ActiveOnly", Team = foundTeam }
	end
end

-- ============================================================
-- HELPER FUNCTIONS — POR PLAYER (FIX: O(1) via lookup)
-- ============================================================

local function ResolvePlayer(plr)
	if typeof(plr) == 'string' then
		return game.Players:FindFirstChild(plr)
	elseif typeof(plr) == 'Instance' and plr:IsA('Player') then
		return plr
	end
	return nil
end

local function GetPlayerMatchPlayers(player)
	local resolved = ResolvePlayer(player)
	if not resolved then return nil end
	local match = PlayerToMatch[resolved]
	if match and match.Player1 ~= nil then  -- é um match de Players (tem Player1/Player2 direto)
		if match.Player1 == resolved or match.Player2 == resolved then
			return match
		end
	end
	return nil
end

local function GetPlayerMatchTeams(player)
	local resolved = ResolvePlayer(player)
	if not resolved then return nil end
	local match = PlayerToMatch[resolved]
	if not match then return nil end
	-- Verifica se é match de Teams (tem Team1/Team2)
	if not match.Team1 then return nil end

	for _, p in ipairs(match.Team1.Players) do
		if p == resolved then
			return { Match = match, PlayerTeam = match.Team1, EnemyTeam = match.Team2 }
		end
	end
	for _, p in ipairs(match.Team2.Players) do
		if p == resolved then
			return { Match = match, PlayerTeam = match.Team2, EnemyTeam = match.Team1 }
		end
	end
	return nil
end

local function GetPlayerMatch(playerName: string)
	local player = game.Players:FindFirstChild(playerName)
	if not player then return nil end

	local matchPlayers = GetPlayerMatchPlayers(player)
	if matchPlayers then return { Type = "Players", Match = matchPlayers } end

	local matchTeams = GetPlayerMatchTeams(player)
	if matchTeams then return { Type = "Teams", Match = matchTeams.Match } end

	return nil
end

local function GetPlayerTeam(playerName: string)
	return FindPlayersTeam(playerName)
end

local function IsPlayerAlive(playerName: string)
	local player = game.Players:FindFirstChild(playerName)
	if not player then return nil end
	local info = GetPlayerMatchTeams(player)
	if not info then return nil end
	return info.PlayerTeam.PlayersAlive[player] == true
end

local function GetPlayerEnemyTeam(playerName: string)
	local player = game.Players:FindFirstChild(playerName)
	if not player then return nil end
	local info = GetPlayerMatchTeams(player)
	if not info then return nil end
	return info.EnemyTeam
end

local function GetPlayer1v1Opponent(playerName: string)
	local player = game.Players:FindFirstChild(playerName)
	if not player then return nil end
	local match = GetPlayerMatchPlayers(player)
	if not match then return nil end
	if match.Player1 == player then return match.Player2 end
	return match.Player1
end

-- ============================================================
-- UTILS
-- ============================================================

local function RemoveMatchPlayer(playerName: string)
	for i, match in ipairs(InMatchPlayers) do
		if (match.Player1 and match.Player1.Name == playerName)
			or (match.Player2 and match.Player2.Name == playerName) then
			UnindexMatchPlayers(match)
			table.remove(InMatchPlayers, i)
			return true
		end
	end
	return false
end

local function RemoveMatchTeam(...)
	local args = { ... }
	for i, match in ipairs(InMatchTeams) do
		if SameTeam(match.Team1, table.unpack(args))
			or SameTeam(match.Team2, table.unpack(args)) then
			UnindexMatchTeams(match)
			table.remove(InMatchTeams, i)
			return true
		end
	end
	return false
end

local function UpdateMatchTeamsCurrentRound(...)
	local args = { ... }
	for _, match in ipairs(InMatchTeams) do
		if SameTeam(match.Team1, table.unpack(args))
			or SameTeam(match.Team2, table.unpack(args)) then
			match.CurrentRound += 1
			return true
		end
	end
	return false
end

local function UpdateMatchPlayersCurrentRound(player)
	for _, match in ipairs(InMatchPlayers) do
		if match.Player1 == player or match.Player2 == player then
			match.CurrentRound += 1
			return true
		end
	end
	return false
end

local function UpdateMatchRoundByPlayer(player)
	if UpdateMatchPlayersCurrentRound(player) then return true end
	local info = GetPlayerMatchTeams(player)
	if info then info.Match.CurrentRound += 1; return true end
	return false
end

local function SetMatchReady(player)
	local match = PlayerToMatch[player]
	if match then match.Ready = true; return end
end

-- ============================================================
-- ROUND TIMER RESET
-- ============================================================

local function ResetMatchTimer(player)
	local match1v1 = GetPlayerMatchPlayers(player)
	if match1v1 then match1v1.TimeLeft = MatchTime; return true end
	local infoNvN = GetPlayerMatchTeams(player)
	if infoNvN then infoNvN.Match.TimeLeft = MatchTime; return true end
	return false
end

local function ResetMatchTimerTeams(team1, team2)
	for _, match in ipairs(InMatchTeams) do
		if (SameTeam(match.Team1, team1) and SameTeam(match.Team2, team2))
			or (SameTeam(match.Team1, team2) and SameTeam(match.Team2, team1)) then
			match.TimeLeft = MatchTime
			return true
		end
	end
	return false
end

local function ResetMatchTimerPlayers(player1, player2)
	for _, match in ipairs(InMatchPlayers) do
		if (match.Player1 == player1 and match.Player2 == player2)
			or (match.Player1 == player2 and match.Player2 == player1) then
			match.TimeLeft = MatchTime
			return true
		end
	end
	return false
end

-- ============================================================
-- PAUSE TIMER
-- ============================================================

local function PauseMatchTimer(player, duration)
	local pauseUntil = os.clock() + duration

	local match1v1 = GetPlayerMatchPlayers(player)
	if match1v1 then
		match1v1.PausedUntil = pauseUntil
		return true
	end

	local infoNvN = GetPlayerMatchTeams(player)
	if infoNvN then
		infoNvN.Match.PausedUntil = pauseUntil
		return true
	end

	return false
end

-- ============================================================
-- START MATCHES
-- ============================================================

local function StartOffline1v1Match(Player, Map)
	if FindPlayer(Player.Name) ~= 'FreePlayer' then return end
	local ArenaID = MatchInteractionsManager.StartMatch('Offline1v1', { Player = Player, Map = Map })
	local newMatch = CreateMatchPlayers(Player, nil, OfflineMatchTime, ArenaID) -- passa ArenaID
	newMatch.IsOffline = true
	table.insert(InMatchPlayers, newMatch)
	IndexMatchPlayers(newMatch)
end

local function Start1v1Match(player1, player2, Map)
	if FindPlayer(player1.Name) ~= 'FreePlayer' then return end
	if FindPlayer(player2.Name) ~= 'FreePlayer' then return end
	local ArenaID  = MatchInteractionsManager.StartMatch('Online1v1', { Player1 = player1, Player2 = player2, Map = Map })
	local newMatch = CreateMatchPlayers(player1, player2, MatchTime, ArenaID)
	table.insert(InMatchPlayers, newMatch)
	IndexMatchPlayers(newMatch)
end

local function StartOffline2v2Match(team)
	local found = FindTeam(table.unpack(team.Players))
	if not found or found.Status ~= 'ActiveOnly' then return end
	local botTeam  = CreateTeam()
	local newMatch = CreateMatchTeams(team, botTeam, OfflineMatchTime)
	newMatch.IsOffline = true
	table.insert(InMatchTeams, newMatch)
	IndexMatchTeams(newMatch)
end

local function StartNvNMatch(team1, team2, map, matchType)
	matchType = matchType or 'Online2v2'
	local found1 = FindTeam(table.unpack(team1.Players))
	if not found1 or found1.Status ~= 'ActiveOnly' then warn('TEAM 1 IS NOT ACTIVE'); return end
	local found2 = FindTeam(table.unpack(team2.Players))
	if not found2 or found2.Status ~= 'ActiveOnly' then warn('TEAM 2 IS NOT ACTIVE'); return end
	local ArenaID  = MatchInteractionsManager.StartMatch(matchType, { Team1 = team1, Team2 = team2, Map = map })
	local newMatch = CreateMatchTeams(team1, team2, MatchTime, ArenaID)
	table.insert(InMatchTeams, newMatch)
	IndexMatchTeams(newMatch)
end

local function Start2v2Match(team1, team2, map) StartNvNMatch(team1, team2, map, 'Online2v2') end
local function Start3v3Match(team1, team2, map) StartNvNMatch(team1, team2, map, 'Online3v3') end
local function Start4v4Match(team1, team2, map) StartNvNMatch(team1, team2, map, 'Online4v4') end
local function Start5v5Match(team1, team2, map) StartNvNMatch(team1, team2, map, 'Online5v5') end

-- ============================================================
-- UI HELPERS
-- FIX: BroadcastBarUpdate otimizado — sem loop duplo, sem FindPlayer dentro
-- ============================================================

local function BroadcastBarUpdate(player, percentage, eventSelf, eventEnemy)
	-- Tenta 1v1 primeiro via lookup O(1)
	local match = PlayerToMatch[player]
	if match and match.Player1 ~= nil and match.Team1 == nil then
		-- é match de Players
		MatchUIInteractions:FireClient(player, eventSelf, { Percentage = percentage })
		local opponent = (match.Player1 == player) and match.Player2 or match.Player1
		if opponent then
			MatchUIInteractions:FireClient(opponent, eventEnemy, { Percentage = percentage })
		end
		return
	end

	-- NvN via lookup O(1)
	if match and match.Team1 then
		local playerTeam, enemyTeam
		for _, p in ipairs(match.Team1.Players) do
			if p == player then playerTeam = match.Team1; enemyTeam = match.Team2; break end
		end
		if not playerTeam then
			for _, p in ipairs(match.Team2.Players) do
				if p == player then playerTeam = match.Team2; enemyTeam = match.Team1; break end
			end
		end
		if playerTeam then
			for _, p in ipairs(playerTeam.Players) do
				MatchUIInteractions:FireClient(p, eventSelf, { Percentage = percentage })
			end
			if enemyTeam then
				for _, p in ipairs(enemyTeam.Players) do
					MatchUIInteractions:FireClient(p, eventEnemy, { Percentage = percentage })
				end
			end
		end
	end
end

local function UpdateBurstBar(player, percentage)
	if FindPlayer(player.Name) == 'FreePlayer' then return end
	BroadcastBarUpdate(player, percentage, 'UpdatePlayer1BurstBar', 'UpdatePlayer2BurstBar')
end

local function UpdateUltBar(player, percentage)
	if FindPlayer(player.Name) == 'FreePlayer' then return end
	BroadcastBarUpdate(player, percentage, 'UpdatePlayer1UltBar', 'UpdatePlayer2UltBar')
end

-- FIX: throttle de stamina — só envia se mudou pelo menos 1 ponto inteiro
-- Isso elimina dezenas de FireClient por segundo durante a regen
local function UpdateStaminaBar(player, percentage)
	local rounded = math.floor(percentage)
	local last = StaminaLastSent[player]
	if last == rounded then return end  -- não mudou, ignora
	StaminaLastSent[player] = rounded

	if FindPlayer(player.Name) == 'FreePlayer' then
		MatchUIInteractions:FireClient(player, 'UpdatePlayer1StaminaBar', { Percentage = rounded })
		return
	end
	BroadcastBarUpdate(player, rounded, 'UpdatePlayer1StaminaBar', 'UpdatePlayer2StaminaBar')
end

-- ============================================================
-- STOP MATCHES
-- ============================================================

local function StopOffline1v1Match(playerName: string)
	return RemoveMatchPlayer(playerName)
end

local function StopOffline2v2Match(team)
	return RemoveMatchTeam(table.unpack(team.Players))
end

local function Stop1v1Match(player1, player2)
	warn('STOP 1v1 MATCH')
	for i, match in ipairs(InMatchPlayers) do
		if (match.Player1 == player1 and match.Player2 == player2)
			or (match.Player1 == player2 and match.Player2 == player1) then
			warn('STOP 1v1 MATCH ACCEPTED')
			UnindexMatchPlayers(match)
			MatchInteractionsManager.Stop1v1Match(player1, player2, match.ArenaID)
			table.remove(InMatchPlayers, i)
			-- Limpa throttle de stamina
			if player1 then StaminaLastSent[player1] = nil end
			if player2 then StaminaLastSent[player2] = nil end
			return true
		end
	end
	return false
end

local function Stop2v2Match(team1, team2)
	print('stop 2v2 function')
	for i, match in ipairs(InMatchTeams) do
		if (SameTeam(match.Team1, team1) and SameTeam(match.Team2, team2))
			or (SameTeam(match.Team1, team2) and SameTeam(match.Team2, team1)) then
			print('stop 2v2 match interactions trigger')
			UnindexMatchTeams(match)
			MatchInteractionsManager.Stop2v2Match(team1, team2, match.ArenaID)
			table.remove(InMatchTeams, i)
			-- Limpa throttle de stamina
			for _, team in ipairs({ team1, team2 }) do
				for _, p in ipairs(team.Players) do
					StaminaLastSent[p] = nil
				end
			end
			return true
		end
	end
	return false
end

local function StopNvNMatch(team1, team2)
	return Stop2v2Match(team1, team2)
end

local function StopMatchByPlayer(player)
	local match1v1 = GetPlayerMatchPlayers(player)
	if match1v1 then return Stop1v1Match(match1v1.Player1, match1v1.Player2) end
	local infoNvN = GetPlayerMatchTeams(player)
	if infoNvN then return Stop2v2Match(infoNvN.Match.Team1, infoNvN.Match.Team2) end
	warn("[MatchServer] StopMatchByPlayer: player não está em nenhuma match.")
	return false
end

local function SetPlayerDeadInMatch(player)
	local info = GetPlayerMatchTeams(player)
	if not info then warn("[MatchServer] SetPlayerDead: player não está em match NvN."); return false end
	SetPlayerAliveInternal(info.PlayerTeam, player, false)
	return true
end

local function SetPlayerAliveInMatch(player)
	local info = GetPlayerMatchTeams(player)
	if not info then warn("[MatchServer] SetPlayerAlive: player não está em match NvN."); return false end
	SetPlayerAliveInternal(info.PlayerTeam, player, true)
	return true
end

-- ============================================================
-- TEAM MANAGEMENT
-- ============================================================

local function CreateAndInsertTeam(...)
	local args = { ... }
	local newTeam = CreateTeam(table.unpack(args))
	table.insert(ActiveTeams, newTeam)
	IndexActiveTeam(newTeam)
end

local function RemoveTeam(...)
	local args = { ... }
	for i, team in ipairs(ActiveTeams) do
		if SameTeam(team, table.unpack(args)) then
			UnindexActiveTeam(team)
			table.remove(ActiveTeams, i)
			break
		end
	end
end

local function RemoveTeamByPlayer(player)
	local playerName = typeof(player) == 'Instance' and player.Name or tostring(player)
	local teamInfo = FindPlayersTeam(playerName)
	if not teamInfo then
		warn("[MatchServer] RemoveTeamByPlayer: nenhum time encontrado para " .. playerName)
		return false
	end
	RemoveTeam(table.unpack(teamInfo.Team.Players))
	return true
end

-- ============================================================
-- TEAM MEMBER MANAGEMENT
-- ============================================================

local function AddPlayerToTeam(team, player)
	if not team or not player then return false, "Team or player is nil" end
	if team.Size >= 5 then return false, "Team is full (max 5 players)" end
	for _, p in ipairs(team.Players) do
		if p == player then return false, "Player is already on this team" end
	end
	local playerState = FindPlayer(player)
	if playerState ~= "FreePlayer" then
		return false, "Player is not free (state: " .. tostring(playerState) .. ")"
	end
	local slot = team.Size + 1
	team.Players[slot]                = player
	team.PlayersAlive[player]         = true
	team["Player" .. slot]            = player
	team["Player" .. slot .. "Alive"] = true
	team.Size                         = slot
	return true
end

local function RemovePlayerFromTeam(team, player)
	if not team or not player then return false, "Team or player is nil" end
	for _, match in ipairs(InMatchTeams) do
		if SameTeam(match.Team1, table.unpack(team.Players))
			or SameTeam(match.Team2, table.unpack(team.Players)) then
			return false, "Cannot remove player while team is in a match"
		end
	end
	local found = false
	for i, p in ipairs(team.Players) do
		if p == player then table.remove(team.Players, i); found = true; break end
	end
	if not found then return false, "Player is not on this team" end
	team.PlayersAlive[player] = nil
	for i = 1, team.Size do
		team["Player" .. i]            = nil
		team["Player" .. i .. "Alive"] = nil
	end
	team.Size = #team.Players
	RebuildTeamAliases(team)
	return true
end

-- ============================================================
-- EVENT ROUTER
-- ============================================================

local function EventActions(action, args)
	if action == 'CreateTeam' then
		if args.Players then CreateAndInsertTeam(table.unpack(args.Players))
		else CreateAndInsertTeam(args.Player1, args.Player2) end
	end
	if action == 'RemoveTeam' then
		if args.Players then RemoveTeam(table.unpack(args.Players))
		else RemoveTeam(args.Player1, args.Player2) end
	end
	if action == 'RemoveTeamByPlayer' then RemoveTeamByPlayer(args.Player) end
	if action == 'StartOffline1v1Match' then StartOffline1v1Match(args.Player, args.Map) end
	if action == 'StartOffline2v2Match' then StartOffline2v2Match(args.Team) end
	if action == 'Start1v1Match' then Start1v1Match(args.Player1, args.Player2, args.Map) end
	if action == 'Start2v2Match' then StartNvNMatch(args.Team1, args.Team2, args.Map, 'Online2v2') end
	if action == 'Start3v3Match' then StartNvNMatch(args.Team1, args.Team2, args.Map, 'Online3v3') end
	if action == 'Start4v4Match' then StartNvNMatch(args.Team1, args.Team2, args.Map, 'Online4v4') end
	if action == 'Start5v5Match' then StartNvNMatch(args.Team1, args.Team2, args.Map, 'Online5v5') end
	if action == 'StopOffline1v1Match' then StopOffline1v1Match(args.Player) end
	if action == 'Stop1v1Match'        then Stop1v1Match(args.Player1, args.Player2) end
	if action == 'StopOffline2v2Match' then StopOffline2v2Match(args.Team) end
	if action == 'Stop2v2Match'        then Stop2v2Match(args.Team1, args.Team2) end
	if action == 'StopNvNMatch'        then StopNvNMatch(args.Team1, args.Team2) end
	if action == 'StopMatchByPlayer'   then StopMatchByPlayer(args.Player) end
	if action == 'UpdateBurstBar'      then UpdateBurstBar(args.Player, args.Percentage) end
	if action == 'UpdateUltBar'        then UpdateUltBar(args.Player, args.Percentage) end
	if action == 'UpdateStaminaBar'    then UpdateStaminaBar(args.Player, args.Percentage) end
	if action == 'UpdateMatchTeamsCurrentRound' then
		if args.Players then UpdateMatchTeamsCurrentRound(table.unpack(args.Players))
		else UpdateMatchTeamsCurrentRound(args.Player1, args.Player2) end
	end
	if action == 'UpdateMatchPlayersCurrentRound' then UpdateMatchPlayersCurrentRound(args.Player) end
	if action == 'UpdateMatchRoundByPlayer'       then UpdateMatchRoundByPlayer(args.Player) end
	if action == 'SetMatchReady'                  then SetMatchReady(args.Player) end
	if action == 'SetPlayerDead'                  then SetPlayerDeadInMatch(args.Player) end
	if action == 'SetPlayerAlive'                 then SetPlayerAliveInMatch(args.Player) end
	if action == 'ResetMatchTimer'                then ResetMatchTimer(args.Player) end
	if action == 'ResetMatchTimerPlayers'         then ResetMatchTimerPlayers(args.Player1, args.Player2) end
	if action == 'ResetMatchTimerTeams'           then ResetMatchTimerTeams(args.Team1, args.Team2) end
	if action == 'PauseMatchTimer' then PauseMatchTimer(args.Player, args.Duration) end
end

-- ============================================================
-- HANDLER DE QUERIES
-- ============================================================

local function HandleQuery(action, args)
	if action == 'GetActiveTeams'       then return ActiveTeams    end
	if action == 'GetInMatchPlayers'    then return InMatchPlayers end
	if action == 'GetInMatchTeams'      then return InMatchTeams   end
	if action == 'FindPlayer'           then return FindPlayer(args.PlayerName) end
	if action == 'FindPlayersTeam'      then return FindPlayersTeam(args.PlayerName) end
	if action == 'FindTeam' then
		if args.Players then return FindTeam(table.unpack(args.Players))
		else return FindTeam(args.Player1, args.Player2) end
	end
	if action == 'GetPlayerArena' then
		local player = game.Players:FindFirstChild(args.PlayerName)
		if not player then return nil end

		local match = PlayerToMatch[player]
		if not match then return nil end
		if not match.ArenaID then return nil end

		local arena = MatchInteractionsManager.GetArena(match.ArenaID)
		return arena and arena.Bounds or nil
	end
	if action == 'GetPlayerMatch'       then return GetPlayerMatch(args.PlayerName) end
	if action == 'GetPlayerTeam'        then return GetPlayerTeam(args.PlayerName) end
	if action == 'IsPlayerAlive'        then return IsPlayerAlive(args.PlayerName) end
	if action == 'GetPlayerEnemyTeam'   then return GetPlayerEnemyTeam(args.PlayerName) end
	if action == 'GetPlayer1v1Opponent' then return GetPlayer1v1Opponent(args.PlayerName) end
	return nil
end

-- ============================================================
-- EVENT CONNECTIONS
-- ============================================================

MatchRemoteEvent.OnServerEvent:Connect(function(player, action, args)
	EventActions(action, args)
end)
MatchRemoteFunction.OnServerInvoke = function(player, action, args)
	return HandleQuery(action, args)
end
MatchBindableEvent.Event:Connect(function(action, args)
	EventActions(action, args)
end)
MatchBindableFunction.OnInvoke = function(action, args)
	return HandleQuery(action, args)
end

-- ============================================================
-- PLAYER REMOVING
-- ============================================================
game.Players.PlayerRemoving:Connect(function(plr)
	StaminaLastSent[plr] = nil

	local playerState = PlayerToStatus[plr]
	if not playerState then return end

	if playerState == 'ActiveTeams' then
		-- Busca direto em ActiveTeams pela referência, sem usar o nome
		local foundTeam = nil
		for _, team in ipairs(ActiveTeams) do
			for _, member in ipairs(team.Players) do
				if member == plr then
					foundTeam = team
					break
				end
			end
			if foundTeam then break end
		end

		if not foundTeam then return end

		-- Salva membros antes de remover
		local members = {}
		for _, member in ipairs(foundTeam.Players) do
			table.insert(members, member)
		end

		RemoveTeam(table.unpack(members))

		for _, member in ipairs(members) do
			if member ~= plr and member.Parent then
				MatchRemoteEvent:FireClient(member, 'DisableQueue2v2')
				NotificationModule.SendMessageToClient(member, 'Your Team was Dismantled')
			end
		end

	elseif playerState == 'InMatchTeams' then
		local foundMatch = nil
		local foundTeam = nil
		for _, match in ipairs(InMatchTeams) do
			for _, team in ipairs({ match.Team1, match.Team2 }) do
				for _, member in ipairs(team.Players) do
					if member == plr then
						foundMatch = match
						foundTeam = team
						break
					end
				end
				if foundMatch then break end
			end
			if foundMatch then break end
		end

		if not foundMatch then return end

		local allMembers = {}
		for _, team in ipairs({ foundMatch.Team1, foundMatch.Team2 }) do
			for _, member in ipairs(team.Players) do
				table.insert(allMembers, member)
			end
		end

		Stop2v2Match(foundMatch.Team1, foundMatch.Team2)
		RemoveTeam(table.unpack(foundTeam.Players))

		for _, member in ipairs(allMembers) do
			if member ~= plr and member.Parent then
				NotificationModule.SendMessageToClient(member, plr.Name .. " left. The match has been cancelled.")
			end
		end

	elseif playerState == 'InMatchPlayers' then
		for _, match in ipairs(InMatchPlayers) do
			if match.Player1 == plr or match.Player2 == plr then
				local opponent = (match.Player1 == plr) and match.Player2 or match.Player1
				Stop1v1Match(match.Player1, match.Player2)
				if opponent and opponent.Parent then
					NotificationModule.SendMessageToClient(opponent, plr.Name .. " left. The match has been cancelled.")
				end
				break
			end
		end
	end
end)

-- ============================================================
-- HEARTBEAT — TIMER
-- FIX: separa o envio do timer (a cada 1s) do decremento (todo frame)
-- para não misturar lógica e evitar FireClient desnecessário
-- ============================================================

local elapsed = 0

RunService.Heartbeat:Connect(function(dt)
	elapsed += dt

	-- Envia timer para UI apenas 1x por segundo
	if elapsed >= 1 then
		elapsed = 0

		for _, match in pairs(InMatchTeams) do
			if match then
				local timeRounded = math.round(match.TimeLeft)
				for _, team in ipairs({ match.Team1, match.Team2 }) do
					for _, p in ipairs(team.Players) do
						if p and p.Parent then
							MatchUIInteractions:FireClient(p, 'UpdateTimer', { Time = timeRounded })
						end
					end
				end
			end
		end

		for _, players in pairs(InMatchPlayers) do
			if players then
				local timeRounded = math.round(players.TimeLeft)
				if players.Player1 then
					MatchUIInteractions:FireClient(players.Player1, 'UpdateTimer', { Time = timeRounded })
				end
				if players.Player2 then
					MatchUIInteractions:FireClient(players.Player2, 'UpdateTimer', { Time = timeRounded })
				end
			end
		end
	end

	-- Decrementa timer e trata timeout
	for _, match in pairs(InMatchTeams) do
		if not match.Ready then continue end
		if match.IsOffline then continue end
		if match.PausedUntil and os.clock() < match.PausedUntil then continue end
		match.TimeLeft -= dt
		if match.TimeLeft <= 0 then
			match.TimeLeft = 0
			match.Ready = false
			MatchInteractionsManager.HandleRoundTimeout_NvN(match.Team1, match.Team2, match.ArenaID)
		end
	end

	for _, players in pairs(InMatchPlayers) do
		if not players.Ready then continue end
		if players.IsOffline then continue end
		if players.PausedUntil and os.clock() < players.PausedUntil then continue end
		players.TimeLeft -= dt
		if players.TimeLeft <= 0 then
			players.TimeLeft = 0
			players.Ready = false
			MatchInteractionsManager.HandleRoundTimeout_1v1(players.Player1, players.Player2, players.ArenaID)
		end
	end
end)

-- ============================================================
-- EXPORTS PÚBLICOS (usados pelo MatchInteractions e outros módulos)
-- ============================================================
module.UpdateBurstBar                   = UpdateBurstBar
module.UpdateUltBar                     = UpdateUltBar
module.UpdateStaminaBar                 = UpdateStaminaBar
module.Stop1v1Match                     = Stop1v1Match
module.Stop2v2Match                     = Stop2v2Match
module.StopMatchByPlayer                = StopMatchByPlayer
module.SetMatchReady                    = SetMatchReady
module.ResetMatchTimer                  = ResetMatchTimer
module.ResetMatchTimerPlayers           = ResetMatchTimerPlayers
module.ResetMatchTimerTeams             = ResetMatchTimerTeams
module.UpdateMatchTeamsCurrentRound     = UpdateMatchTeamsCurrentRound
module.UpdateMatchPlayersCurrentRound   = UpdateMatchPlayersCurrentRound
module.UpdateMatchRoundByPlayer         = UpdateMatchRoundByPlayer
module.GetInMatchPlayers                = function() return InMatchPlayers end
module.GetInMatchTeams                  = function() return InMatchTeams end
module.GetActiveTeams                   = function() return ActiveTeams end
module.FindPlayer                       = FindPlayer
module.CreateTeam                       = CreateTeam
module.CreateAndInsertTeam              = CreateAndInsertTeam
module.RemoveTeam                       = RemoveTeam
module.RemoveTeamByPlayer               = RemoveTeamByPlayer
module.Start1v1Match                    = Start1v1Match
module.StartOffline1v1Match             = StartOffline1v1Match
module.StartNvNMatch                    = StartNvNMatch
module.SetPlayerDeadInMatch             = SetPlayerDeadInMatch
module.SetPlayerAliveInMatch            = SetPlayerAliveInMatch
module.PauseMatchTimer = PauseMatchTimer

return module