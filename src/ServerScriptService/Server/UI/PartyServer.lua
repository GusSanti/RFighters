-- =============================================================
-- PartyServer.lua
-- Party = time no MatchModule. Sem estado local de party.
-- Players[1] do time = owner.
-- Party com 1 player = sem time no MatchModule (player solo).
-- =============================================================

local PartyServer = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModule        = require(ReplicatedStorage.MatchSystem.MatchModule)
local MatchmakingModule  = require(ReplicatedStorage.MatchSystem.MatchmakingModule) -- ⚠️ ajuste o caminho
local NotificationModule = require(ReplicatedStorage.Modules.NotificationModule)

local PartyEvents = ReplicatedStorage.Events:WaitForChild("Party")
local PartyRemote = PartyEvents:WaitForChild("PartyRemoteEvent")
local PartyFunc   = PartyEvents:WaitForChild("PartyRemoteFunction")

local NotificationRemoteEvent = ReplicatedStorage.Events.Notification.NotificationRemoteEvents

local MAX_PARTY_SIZE = 5

-- =============================================================
-- Convites pendentes: pendingInvites[targetName] = ownerName
-- =============================================================
local pendingInvites = {}

-- =============================================================
-- Helpers — leitura do time via MatchModule
-- =============================================================

local function getTeamOf(player: Player)
	local info = MatchModule.FindPlayersTeam(player.Name)
	if not info then return nil end
	return info.Team
end

local function isOwner(player: Player): boolean
	local team = getTeamOf(player)
	if not team then return false end
	return team.Players[1] == player
end

local function getMembersOf(player: Player): { Player }
	local team = getTeamOf(player)
	if team then return team.Players end
	return { player }
end

local function partySize(player: Player): number
	return #getMembersOf(player)
end

-- =============================================================
-- Queue helpers
-- =============================================================

-- Retira o time inteiro da fila.
-- Deve ser chamado ANTES de qualquer rebuildTeam / dissolve,
-- pois após o rebuild o teamId já mudou.
local function leaveQueueIfInQueue(ownerPlayer: Player)
	-- O atributo TeamId fica em qualquer membro do time.
	-- Usamos o owner (Players[1]) como referência, mas basta um membro ter o atributo.
	local members = getMembersOf(ownerPlayer)
	for _, m in ipairs(members) do
		if m:GetAttribute("TeamId") then
			-- LeaveQueue lê o atributo do player passado e limpa todos no servidor
			MatchmakingModule.LeaveQueue(m)
			break
		end
	end
end

-- Notifica todos os membros sobre mudança no status da fila
local function broadcastQueueStatus(members: { Player }, inQueue: boolean)
	for _, plr in ipairs(members) do
		PartyRemote:FireClient(plr, "QueueStatus", { InQueue = inQueue })
	end
end

-- =============================================================
-- Helpers — broadcast de UI
-- =============================================================

local function broadcastPartyUpdate(members: { Player }, ownerPlayer: Player)
	local payload = { Members = {} }
	for i, plr in ipairs(members) do
		payload.Members[i] = {
			Name        = plr.Name,
			DisplayName = plr.DisplayName,
			UserId      = plr.UserId,
			IsOwner     = (plr == ownerPlayer),
		}
	end
	for _, plr in ipairs(members) do
		PartyRemote:FireClient(plr, "UpdateParty", payload)
	end
end

-- =============================================================
-- Helpers — rebuild de time no MatchModule
-- =============================================================

local function rebuildTeam(ownerPlayer: Player, newMembers: { Player })
	-- Sai da fila ANTES de dissolver o time (teamId ainda válido)
	leaveQueueIfInQueue(ownerPlayer)

	local state = MatchModule.FindPlayer(ownerPlayer.Name)
	if state == "ActiveTeams" then
		MatchModule.RemoveTeamByPlayer(ownerPlayer)
	end

	if #newMembers >= 2 then
		MatchModule.CreateTeamNPlayers(newMembers)
	end
end

-- =============================================================
-- Lobby list
-- =============================================================

