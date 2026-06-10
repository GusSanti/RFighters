local NotificationModule = {}
local RunService = game:GetService("RunService")

local MatchModule = require(game.ReplicatedStorage.MatchSystem.MatchModule)

local NotificationRemoteFunction = game.ReplicatedStorage.Events.Notification.NotificationRemoteFunctions
local NotificationRemoteEvent = game.ReplicatedStorage.Events.Notification.NotificationRemoteEvents
local NotificationBindableFunction = game.ReplicatedStorage.Events.Notification.NotificationBindableFunctions
local NotificationBindableEvents = game.ReplicatedStorage.Events.Notification.NotificationBindableEvents

print("CLIENT RemoteEvent:", NotificationRemoteEvent:GetFullName(), NotificationRemoteEvent)

if RunService:IsClient() then
	function NotificationModule.SendInviteTeamNotification(playerName)
		NotificationRemoteEvent:FireServer('SendInviteTeamNotification', {PlayerName = playerName})
	end
	
	function NotificationModule.SendFightInviteNotification(playerName)
		NotificationRemoteEvent:FireServer('SendFightInviteNotification', {PlayerName = playerName})
		print('sent to server')
	end
	
	function NotificationModule.SendTeamFightInviteNotification(player1Name, player2Name)
		local FindTeamStatus = MatchModule.FindTeam(player1Name, player2Name)
		print('FIND STATUS', FindTeamStatus)
		
		if FindTeamStatus.Team and FindTeamStatus.Status == 'ActiveOnly' then
			print('FIRING SERVER')
			NotificationRemoteEvent:FireServer('SendTeamFightInviteNotification', {Team = FindTeamStatus.Team})
		end
	end
end

if RunService:IsServer() then
	function NotificationModule.SendMessageToClient(player, message)
		NotificationRemoteEvent:FireClient(player, 'SendMessage', message)
	end
end

return NotificationModule