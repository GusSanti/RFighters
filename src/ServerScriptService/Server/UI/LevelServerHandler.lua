local module = {}
local PlayerStateServer = require(game.ReplicatedStorage.PlayerState.PlayerStateServer)

local function onPlayerAdded(plr)
	PlayerStateServer.OnChanged(plr, "Xp", function(newValue)
		local currentLevel = PlayerStateServer.Get(plr, "Level")
		local xp = newValue

		while true do
			local xpNeeded = 100 + 100 * (currentLevel + 1)

			if xp < xpNeeded then
				break
			end

			xp -= xpNeeded
			currentLevel += 1
		end

		PlayerStateServer.Set(plr, "Level", currentLevel)
		PlayerStateServer.Set(plr, "Xp", xp)
	end)
end

for _, player in game.Players:GetPlayers() do
	onPlayerAdded(player)
end

game.Players.PlayerAdded:Connect(onPlayerAdded)

return module