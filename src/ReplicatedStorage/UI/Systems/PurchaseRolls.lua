local PurchaseRolls = {}

local localPlayer = game.Players.LocalPlayer
if not game:IsLoaded() then game.Loaded:Wait() end

local PlayerState = require(game.ReplicatedStorage.PlayerState.PlayerStateClient)
local Effects = require(script.Parent.Parent.Effects)

local playerGui = localPlayer:WaitForChild("PlayerGui")
local MainUI = playerGui:WaitForChild("UI")
local RollsUI = MainUI:WaitForChild('Roll')
local RollShopUI = RollsUI:WaitForChild('RollShop')

function PurchaseRolls.ButtonAction(button: GuiButton, action)
	if action == "BuyRollFrame" then
		Effects.ToggleUI(RollShopUI)
	end
	
	if action == "Buy3Rolls" or action == "Buy5Rolls" or action == "Buy10Rolls" or action == "Buy25Rolls" then
		game.ReplicatedStorage.Events.PurchaseRolls:FireServer(action)
	end
end

return PurchaseRolls
