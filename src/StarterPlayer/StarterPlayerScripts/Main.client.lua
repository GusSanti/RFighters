--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

--Imports
local UI = require(ReplicatedStorage:WaitForChild("UI"))

--Client
local localPlayer = Players.LocalPlayer
local PlayerGui = localPlayer:WaitForChild("PlayerGui")

--Inits
local ok, err = pcall(UI.Init)
if not ok then
	warn("[Main] UI.Init failed:", err)
end

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

local function getCharacterReadyRemote(): RemoteEvent?
	local events = ReplicatedStorage:WaitForChild("Events", 15)
	if not events then
		warn("[Main] ReplicatedStorage.Events not found; CharacterReady disabled")
		return nil
	end

	local remote = events:WaitForChild("CharacterReady", 15)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	warn("[Main] Events.CharacterReady RemoteEvent not found")
	return nil
end

local CharacterReady = getCharacterReadyRemote()

local function onCharacterLoaded()
	if not CharacterReady then
		return
	end

	-- Avisa o servidor que está tudo pronto
	CharacterReady:FireServer()
end

player.CharacterAdded:Connect(onCharacterLoaded)

if player.Character then
	onCharacterLoaded()
end

task.delay(1, function()
	StarterGui:SetCore("ResetButtonCallback", false)
end)
