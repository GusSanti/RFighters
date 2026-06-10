local ModuleScript = script.Parent.Parent.Parent.Settings
local Settings = require(ModuleScript)

script.Parent.Parent.Visible = true
script.Parent.Visible = true

local Players = game:GetService("Players")
local player = Players.LocalPlayer -- Obtém o jogador local

local HUD = player.PlayerGui:WaitForChild("UI"):WaitForChild("HUD")
HUD.Interactable = false

local BackgroundIds = {
	"rbxassetid://123981366649981",
	"rbxassetid://73890718232005"
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local AssetFolder = Settings.LoadingScreen.AssetFolder:GetDescendants()
local LoadingBarTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
local ButtonTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out) -- Animação dos botões

--local LoadingEvent = game.ReplicatedStorage.TriggerLoad

-- SETTINGS CONFIG, I KNOW THIS SUCKS.

if Settings.LoadingScreen.SkipButton == true then
	script.Parent.Elements.Skip.Visible = true
else
	script.Parent.Elements.Skip.Visible = false
end

if Settings.LoadingScreen.LoadingBar == true then
	script.Parent.LoadingBar.Visible = true
else
	script.Parent.LoadingBar.Visible = false
end

script.Parent.Elements.Background.Image = Settings.LoadingScreen.BackgroundImage
script.Parent.Elements.TopText.Text = Settings.LoadingScreen.TopText
script.Parent.Elements.BottomText.Text = Settings.LoadingScreen.BottomText

-- LOAD THE EXPERIENCE

local function Load(fld)
	local Folder = fld or AssetFolder
	local LoadAssets = #Folder
	
	local BackgroundUI = script.Parent.Elements.Background
	local RandomID = BackgroundIds[math.random(1, #BackgroundIds)]
	BackgroundUI.Image = RandomID

	for i, v in pairs(Folder) do
		ContentProvider:PreloadAsync({v})
		TweenService:Create(script.Parent.LoadingBar.LoadingBar, LoadingBarTweenInfo, {Size = UDim2.new(i/LoadAssets,0,1,0)}):Play()
	end

	local GradientTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	TweenService:Create(script.Parent.Parent.UIGradient, GradientTweenInfo, {Offset = Vector2.new(-1,0)}):Play()

	print("Assets loaded.")
	
	HUD.Interactable = true

	wait(1)

	script.Parent.Visible = false
	script.Parent.Parent.UIGradient:Destroy()

	script.Parent.Parent.Parent:Destroy()
end

--[[
LoadingEvent.OnClientEvent:Connect(function()
	warn('EVENT LOAD TRIGGEREGRG')
	Load(game.ReplicatedStorage.SkillStorage)
end)
]]

Load()
