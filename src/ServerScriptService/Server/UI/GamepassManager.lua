local module = {}

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local StoreConfig = require(game:GetService("ServerStorage").StorageManager.StoreConfig)

local function giveReward(player, id, isPass)
	local category = isPass and StoreConfig.Gamepasses or StoreConfig.Products
	local rewardFunc = category[tostring(id)]

	if rewardFunc then
		rewardFunc(player)
	end
end

Players.PlayerAdded:Connect(function(player)
	for passId, _ in pairs(StoreConfig.Gamepasses) do
		local success, hasPass = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, tonumber(passId))
		end)
		if success and hasPass then
			giveReward(player, passId, true)
		end
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
	if wasPurchased then
		giveReward(player, passId, true)
	end
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local success, err = pcall(function()
		giveReward(player, receiptInfo.ProductId, false)
	end)

	if success then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		warn("[Store] Erro ao processar produto: " .. err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return module
