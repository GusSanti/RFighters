local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerState = require(ReplicatedStorage.PlayerState.PlayerStateServer)
local MatchModule = require(ReplicatedStorage.MatchSystem.MatchModule)
local ServerEvents = ReplicatedStorage.CombatSystem.Events.ServerEvents
local MatchRemoteEvent = ReplicatedStorage.Events.Match.MatchRemoteEvent
local TutorialComplete = ReplicatedStorage.Events:WaitForChild("TutorialComplete")
local PurchaseRolls = ReplicatedStorage.Events.PurchaseRolls

local RunService = game:GetService("RunService")

-- === LEADERBOARD SETUP ===
local Events = ReplicatedStorage:FindFirstChild("Events")
local UpdateLeaderBoard = Events:FindFirstChild("UpdateLeaderBoard")
local UpdateShopDiscounts = Events:WaitForChild("UpdateShopDiscounts")
local RequestLeaderboard = Events:FindFirstChild("RequestLeaderboard")

local STATS = { "KillStreak", "Kills", "PlayTime" }
local TOP_COUNT = 10
local bestData = {}

local function getFilteredLeaderboard(stat, count)
	local entries = PlayerState.GetLeaderboard(stat, count + 50)
	if not entries or #entries == 0 then return {} end

	local filtered = {}
	local seenIds = {}
	local seenNames = {}

	for _, entry in ipairs(entries) do
		if not entry.userId or entry.userId <= 0 then continue end
		if seenIds[entry.userId] then continue end
		local name = entry.username or entry.name or ""
		if name ~= "" and seenNames[name] then continue end
		seenIds[entry.userId] = true
		if name ~= "" then seenNames[name] = true end
		table.insert(filtered, entry)
	end

	table.sort(filtered, function(a, b)
		return (a.score or 0) > (b.score or 0)
	end)

	for i, entry in ipairs(filtered) do
		entry.rank = i
	end

	return filtered
end

local function syncOnlinePlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerState.IsPlayerDataReady(player) then
			for _, stat in ipairs(STATS) do
				local value = PlayerState.Get(player, stat)
				if value and typeof(value) == "number" then
					PlayerState.UpdateLeaderboard(player, stat, value)
				end
			end
		end
	end
	task.wait(0.5)
end

local function mergeIntoBest(newData)
	for stat, entries in pairs(newData) do
		if not bestData[stat] then
			bestData[stat] = entries
		else
			local newTop = entries[1] and entries[1].score or 0
			local bestTop = bestData[stat][1] and bestData[stat][1].score or 0
			if newTop > bestTop then
				bestData[stat] = entries
			end
		end
	end
	return bestData
end

local function buildLeaderboardData()
	syncOnlinePlayers()

	local data = {}
	for _, stat in ipairs(STATS) do
		local filtered = getFilteredLeaderboard(stat, TOP_COUNT)
		if stat == "PlayTime" then
			for _, entry in ipairs(filtered) do
				entry.score = math.floor(entry.score / 60)
			end
		end
		data[stat] = filtered
	end
	return mergeIntoBest(data)
end

-- === TOP PLAYERS CHARACTER DISPLAY ===

local DISPLAY_CONFIGS = {
	{ stat = "Kills",      folder = "TopPlayerKills"      },
	{ stat = "Wins",       folder = "TopPlayerWins"       },
	{ stat = "KillStreak", folder = "TopPlayerKillStreak" },
	{ stat = "PlayTime",   folder = "TopPlayerPlayTime"   }
}

local function clearDisplayCharacter(rankFolder)
	for _, child in ipairs(rankFolder:GetChildren()) do
		if child.Name == "DisplayCharacter" or child.Name == "_Occupied" then
			child:Destroy()
		end
	end
end

local function spawnDisplayCharacter(userId, rankFolder)
	if rankFolder:FindFirstChild("_Occupied") then return end
	local flag = Instance.new("BoolValue")
	flag.Name = "_Occupied"
	flag.Parent = rankFolder

	task.spawn(function()
		local spawnPart = rankFolder:FindFirstChild("SpawnPlyerCharacter")
		if not spawnPart then
			warn("[DisplayCharacter] SpawnPlyerCharacter não encontrado em:", rankFolder.Name)
			flag:Destroy()
			return
		end

		clearDisplayCharacter(rankFolder)

		local ok, character = pcall(function()
			return Players:CreateHumanoidModelFromUserIdAsync(userId)
		end)
		if not ok or not character then
			warn("[DisplayCharacter] Falha ao criar modelo para userId:", userId)
			flag:Destroy()
			return
		end

		local idleAnimScript = game.ReplicatedStorage.Assets.Templates.CharacterAnimation:Clone()
		idleAnimScript.Parent = character

		local nameOk, name = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		if nameOk and name then
			character.Name = name
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed       = 0
			humanoid.JumpPower       = 0
			humanoid.AutoJumpEnabled = false
		end

		for _, s in ipairs(character:GetDescendants()) do
			if s:IsA("LocalScript") or s:IsA("Script") then
				s:Destroy()
			end
		end

		character.Parent = workspace

		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = true
			local cf = spawnPart.CFrame
			root.CFrame = cf * CFrame.new(0, root.Size.Y / 2, 0)
		end

		character:ScaleTo(1)
		character.Parent = rankFolder
	end)
