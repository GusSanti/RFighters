local module = {}

local MatchSystemEvents = game.ReplicatedStorage.Events.Match.MatchRemoteEvent
local NotificationModule = require(game.ReplicatedStorage.Modules.NotificationModule)
local MatchModule = require(game.ReplicatedStorage.MatchSystem.MatchModule)

MatchSystemEvents.OnServerEvent:Connect(function(player, action, args)
	if action == "StartOnline1v1" then
		if args and args.Player then
			print(player, args.Player)
			MatchModule.Start1v1Match(player, args.Player, args.Map)
		end
	end

	if action == "StartOnline2v2" then
		if args and args.TeamThatAccepted then
			local PlayersTeam = MatchModule.FindPlayersTeam(player.Name)
			if not PlayersTeam or PlayersTeam.Status ~= 'ActiveOnly' then return end
			print(PlayersTeam.Team, args.TeamThatAccepted)
			MatchModule.Start2v2Match(PlayersTeam.Team, args.TeamThatAccepted.Team, args.Map)
		end
	end

	if action == 'LeaveTeam' then
		local PlayersTeam = MatchModule.FindPlayersTeam(player.Name)
		if PlayersTeam and PlayersTeam.Status == 'ActiveOnly' then
			MatchModule.RemoveTeam(PlayersTeam.Team.Player1, PlayersTeam.Team.Player2)
			MatchSystemEvents:FireClient(PlayersTeam.Team.Player1, 'DisableQueue2v2')
			MatchSystemEvents:FireClient(PlayersTeam.Team.Player2, 'DisableQueue2v2')
			NotificationModule.SendMessageToClient(PlayersTeam.Team.Player1, 'Your Team was Dismantled')
			NotificationModule.SendMessageToClient(PlayersTeam.Team.Player2, 'Your Team was Dismantled')
		end
	end
end)

return module
