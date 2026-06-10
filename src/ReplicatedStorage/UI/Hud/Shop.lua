local module = {}

local updateEvent = game.ReplicatedStorage.Events:WaitForChild("UpdateShopDiscounts")

local Players           = game:GetService("Players")
local SoundService      = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst   = game:GetService("ReplicatedFirst")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local PlayerState       = require(game.ReplicatedStorage.PlayerState.PlayerStateClient)

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui   = localPlayer:WaitForChild("PlayerGui")

local Main: PlayerGui      = PlayerGui:WaitForChild("UI", 15) :: PlayerGui
local UIScript             = script.Parent.Parent
local Effects              = require(UIScript:WaitForChild("Effects"))
local DailyRewards = Main:WaitForChild("DailyRewards")
local FTUEPopup = Main:WaitForChild('FTUEPopup')
local FTUEPopupMain = FTUEPopup:WaitForChild('MAIN')
local FTUEButton = Main:WaitForChild('FTUESmallPopup')
local ShopFrame = Main:WaitForChild('Shop')
local ShopMain = ShopFrame:WaitForChild('MAIN')
local ShopScrollingFrame = ShopMain:WaitForChild('ScrollingFrame')

local Discount25RollsContainer = ShopScrollingFrame:WaitForChild('25Rolls')
local Discount10000CrystalsContainer = ShopScrollingFrame:WaitForChild('10000Crystals')

local LimitedOffersTimer = Main.Shop.MAIN.ScrollingFrame:WaitForChild("LimitedOffersTimer")
local TimerLabel  = LimitedOffersTimer:WaitForChild("TextLabel")
local TimerLabel2 = TimerLabel:WaitForChild("TextLabel2")

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	return string.format("%02d:%02d:%02d", h, m, s)
end

function module.ButtonAction(button: GuiButton, action)
	if action == "ShowFTUEHudButton" then
		if PlayerState.Get("ClaimedStarterBundle") == true then return end
		if FTUEPopup.Visible then Effects.ToggleUI(FTUEPopup) end
		if not FTUEButton.Visible then Effects.ToggleUI(FTUEButton) end
	end
end

updateEvent.OnClientEvent:Connect(function(action, args)
	if action == 'Enable25RollsDiscount' then
		Discount25RollsContainer.Discount.Visible = true
		Discount25RollsContainer.Normal.Visible = false
		Discount25RollsContainer.SaleText.Visible = true
		
	elseif action == 'Disable25RollsDiscount' then
		Discount25RollsContainer.Discount.Visible = false
		Discount25RollsContainer.Normal.Visible = true
		Discount25RollsContainer.SaleText.Visible = false
		
	elseif action == 'Enable10000CrystalsDiscount' then
		Discount10000CrystalsContainer.Discount.Visible = true
		Discount10000CrystalsContainer.Normal.Visible = false
		Discount10000CrystalsContainer.SaleText.Visible = true
		
	elseif action == 'Disable10000CrystalsDiscount' then
		Discount10000CrystalsContainer.Discount.Visible = false
		Discount10000CrystalsContainer.Normal.Visible = true
		Discount10000CrystalsContainer.SaleText.Visible = false
	elseif action == 'ShowFTUEPopup' then
		if PlayerState.Get("ClaimedStarterBundle") == true then return end
		if not FTUEPopup.Visible then
			Effects.ToggleUI(FTUEPopup)
		end
		
	elseif action == "HideFTUEPopup" then
		if FTUEPopup.Visible then
			Effects.ToggleUI(FTUEPopup)
		end
		
	elseif action == "ShowDailyRewards" then
		if not DailyRewards.Visible then
			Effects.ToggleUI(DailyRewards)
		end
		
	elseif action == "StartDiscountTimer" then
		local expiry = args -- args aqui é o timestamp de expiração

		task.spawn(function()
			while true do
				local remaining = expiry - os.time()

				if remaining <= 0 then
					TimerLabel.Text  = "00:00:00"
					TimerLabel2.Text = "00:00:00"
					FTUEButton.Visible = false
					LimitedOffersTimer.Visible = false
					return
				end

				local formatted = formatTime(remaining)
				TimerLabel.Text  = formatted
				TimerLabel2.Text = formatted

				task.wait(1)
			end
		end)
	end
end)

return module