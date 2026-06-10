local prompt = script.Parent
local MarketplaceService = game:GetService("MarketplaceService")

prompt.Triggered:Connect(function(player)
	MarketplaceService:PromptGamePassPurchase(player, prompt:GetAttribute("ProductID"))
end)