local function sendLobbyListToClient(player: Player)
	local playerList = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p == player then continue end
		if MatchModule.FindPlayer(p.Name) ~= 'FreePlayer' then continue end
		table.insert(playerList, {
			Name        = p.Name,
			DisplayName = p.DisplayName,
			UserId      = p.UserId,
		})
	end
	print('update lobby list')
	PartyRemote:FireClient(player, "UpdateLobbyList", { Players = playerList })
end

-- =============================================================
-- Remoção de membro (LeaveParty, KickMember, PlayerRemoving)
-- =============================================================

local function removeMemberFromParty(player: Player)
	local team = getTeamOf(player)
	if not team then return end

	local owner   = team.Players[1]
	local members = { table.unpack(team.Players) }

	if player == owner then
		-- Owner saiu: sai da fila e dissolve a party inteira
		leaveQueueIfInQueue(owner)
		MatchModule.RemoveTeamByPlayer(owner)

		for _, m in ipairs(members) do
			if m ~= owner then
				PartyRemote:FireClient(m, "PartyDissolved", {})
				PartyRemote:FireClient(m, "QueueStatus", { InQueue = false })
				NotificationModule.SendMessageToClient(m, owner.Name .. " dissolveu a party.")
			end
		end

		-- Notifica o próprio owner para fechar a UI e limpar os slots
		PartyRemote:FireClient(owner, "PartyDissolved", {})
		PartyRemote:FireClient(owner, "QueueStatus", { InQueue = false })

		for _, p in ipairs(Players:GetPlayers()) do
			sendLobbyListToClient(p)
		end

		warn("[PartyServer] Party dissolvida — owner saiu:", owner.Name)
	else
		-- Membro saiu: sai da fila e rebuilda sem ele
		local newMembers = {}
		for _, m in ipairs(members) do
			if m ~= player then
				table.insert(newMembers, m)
			end
		end
		rebuildTeam(owner, newMembers)

		PartyRemote:FireClient(player, "PartyDissolved", {})
		PartyRemote:FireClient(player, "QueueStatus", { InQueue = false })
		broadcastPartyUpdate(newMembers, owner)

		-- Notifica os que ficaram que saíram da fila (precisam dar QueueUp de novo)
		if #newMembers > 0 then
			broadcastQueueStatus(newMembers, false)
			NotificationModule.SendMessageToClient(
				owner,
				player.Name .. " saiu — party removida da fila."
			)
		end

		for _, p in ipairs(Players:GetPlayers()) do
			sendLobbyListToClient(p)
		end

		warn("[PartyServer] Membro saiu da party:", player.Name)
	end
end

-- =============================================================
-- Handler principal de eventos
-- =============================================================

