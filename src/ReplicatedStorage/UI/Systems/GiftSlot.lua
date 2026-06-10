local module = {}
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local StarterGui         = game:GetService("StarterGui")

local Player    = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

local GiftRemoteFunction: RemoteFunction = ReplicatedStorage.Events:WaitForChild("GiftSlotRemoteFunction")
local GiftPurchaseEvent:  RemoteEvent   = ReplicatedStorage.Events:WaitForChild("GiftSlotPurchaseEvent")

local UI       = PlayerGui:WaitForChild("UI")
local GiftSlot = UI:WaitForChild("GiftSlot")
local MAIN     = GiftSlot:WaitForChild("MAIN")
local Close    = MAIN:WaitForChild("Close")
local Redem    = MAIN:WaitForChild("Redem")
local TextBox  = MAIN:WaitForChild("CodesMain"):WaitForChild("TextBox")

local GIFT_PRODUCT_ID = 3573095511

local function notify(title: string, text: string, duration: number?)
	StarterGui:SetCore("SendNotification", {
		Title    = title,
		Text     = text,
		Duration = duration or 4,
	})
end

local function setTextBoxError(msg: string)
	TextBox.TextColor3 = Color3.fromRGB(255, 0, 0)
	TextBox.Text       = msg
	task.delay(2, function()
		TextBox.Text       = ""
		TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	end)
end

Redem.MouseButton1Click:Connect(function()
	local targetName = TextBox.Text
	if targetName == "" or targetName:match("^%s*$") then return end

	local ok, errMsg = GiftRemoteFunction:InvokeServer("ValidateTarget", targetName)
	if not ok then
		setTextBoxError("Error")
		notify("Error", errMsg, 3)
		return
	end

	notify("Gift", `Purchasing slot for: {targetName}`, 3)
	MarketplaceService:PromptProductPurchase(Player, GIFT_PRODUCT_ID)
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
	if productId ~= GIFT_PRODUCT_ID then return end

	if wasPurchased then
		notify("Success!", "Gift slot sent!", 5)
		TextBox.Text = ""
	else
		notify("Cancelled", "Purchase cancelled.", 3)
		GiftPurchaseEvent:FireServer("CancelGift")
	end
end)

GiftPurchaseEvent.OnClientEvent:Connect(function(action: string, senderName: string)
	if action == "GiftReceived" then
		notify("🎁 Gift Received!", `{senderName} sent you 1 slot as a gift!`, 6)
	end
end)

Close.MouseButton1Click:Connect(function()
	GiftSlot.Visible = false
end)

function module.Init()
	print("[GiftSlot] Initialized")
end

return module