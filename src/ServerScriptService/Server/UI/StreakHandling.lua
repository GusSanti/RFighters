local module = {}
local UpdateStreakInfo = game.ReplicatedStorage.Events.UpdateStreakInfo
local GetStreakInfo = game.ReplicatedStorage.Events.GetStreakInfo
local SendDamageIndicator = game.ReplicatedStorage.Events.SendDamageIndicator
local RunService = game:GetService("RunService")
local StreakStorage = {}
local STREAK_TIMEOUT = 1.5

-- StreakStorage[player] = { streak = N, lastUpdate = tick() }

local MAX_MULTIPLIER = 2.5
local MAX_STREAK = 25

local function getStreakMultiplier(player)
	if not player then return 1 end
	local streak = GetStreakInfo:Invoke(player) or 0
	warn('STREAK DAMAGE MODULE = ', streak)
	local t = math.clamp(streak / MAX_STREAK, 0, 1)
	return 1 + (MAX_MULTIPLIER - 1) * t
end

local function resetStreak(player)
	if StreakStorage[player] then
		StreakStorage[player].streak = 0
	end
end

RunService.Heartbeat:Connect(function()
	local now = tick()
	for player, data in pairs(StreakStorage) do
		if data.streak > 0 and (now - data.lastUpdate) >= STREAK_TIMEOUT then
			resetStreak(player)
		end
	end
end)

UpdateStreakInfo.Event:Connect(function(player)
	if not StreakStorage[player] then
		StreakStorage[player] = { streak = 0, lastUpdate = tick() }
	end

	StreakStorage[player].streak += 1
	warn('NEW STREAK = ', StreakStorage[player].streak)
	StreakStorage[player].lastUpdate = tick()

	SendDamageIndicator:FireClient(player, getStreakMultiplier(player))
end)

GetStreakInfo.OnInvoke = function(player)
	if StreakStorage[player] then
		return StreakStorage[player].streak
	end
	return 0
end

return module