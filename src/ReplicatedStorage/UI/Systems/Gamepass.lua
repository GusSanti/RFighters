local module = {}

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local function setupButton(button: GuiButton)
	button.MouseButton1Click:Connect(function()
		local id = button:GetAttribute("ID")
		if not id then 
			warn(`[Store] Botão {button.Name} está sem o Atributo 'ID'!`)
			return 
		end

		if CollectionService:HasTag(button, "Gamepass") then
			MarketplaceService:PromptGamePassPurchase(localPlayer, tonumber(id))
		elseif CollectionService:HasTag(button, "Product") then
			MarketplaceService:PromptProductPurchase(localPlayer, tonumber(id))
		end
	end)
end

function module.Init()
	local function handleTags(tagName)
		for _, btn in ipairs(CollectionService:GetTagged(tagName)) do
			if btn:IsA("GuiButton") then setupButton(btn) end
		end
		CollectionService:GetInstanceAddedSignal(tagName):Connect(function(instance)
			if instance:IsA("GuiButton") then setupButton(instance) end
		end)
	end

	handleTags("Gamepass")
	handleTags("Product")
end

return module