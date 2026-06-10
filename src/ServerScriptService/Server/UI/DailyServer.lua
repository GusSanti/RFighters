--!strict
local DailyRewardSystem = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")

local DAY_IN_SECONDS = 86400
local STREAK_GRACE   = 172800
local MAX_DAYS       = 28

local Events      = ReplicatedStorage:WaitForChild("Events")
local DailyRemote = Events:WaitForChild("DailyRewardRemote") :: RemoteFunction

local PlayerState = require(ReplicatedStorage.PlayerState.PlayerStateServer)

local function grantRolls(player: Player, amount: number)
	local current = PlayerState.Get(player, "Rolls") or 0
	PlayerState.Set(player, "Rolls", current + amount)
	print(string.format("[Daily] %s recebeu %d roll(s) | Total: %d", player.Name, amount, current + amount))
end

local function grantCrystals(player: Player, amount: number)
	local current = PlayerState.Get(player, "Crystals") or 0
	PlayerState.Set(player, "Crystals", current + amount)
	print(string.format("[Daily] %s recebeu %d Crystal(s) | Total: %d", player.Name, amount, current + amount))
end

local function grantSkin(player: Player, rarity: string)
	print(string.format("[Daily] TODO: conceder Skin %s para %s", rarity, player.Name))
end

local weeklyPattern: { [number]: (Player) -> () } = {
	[1] = function(p) grantRolls(p, 1) end,
	[2] = function(p) grantCrystals(p, 25) end,
	[3] = function(p) grantRolls(p, 3) end,
	[4] = function(p) grantCrystals(p, 50) end,
	[5] = function(p) grantRolls(p, 5) end,
	[6] = function(p) grantCrystals(p, 100) end,
}

local milestones: { [number]: (Player) -> () } = {
	[7] = function(p) grantSkin(p, "Rare") end,
	[14] = function(p) grantSkin(p, "Uncommon") end,
	[21] = function(p) grantSkin(p, "Epic") end,
	[28] = function(p) grantSkin(p, "Legendary") end
}

local Rewards: { [number]: (Player) -> () } = {}
for day = 1, MAX_DAYS do
	local weekDay = day % 7
	if weekDay == 0 then
		Rewards[day] = milestones[day]
	else
		Rewards[day] = weeklyPattern[weekDay]
	end
end

function DailyRewardSystem.GetStatus(player: Player)
	local timeout = 0
	while not PlayerState.IsPlayerDataReady(player) and timeout < 10 do
		task.wait(0.5)
		timeout += 1
	end
	if not PlayerState.IsPlayerDataReady(player) then return nil end

	local allData = PlayerState.GetAll(player)
	if not allData.Daily then
		PlayerState.SetPath(player, "Daily", { CurrentDay = 1, LastClaim = 0, LastClaimedDay = 0 })
		allData = PlayerState.GetAll(player)
	end

	local data           = allData.Daily
	local now            = os.time()
	local lastClaim      = data.LastClaim      or 0
	local currentDay     = data.CurrentDay     or 1
	local lastClaimedDay = data.LastClaimedDay or 0

	if lastClaim > 0 then
		local rewardAvailableAt = lastClaim + DAY_IN_SECONDS
		if (now - rewardAvailableAt) >= STREAK_GRACE then
			currentDay    = 1
			lastClaimedDay = 0
			lastClaim      = 0
			PlayerState.SetPath(player, "Daily.CurrentDay",     1)
			PlayerState.SetPath(player, "Daily.LastClaim",      0)
			PlayerState.SetPath(player, "Daily.LastClaimedDay", 0)
		end
	end

	local timeSinceClaim = now - lastClaim
	local canClaim = (lastClaim == 0) or (timeSinceClaim >= DAY_IN_SECONDS)

	return {
		CurrentDay     = currentDay,
		LastClaimedDay = lastClaimedDay,
		CanClaim       = canClaim,
		TimeUntilNext  = math.max(0, DAY_IN_SECONDS - timeSinceClaim),
		MaxDays        = MAX_DAYS,
	}
end

function DailyRewardSystem.Claim(player: Player): (boolean, string)
	local status = DailyRewardSystem.GetStatus(player)
	if not status or not status.CanClaim then
		return false, "Cooldown active"
	end

	local dayToClaim = status.CurrentDay
	local rewardFn   = Rewards[dayToClaim]

	if not rewardFn then
		return false, "No reward defined for day " .. tostring(dayToClaim)
	end

	local ok, err = pcall(rewardFn, player)
	if not ok then
		warn("[Daily] Erro ao conceder recompensa dia " .. dayToClaim .. ": " .. tostring(err))
		return false, "Internal error"
	end

	local claimTime = os.time()
	local nextDay   = (dayToClaim >= MAX_DAYS) and 1 or (dayToClaim + 1)

	PlayerState.SetPath(player, "Daily.LastClaim",      claimTime)
	PlayerState.SetPath(player, "Daily.CurrentDay",     nextDay)
	PlayerState.SetPath(player, "Daily.LastClaimedDay", dayToClaim)

	task.defer(function()
		pcall(function() DailyRemote:InvokeClient(player, "UpdateUI") end)
	end)

	return true, "Success"
end

local function resetPlayerData(player: Player)
	if not PlayerState.IsPlayerDataReady(player) then return end
	PlayerState.SetPath(player, "Daily.CurrentDay",     1)
	PlayerState.SetPath(player, "Daily.LastClaim",      0)
	PlayerState.SetPath(player, "Daily.LastClaimedDay", 0)
	task.defer(function()
		pcall(function() DailyRemote:InvokeClient(player, "UpdateUI") end)
	end)
end

DailyRemote.OnServerInvoke = function(player, action)
	if action == "GetStatus" then
		return DailyRewardSystem.GetStatus(player)
	elseif action == "Claim" then
		return DailyRewardSystem.Claim(player)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		if not RunService:IsStudio() then return end
		local cmd = msg:lower()
		if cmd == "/reset" then
			resetPlayerData(player)
		elseif cmd == "/status" then
			local s = DailyRewardSystem.GetStatus(player)
			if s then print(s) end
		end
	end)
end)

return DailyRewardSystem