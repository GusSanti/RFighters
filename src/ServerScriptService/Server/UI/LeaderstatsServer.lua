local module = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Imports
local PlayerStateServer = require(ReplicatedStorage.PlayerState.PlayerStateServer)
-- Events
local SendLeaderstatsUpdate = ReplicatedStorage.Events.SendLeaderstatsUpdate

local function setupPlayerListeners(player)
	PlayerStateServer.OnChanged(player, "Level", function(newVal)
		SendLeaderstatsUpdate:FireClient(player, player.Name, "Level", newVal)
		-- Manda também pra todos os outros jogadores (pra atualizar o leaderboard deles)
		for _, otherPlayer in Players:GetPlayers() do
			if otherPlayer ~= player then
				SendLeaderstatsUpdate:FireClient(otherPlayer, player.Name, "Level", newVal)
			end
		end
	end)

	PlayerStateServer.OnChanged(player, "Wins", function(newVal)
		SendLeaderstatsUpdate:FireClient(player, player.Name, "Wins", newVal)
		for _, otherPlayer in Players:GetPlayers() do
			if otherPlayer ~= player then
				SendLeaderstatsUpdate:FireClient(otherPlayer, player.Name, "Wins", newVal)
			end
		end
	end)
end

Players.PlayerAdded:Connect(setupPlayerListeners)

for _, player in Players:GetPlayers() do
	setupPlayerListeners(player)
end

return module