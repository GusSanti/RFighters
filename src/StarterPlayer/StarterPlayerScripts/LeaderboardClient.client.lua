local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets    = ReplicatedStorage:WaitForChild("Assets")
local Templates = Assets:WaitForChild("Templates")
local Events    = ReplicatedStorage:WaitForChild("Events")
local leaderboards = workspace:WaitForChild("leaderboards")
local template     = Templates:WaitForChild("PlayerLeaderboardTemplate")
local UpdateLeaderBoard  = Events:WaitForChild("UpdateLeaderBoard")
local RequestLeaderboard = Events:WaitForChild("RequestLeaderboard")

local thumbType = Enum.ThumbnailType.HeadShot
local thumbSize = Enum.ThumbnailSize.Size420x420

local icons = {
	["PlayTime"]     = "rbxassetid://6846329361",
	["Kills"]    = "rbxassetid://7485051733",
	["KillStreak"]  = "rbxassetid://7485051733",
}

local nameCache: {[number]: string} = {}
local receivedData = false  -- controla se já recebemos dados válidos

local function getPlayerName(userId: number): string
	if nameCache[userId] then return nameCache[userId] end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = ok and ("@" .. name) or "@Unknown"
	nameCache[userId] = result
	return result
end

local function getScrollingFrame(stat: string): ScrollingFrame?
	local board = leaderboards:FindFirstChild(stat)
	if not board then return nil end
	local main = board:FindFirstChild("Main")
	if not main then return nil end
	local surface = main:FindFirstChild("SurfaceGui")
	if not surface then return nil end
	return surface:FindFirstChild("ScrollingFrame") :: ScrollingFrame?
end

local function renderStat(stat: string, entries: {any})
	local scrollFrame = getScrollingFrame(stat)
	if not scrollFrame then return end

	for _, child in ipairs(scrollFrame:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end

	for _, entry in ipairs(entries) do
		local rank   = entry.rank
		local score  = entry.score
		local userId = entry.userId
		local name   = getPlayerName(userId)

		-- Checa se já existe um card com esse nome no frame
		local duplicate = false
		for _, child in ipairs(scrollFrame:GetChildren()) do
			if child:IsA("Frame") and child:FindFirstChild("PlayerName") then
				if child.PlayerName.Text == name then
					duplicate = true
					break
				end
			end
		end
		if duplicate then continue end

		local card = template:Clone()
		card.Name        = "Rank_" .. rank
		card.LayoutOrder = rank

		task.spawn(function()
			local ok, img = pcall(Players.GetUserThumbnailAsync, Players, userId, thumbType, thumbSize)
			if ok and card.Parent then
				card.PlayerImage.Image = img
			end
		end)

		card.PlayerName.Text     = getPlayerName(userId)
		card.Rank.Text           = "#" .. rank
		card.CurrencyImage.Image = icons[stat] or ""
		card.Value.Text          = tostring(score)
		card.Parent              = scrollFrame
	end
end

UpdateLeaderBoard.OnClientEvent:Connect(function(data: {[string]: {any}})
	-- Verifica se veio com dados de verdade
	local hasAny = false
	for _, entries in pairs(data) do
		if #entries > 0 then
			hasAny = true
			break
		end
	end

	if not hasAny then return end  -- ignora resposta vazia, retry vai acontecer

	receivedData = true
	for stat, entries in pairs(data) do
		task.spawn(renderStat, stat, entries)
	end
end)

-- Retry: pede a cada 3 segundos até receber dados válidos, com teto de tentativas
task.spawn(function()
	local attempts = 0
	local MAX_ATTEMPTS = 20
	while not receivedData and attempts < MAX_ATTEMPTS do
		RequestLeaderboard:FireServer()
		attempts += 1
		task.wait(3)
	end
	if not receivedData then
		warn("[LeaderboardClient] Sem resposta do servidor após", MAX_ATTEMPTS, "tentativas")
	end
end)