end

local function updateDisplayCharacters()
	local leaderboardsFolder = workspace:FindFirstChild("leaderboards")
	if not leaderboardsFolder then return end

	for _, config in ipairs(DISPLAY_CONFIGS) do
		local topFolder = leaderboardsFolder:FindFirstChild(config.folder)
		if not topFolder then continue end

		for rank = 1, 3 do
			local rankFolder = topFolder:FindFirstChild("Top" .. rank)
			if rankFolder then
				clearDisplayCharacter(rankFolder)  -- só limpa se vazio mesmo
			end
		end

		local filtered = getFilteredLeaderboard(config.stat, 3)
		if #filtered == 0 then continue end

		for newRank, entry in ipairs(filtered) do
			if newRank > 3 then break end
			local rankFolder = topFolder:FindFirstChild("Top" .. newRank)
			if rankFolder then
				spawnDisplayCharacter(entry.userId, rankFolder)
			end
		end
	end
end

local function broadcastLeaderboard()
	local data = buildLeaderboardData()
	for _, player in ipairs(Players:GetPlayers()) do
		UpdateLeaderBoard:FireClient(player, data)
	end
	updateDisplayCharacters()
end

local function sendLeaderboardWhenReady(player)
	task.spawn(function()
		local tries = 0
		while tries < 30 do
			task.wait(2)
			tries += 1
			if player.Parent ~= Players then return end
			local data = buildLeaderboardData()
			local hasAll = true
			for _, stat in ipairs(STATS) do
				if not data[stat] or #data[stat] == 0 then
					hasAll = false
					break
				end
			end
			UpdateLeaderBoard:FireClient(player, data)
			if hasAll then return end
		end
	end)
end

RequestLeaderboard.OnServerEvent:Connect(function(player)
	task.spawn(function()
		local tries = 0
		while not PlayerState.IsPlayerDataReady(player) and tries < 30 do
			task.wait(0.5)
			tries += 1
		end
		if player.Parent ~= Players then return end

		local data = {}
		local dataWaitTries = 0
		repeat
			data = buildLeaderboardData()
			local hasAll = true
			for _, stat in ipairs(STATS) do
				if not data[stat] or #data[stat] == 0 then
					hasAll = false
					break
				end
			end
			if hasAll then break end
			task.wait(1)
			dataWaitTries += 1
		until dataWaitTries >= 20

		UpdateLeaderBoard:FireClient(player, data)
		updateDisplayCharacters()
		sendLeaderboardWhenReady(player)
	end)
end)

-- =========================

PurchaseRolls.OnServerEvent:Connect(function(plr, action)
	if action == "Buy10Rolls" then
		if PlayerState.Get(plr, "Diamonds") < 5000 then return end
		PlayerState.Decrement(plr, "Diamonds", 5000)
		PlayerState.Increment(plr, "Rolls", 10)
	end
	if action == "Buy3Rolls" then
		if PlayerState.Get(plr, "Crystals") < 3500 then return end
		PlayerState.Decrement(plr, "Crystals", 3500)
		PlayerState.Increment(plr, "Rolls", 3)
	end
	if action == "Buy5Rolls" then
		if PlayerState.Get(plr, "Crystals") < 5000 then return end
		PlayerState.Decrement(plr, "Crystals", 5000)
		PlayerState.Increment(plr, "Rolls", 5)
	end
	if action == "Buy25Rolls" then
		if PlayerState.Get(plr, "Diamonds") < 10000 then return end
		PlayerState.Decrement(plr, "Diamonds", 1000)
		PlayerState.Increment(plr, "Rolls", 25)
	end
end)

local function waitForTutorialLobbyReturn(player, previousCharacter)
	local lobby = workspace:FindFirstChild("Lobby")
	local lobbySpawn = lobby and lobby:FindFirstChild("SpawnLocation")
	local lobbyPosition = lobbySpawn and lobbySpawn.Position
	local startedAt = os.clock()

	while player.Parent == Players and os.clock() - startedAt < 5 do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if character and character ~= previousCharacter and root then
			if not lobbyPosition or (root.Position - lobbyPosition).Magnitude <= 80 then
				return
			end
		end

		task.wait(0.05)
	end
end