local function handleEvent(player: Player, action: string, args)
	args = args or {}

	-- ABRIR PARTY -----------------------------------------------
	if action == "CreateParty" then
		broadcastPartyUpdate({ player }, player)
		warn("[PartyServer] Party aberta por:", player.Name)

		-- PEDIR LISTA DO LOBBY --------------------------------------
	elseif action == "RequestLobbyList" then
		print('send lobby list to client')
		sendLobbyListToClient(player)

		-- QUEUE UP --------------------------------------------------
		-- Só o owner (ou player solo) pode colocar o time na fila.
	elseif action == "QueueUp" then
		-- Verifica se é owner ou solo
		local team = getTeamOf(player)
		if team and team.Players[1] ~= player then
			PartyRemote:FireClient(player, "Error", { Message = "Apenas o owner pode entrar na fila." })
			return
		end

		-- Verifica se já está na fila
		if player:GetAttribute("TeamId") then
			PartyRemote:FireClient(player, "Error", { Message = "Você já está na fila." })
			return
		end

		-- Verifica se está em partida
		local ownerState = MatchModule.FindPlayer(player.Name)
		if ownerState == "InMatchPlayers" or ownerState == "InMatchTeams" then
			PartyRemote:FireClient(player, "Error", { Message = "Você está em uma partida." })
			return
		end

		local members = getMembersOf(player)
		local teamId  = MatchmakingModule.EnterQueue(members)

		if teamId then
			broadcastQueueStatus(members, true)
			warn(("[PartyServer] %s colocou o time na fila (%d player(s)). TeamId: %s"):format(
				player.Name, #members, teamId:sub(1, 8)
				))
		else
			PartyRemote:FireClient(player, "Error", { Message = "Erro ao entrar na fila. Tente novamente." })
		end

		-- LEAVE QUEUE -----------------------------------------------
		-- Permite o owner cancelar a fila sem sair da party.
	elseif action == "LeaveQueue" then
		local team = getTeamOf(player)
		if team and team.Players[1] ~= player then
			PartyRemote:FireClient(player, "Error", { Message = "Apenas o owner pode sair da fila." })
			return
		end

		leaveQueueIfInQueue(player)

		local members = getMembersOf(player)
		broadcastQueueStatus(members, false)
		warn("[PartyServer]", player.Name, "cancelou a fila.")

		-- CONVIDAR JOGADOR ------------------------------------------
	elseif action == "InvitePlayer" then
		local team = getTeamOf(player)
		if team and team.Players[1] ~= player then
			PartyRemote:FireClient(player, "Error", { Message = "Apenas o owner pode convidar." })
			return
		end

		if partySize(player) >= MAX_PARTY_SIZE then
			PartyRemote:FireClient(player, "Error", { Message = "Party cheia." })
			return
		end

		local target = Players:FindFirstChild(args.TargetName)
		if not target then return end

		if MatchModule.FindPlayer(target.Name) ~= "FreePlayer" then
			PartyRemote:FireClient(player, "Error", { Message = target.Name .. " não está disponível." })
			return
		end

		if pendingInvites[target.Name] then
			PartyRemote:FireClient(player, "Error", { Message = target.Name .. " já tem um convite pendente." })
			return
		end

		pendingInvites[target.Name] = player.Name

		NotificationRemoteEvent:FireClient(target, "PartyInviteNotification", {
			FromName = player.Name,
		})

		warn("[PartyServer] Convite de party:", player.Name, "→", target.Name)

		-- ACEITAR CONVITE -------------------------------------------
	elseif action == "AcceptInvite" then
		local ownerName = pendingInvites[player.Name]
		if not ownerName then
			PartyRemote:FireClient(player, "Error", { Message = "Nenhum convite pendente." })
			return
		end
		pendingInvites[player.Name] = nil

		local ownerPlayer = Players:FindFirstChild(ownerName)
		if not ownerPlayer then
			PartyRemote:FireClient(player, "Error", { Message = "O dono da party saiu do servidor." })
			return
		end

		local playerState = MatchModule.FindPlayer(player.Name)
		if playerState == "InMatchPlayers" or playerState == "InMatchTeams" then
			PartyRemote:FireClient(player, "Error", { Message = "Você está em uma partida." })
			return
		end

		local ownerState = MatchModule.FindPlayer(ownerName)
		if ownerState == "InMatchPlayers" or ownerState == "InMatchTeams" then
			PartyRemote:FireClient(player, "Error", { Message = ownerName .. " está em uma partida." })
			return
		end

		if partySize(ownerPlayer) >= MAX_PARTY_SIZE then
			PartyRemote:FireClient(player, "Error", { Message = "A party está cheia." })
			return
		end

		-- Sai da fila antes de modificar o time
		leaveQueueIfInQueue(ownerPlayer)

		local currentMembers = getMembersOf(ownerPlayer)
		local newMembers     = { table.unpack(currentMembers) }
		table.insert(newMembers, player)

		rebuildTeam(ownerPlayer, newMembers)
		broadcastPartyUpdate(newMembers, ownerPlayer)

		-- Avisa o owner que a fila foi cancelada por causa da mudança
		NotificationModule.SendMessageToClient(
			ownerPlayer,
			player.Name .. " entrou — party removida da fila. Dê QueueUp novamente."
		)

		for _, p in ipairs(Players:GetPlayers()) do
			sendLobbyListToClient(p)
		end

		warn("[PartyServer]", player.Name, "entrou na party de", ownerName)

		-- RECUSAR CONVITE -------------------------------------------
	elseif action == "DeclineInvite" then
		local ownerName = pendingInvites[player.Name]
		pendingInvites[player.Name] = nil

		if ownerName then
			local ownerPlayer = Players:FindFirstChild(ownerName)
			if ownerPlayer then
				NotificationModule.SendMessageToClient(
					ownerPlayer,
					player.Name .. " recusou seu convite de party."
				)
				PartyRemote:FireClient(ownerPlayer, "InviteDeclined", { Name = player.Name })
			end
		end

		-- SAIR DA PARTY ---------------------------------------------
	elseif action == "LeaveParty" then
		removeMemberFromParty(player)

		-- EXPULSAR MEMBRO -------------------------------------------
	elseif action == "KickMember" then
		if not isOwner(player) then return end

		local target = Players:FindFirstChild(args.TargetName)
		if not target then return end

		local team = getTeamOf(player)
		if not team then return end

		local found = false
		for _, m in ipairs(team.Players) do
			if m == target then found = true; break end
		end
		if not found then return end

		-- Sai da fila antes de modificar o time
		leaveQueueIfInQueue(player)

		local newMembers = {}
		for _, m in ipairs(team.Players) do
			if m ~= target then table.insert(newMembers, m) end
		end

		rebuildTeam(player, newMembers)
		PartyRemote:FireClient(target, "PartyDissolved", {})
		PartyRemote:FireClient(target, "QueueStatus", { InQueue = false })
		broadcastPartyUpdate(newMembers, player)
		broadcastQueueStatus(newMembers, false)

		for _, p in ipairs(Players:GetPlayers()) do
			sendLobbyListToClient(p)
		end

		NotificationModule.SendMessageToClient(
			target,
			"Você foi removido da party de " .. player.Name .. "."
		)
		NotificationModule.SendMessageToClient(
			player,
			target.Name .. " foi expulso — party removida da fila."
		)

		warn("[PartyServer] Membro expulso:", target.Name)

		-- REFRESH LOBBY ---------------------------------------------
	elseif action == "RefreshLobby" or action == "RefreshPartyLobby" then
		print('send lobby list to client')
		sendLobbyListToClient(player)
	end
