local module = {}

local Players = game:GetService("Players")

local MatchModule = require(game.ReplicatedStorage.MatchSystem.MatchModule)

local NotificationRemoteFunction = game.ReplicatedStorage.Events.Notification.NotificationRemoteFunctions
local NotificationRemoteEvent    = game.ReplicatedStorage.Events.Notification.NotificationRemoteEvents

local NotificationBindableFunction = game.ReplicatedStorage.Events.Notification.NotificationBindableFunctions
local NotificationBindableEvents   = game.ReplicatedStorage.Events.Notification.NotificationBindableEvents

local NotificationModule = require(game.ReplicatedStorage.Modules.NotificationModule)

local MatchRemoteEvent = game.ReplicatedStorage.Events.Match.MatchRemoteEvent

-- Party remote (para encaminhar convites de party via FireClient)
local PartyEvents = game.ReplicatedStorage.Events:WaitForChild("Party")
local PartyRemote = PartyEvents:WaitForChild("PartyRemoteEvent")

NotificationRemoteEvent.OnServerEvent:Connect(function(player, action, args)
	print("Notification Server Event:", action)

	-- ================================================================
	-- INVITE DE TEAM (2 jogadores formando time)
	-- ================================================================
	if action == "SendInviteTeamNotification" then
		local targetPlayer = Players:FindFirstChild(args.PlayerName)
		if not targetPlayer then return end

		if MatchModule.FindPlayer(player.Name) ~= 'FreePlayer' then
			NotificationModule.SendMessageToClient(player, "you cannot invite people right now!")
			return
		end
		if MatchModule.FindPlayer(targetPlayer.Name) ~= 'FreePlayer' then
			NotificationModule.SendMessageToClient(player, targetPlayer.Name .. " is not avaliable!")
			return
		end

		NotificationRemoteEvent:FireClient(targetPlayer, "InviteTeamNotification", {
			PlayerName = player.Name
		})
	end

	-- ================================================================
	-- INVITE DE FIGHT (1v1)
	-- ================================================================
	if action == "SendFightInviteNotification" then
		print("received by server, sending to destination client")

		local targetPlayer = Players:FindFirstChild(args.PlayerName)
		if not targetPlayer then return end

		if MatchModule.FindPlayer(player.Name) ~= 'FreePlayer' then
			NotificationModule.SendMessageToClient(player, "you cannot invite people right now!")
			return
		end
		if MatchModule.FindPlayer(targetPlayer.Name) ~= 'FreePlayer' then
			NotificationModule.SendMessageToClient(player, targetPlayer.Name .. " is not avaliable!")
			return
		end

		NotificationRemoteEvent:FireClient(targetPlayer, "FightInviteNotification", {
			PlayerName = player.Name
		})
	end

	-- ================================================================
	-- INVITE DE TEAM FIGHT (2v2)
	-- ================================================================
	if action == 'SendTeamFightInviteNotification' then
		local targetTeam = MatchModule.FindTeam(args.Team.Player1.Name, args.Team.Player2.Name)
		if not targetTeam or targetTeam.Status ~= 'ActiveOnly' then
			print('FindTeam é nil ou não é ActiveOnly')
			return
		end

		if MatchModule.FindPlayer(player.Name) ~= 'ActiveTeams' then
			NotificationModule.SendMessageToClient(player, "you cannot invite people right now!")
			return
		end

		for _, plr in pairs(targetTeam.Team) do
			NotificationRemoteEvent:FireClient(plr, 'FightTeamInviteNotification', {
				SendTeam      = MatchModule.FindPlayersTeam(player.Name).Team,
				ReceivingTeam = targetTeam
			})
		end
	end

	-- ================================================================
	-- ACEITAR FIGHT INVITE (1v1)
	-- ================================================================
	if action == "AcceptInviteFight" then
		print('received accept invite fight')
		local targetPlayer = Players:FindFirstChild(args.PlayerName)
		if not targetPlayer then return end

		if MatchModule.FindPlayer(player.Name) ~= 'FreePlayer' then
			NotificationModule.SendMessageToClient(player, "you cannot accept fights right now!")
			return
		end

		if MatchModule.FindPlayer(targetPlayer.Name) == 'InMatchPlayers'
			or MatchModule.FindPlayer(targetPlayer.Name) == 'InMatchTeams' then
			NotificationModule.SendMessageToClient(player, targetPlayer.Name .. " is already in a match!")
			return
		end

		NotificationModule.SendMessageToClient(targetPlayer, player.Name .. " accepted your invite!")
		task.wait(1)
		MatchRemoteEvent:FireClient(targetPlayer, 'EnableChooseMap', { PlayerThatAccepted = player, Mode = 'Online 1v1' })
	end

	-- ================================================================
	-- ACEITAR TEAM INVITE (formar time 2 jogadores)
	-- ================================================================
	if action == "AcceptInviteTeam" then
		print('Invite Team Accepted')
		local targetPlayer = Players:FindFirstChild(args.PlayerName)
		if not targetPlayer then warn(args.PlayerName .. " not found") return end

		if MatchModule.FindPlayer(player.Name) ~= 'FreePlayer' then
			NotificationModule.SendMessageToClient(player, "you cannot accept team invites right now!")
			return
		end
		if MatchModule.FindPlayer(targetPlayer.Name) ~= 'FreePlayer' then
			NotificationModule.SendMessageToClient(player, targetPlayer.Name .. " is not avaliable!")
			return
		end

		MatchRemoteEvent:FireClient(player, 'DisableChooseTeamateUI')
		MatchRemoteEvent:FireClient(targetPlayer, 'DisableChooseTeamateUI')

		MatchRemoteEvent:FireClient(player, 'EnableQueue2v2', { Player1 = player, Player2 = targetPlayer })
		MatchRemoteEvent:FireClient(targetPlayer, 'EnableQueue2v2', { Player1 = targetPlayer, Player2 = player })

		MatchModule.CreateTeam(targetPlayer, player)
	end

	-- ================================================================
	-- ACEITAR TEAM FIGHT INVITE (2v2)
	-- ================================================================
	if action == 'AcceptTeamInviteFight' then
		local TeamThatAccepted = MatchModule.FindPlayersTeam(player.Name)
		if not TeamThatAccepted then warn('Team not found') return end
		if TeamThatAccepted.Status == 'ActiveAndInMatch' then
			NotificationModule.SendMessageToClient(player, "your team is already in a match!")
			return
		end

		local TeamThatSend = MatchModule.FindTeam(args.Team.Player1.Name, args.Team.Player2.Name)
		if not TeamThatSend then warn('Team not found') return end
		if TeamThatSend.Status == 'ActiveAndInMatch' then
			NotificationModule.SendMessageToClient(player, "the enemy team is already in a match!")
			return
		end

		task.wait(1)
		MatchRemoteEvent:FireClient(
			TeamThatSend.Team.Player1,
			'EnableChooseMap',
			{ TeamThatAccepted = TeamThatAccepted, Mode = 'Online 2v2' }
		)
	end

	-- ================================================================
	-- FORWARD PARTY INVITE → envia notificação de convite de party
	-- para o target via PartyRemote (exibido pelo NotificationClient)
	-- ================================================================
	if action == "ForwardPartyInviteToClient" then
		local targetPlayer = Players:FindFirstChild(args.TargetName)
		if not targetPlayer then return end

		-- Usa o PartyRemote para reencaminhar, assim o client de party
		-- já registrou o convite e sabe a quem aceitar/recusar.
		-- O NotificationClient escuta "PartyInviteNotification" no
		-- NotificationRemoteEvent para exibir o card.
		NotificationRemoteEvent:FireClient(targetPlayer, "PartyInviteNotification", {
			FromName = args.FromName,
		})
	end

	--[[
	-- Timeouts (descomentados quando necessário)
	if action == "InviteFightTimeout" then ... end
	if action == "TeamInviteFightTimeout" then ... end
	if action == "InviteTeamTimeout" then ... end
	]]
end)

return module
