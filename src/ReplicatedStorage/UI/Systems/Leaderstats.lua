local Leaderstats = {}
-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Imports
local PlayerState = require(ReplicatedStorage.PlayerState.PlayerStateClient)
-- Events
local SendLeaderstatsUpdate = ReplicatedStorage.Events.SendLeaderstatsUpdate
-- Client_Related
local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = localPlayer:WaitForChild("PlayerGui")
local Main = PlayerGui:WaitForChild("UI", 15)
local HUD = Main:WaitForChild("HUD")
local LeaderstatsUI = HUD:WaitForChild("Leaderboard")
local Template = LeaderstatsUI:WaitForChild("Template")
-- Tables
local playerFrames = {}

-- Private Functions
local function updatePlayerStats(playerName)
	local frame = playerFrames[playerName]
	if not frame then return end

	local wins = 0
	local level = 1

	if playerName == localPlayer.Name then
		level = PlayerState.Get("Level") or 1
		wins = PlayerState.Get("Wins") or 0
	else
		wins = ReplicatedStorage.Events.RequestLeaderstatsPlayerData:InvokeServer(playerName, "Wins")
		level = ReplicatedStorage.Events.RequestLeaderstatsPlayerData:InvokeServer(playerName, "Level")
	end

	frame.Level.TextLabel.Text = `{level}`
	frame.Wins.TextLabel.Text = `{wins}`
end

local function CloneTemplate(player)
	if playerFrames[player.Name] then
		playerFrames[player.Name]:Destroy()
	end
	local newTemplate = Template:Clone()
	newTemplate.Parent = LeaderstatsUI
	newTemplate.Name = player.Name
	newTemplate.Username.TextLabel.Text = `@{player.Name}`
	newTemplate.Visible = true
	playerFrames[player.Name] = newTemplate
	updatePlayerStats(player.Name)
end

local function DestroyLeaderboard(player)
	if playerFrames[player.Name] then
		playerFrames[player.Name]:Destroy()
		playerFrames[player.Name] = nil
	end
end

-- Setup
for _, player in Players:GetPlayers() do
	CloneTemplate(player)
end

Players.PlayerAdded:Connect(CloneTemplate)
Players.PlayerRemoving:Connect(DestroyLeaderboard)

-- Recebe atualizações do servidor (substitui os OnChanged do client)
SendLeaderstatsUpdate.OnClientEvent:Connect(function(playerName, key, newVal)
	local frame = playerFrames[playerName]
	if not frame then return end

	if key == "Level" then
		frame.Level.TextLabel.Text = `{newVal}`
	elseif key == "Wins" then
		frame.Wins.TextLabel.Text = `{newVal}`
	end
end)

return Leaderstats