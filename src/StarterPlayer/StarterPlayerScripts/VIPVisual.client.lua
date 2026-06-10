local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerStat = require(game.ReplicatedStorage.PlayerState.PlayerStateClient)

TextChatService.OnIncomingMessage = function(message)
	local props = Instance.new("TextChatMessageProperties")
	local sender = message.TextSource
	if not sender then return props end

	local player = Players:GetPlayerByUserId(sender.UserId)
	if not player then return props end

	-- Checa HasVIP via RemoteFunction (cria uma se não tiver)
	local isVip = ReplicatedStorage.Events.RequestLeaderstatsPlayerData:InvokeServer(
		player.Name, "HasVIP"  -- adicione "HasVIP" no InvokeServer do servidor
	)

	if isVip then
		props.PrefixText = '<font color="#7c3aed"><b>[VIP]</b></font> ' .. message.PrefixText
	end

	return props
end