end

-- =============================================================
-- RemoteFunction
-- =============================================================

PartyFunc.OnServerInvoke = function(player: Player, action: string, args)
	args = args or {}

	if action == "GetMyParty" then
		local members = getMembersOf(player)
		local owner   = members[1]
		local payload = { Members = {} }
		for i, plr in ipairs(members) do
			payload.Members[i] = {
				Name        = plr.Name,
				DisplayName = plr.DisplayName,
				UserId      = plr.UserId,
				IsOwner     = (plr == owner),
			}
		end
		return payload
	end

	if action == "IsInParty" then
		return partySize(player) >= 2
	end

	if action == "IsInQueue" then
		return player:GetAttribute("TeamId") ~= nil
	end

	return nil
end

-- =============================================================
-- Jogadores entrando / saindo do servidor
-- =============================================================

Players.PlayerAdded:Connect(function(newPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		if p == newPlayer then continue end
		print('lobby player added')
		PartyRemote:FireClient(p, "LobbyPlayerAdded", {
			Name        = newPlayer.Name,
			DisplayName = newPlayer.DisplayName,
			UserId      = newPlayer.UserId,
		})
	end

	task.defer(function()
		if newPlayer and newPlayer.Parent then
			print('send lobby list to client')
			sendLobbyListToClient(newPlayer)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(leavingPlayer)
	-- Limpa convites pendentes
	pendingInvites[leavingPlayer.Name] = nil
	for targetName, ownerName in pairs(pendingInvites) do
		if ownerName == leavingPlayer.Name then
			pendingInvites[targetName] = nil
		end
	end

	-- Remove da party/time (leaveQueueIfInQueue já está dentro de removeMemberFromParty)
	removeMemberFromParty(leavingPlayer)

	for _, p in ipairs(Players:GetPlayers()) do
		sendLobbyListToClient(p)
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p == leavingPlayer then continue end
		PartyRemote:FireClient(p, "LobbyPlayerRemoved", { Name = leavingPlayer.Name })
	end
end)

PartyRemote.OnServerEvent:Connect(handleEvent)

function PartyServer.Init()
	warn("[PartyServer] Sistema de Party inicializado.")
end

return PartyServer