TutorialComplete.OnServerEvent:Connect(function(player)
	warn("[Tutorial] Completo por", player.Name, "— encerrando partida offline")
	MatchRemoteEvent:FireClient(player, "FadeIn")
	task.wait(0.6)

	local previousCharacter = player.Character
	local stoppedMatch = MatchModule.Stop1v1Match(player, nil)
	if stoppedMatch then
		waitForTutorialLobbyReturn(player, previousCharacter)
	else
		task.wait(0.4)
	end

	if PlayerState.Get(player, "ClaimedStarterBundle") == false then
		UpdateShopDiscounts:FireClient(player, "ShowFTUEPopup")
	else
		UpdateShopDiscounts:FireClient(player, "ShowDailyRewards")
	end

	task.wait(0.2)
	MatchRemoteEvent:FireClient(player, "FadeOut")
	ServerEvents:FireClient(player, "FinishTutorialTeleportFade")

	task.delay(0.1, function()
		if player.Parent == Players then
			ServerEvents:FireClient(player, "StartLobbyTutorial")
		end
	end)
end)

Players.PlayerAdded:Connect(function(player)
	PlayerState.Init(player)

	task.spawn(function()
		local tries = 0
		while not PlayerState.IsPlayerDataReady(player) and tries < 30 do
			task.wait(0.5)
			tries += 1
		end
		if player.Parent ~= Players then return end

		local expiry = PlayerState.Get(player, "DiscountExpiry")
		if expiry == 0 then
			PlayerState.Set(player, "DiscountExpiry", os.time() + 72 * 3600)
		elseif os.time() >= expiry then
			PlayerState.Set(player, "ClaimedRollDiscount", true)
			PlayerState.Set(player, "ClaimedCrystalDiscount", true)
		end

		UpdateShopDiscounts:FireClient(player, "StartDiscountTimer", PlayerState.Get(player, "DiscountExpiry"))

		if PlayerState.Get(player, "ClaimedStarterBundle") == false and PlayerState.Get(player, "HasDoneTutorial") == true then
			UpdateShopDiscounts:FireClient(player, "ShowFTUEPopup")
		elseif PlayerState.Get(player, "ClaimedStarterBundle") == true and PlayerState.Get(player, "HasDoneTutorial") == true then
			UpdateShopDiscounts:FireClient(player, "ShowDailyRewards")
		end

		if PlayerState.Get(player, "ClaimedRollDiscount") == false then
			UpdateShopDiscounts:FireClient(player, "Enable25RollsDiscount")
		else
			UpdateShopDiscounts:FireClient(player, "Disable25RollsDiscount")
		end

		if PlayerState.Get(player, "ClaimedCrystalDiscount") == false then
			UpdateShopDiscounts:FireClient(player, "Enable10000CrystalsDiscount")
		else
			UpdateShopDiscounts:FireClient(player, "Disable10000CrystalsDiscount")
		end
	end)
end)

ReplicatedStorage.Events:WaitForChild("CharacterReady").OnServerEvent:Connect(function(player)
	local hasDone = PlayerState.Get(player, "HasDoneTutorial")
	warn("HasDoneTutorial vale:", hasDone)
	if not hasDone then
		warn("INICIOU TUTORIAL — aparência carregada para", player.Name)
		PlayerState.Set(player, "HasDoneTutorial", true)
		MatchModule.StartOffline1v1Match(
			player,
			game.ReplicatedStorage.MatchSystem.Storage.MapVisuals.Map_Dojo
		)
		task.wait(4)
		ServerEvents:FireClient(player, "StartTutorial")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	task.wait(1)
	broadcastLeaderboard()
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 1 then return end
	elapsed = 0

	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerState.IsPlayerDataReady(player) then
			PlayerState.Increment(player, "PlayTime", 1)
		end
	end
end)

ReplicatedStorage.Events.RequestLeaderstatsPlayerData.OnServerInvoke = function(plr, plrRequestName, requestedData)
	local plrRequest = Players:FindFirstChild(plrRequestName)
	if not plrRequest then return end
	if requestedData == "HasVIP"  then return PlayerState.Get(plrRequest, "HasVIP")  end
	if requestedData == "Wins"    then return PlayerState.Get(plrRequest, "Wins")    end
	if requestedData == "Level"   then return PlayerState.Get(plrRequest, "Level")   end
end

for _, child in ipairs(script:GetDescendants()) do
	if child:IsA("ModuleScript") then
		local status, result = pcall(require, child)
		if status then
			print("Módulo carregado com sucesso: " .. child.Name)
			if type(result) == "table" and type(result.ServerInit) == "function" then
				local ok, err = pcall(result.ServerInit, result)
				if not ok then
					warn("Erro no Init de " .. child.Name .. ": " .. err)
				end
			end
		else
			warn("Erro ao carregar módulo " .. child.Name .. ": " .. result)
		end
	end
end
