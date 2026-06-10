--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local CharacterReady = ReplicatedStorage.Events:WaitForChild("CharacterReady")

--Imports
local UI = require(ReplicatedStorage:WaitForChild("UI"))

--Client
local localPlayer = Players.LocalPlayer
local PlayerGui = localPlayer:WaitForChild("PlayerGui")

--Inits
UI.Init()

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

local function onCharacterLoaded()
	-- Espera o personagem existir
	local character = player.Character or player.CharacterAdded:Wait()

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