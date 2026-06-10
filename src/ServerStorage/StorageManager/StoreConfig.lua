local PlayerState = require(game:GetService("ReplicatedStorage").PlayerState.PlayerStateServer)
local SlotServer = require(game:GetService("ServerScriptService").Server.UI.SlotServer)
local GiftServer    = require(game:GetService("ServerScriptService").Server.UI.GiftSlotServer)
local EmotesServer = require(game:GetService("ServerScriptService").Server.UI.EmotesServer)
local EmotesData = require(game:GetService("ReplicatedStorage").UI.Systems.Emotes.EmotesData)
local UnlockSkinEvent: BindableEvent = game:GetService("ReplicatedStorage").Events.Skins:WaitForChild("UnlockSkin")
local GiftPurchaseEvent: RemoteEvent = game:GetService("ReplicatedStorage").Events:WaitForChild("GiftSlotPurchaseEvent")
local UpdateShopDiscountsEvent: RemoteEvent = game:GetService("ReplicatedStorage").Events:WaitForChild("UpdateShopDiscounts")

local StoreConfig = {}

StoreConfig.Gamepasses = {
	["1822156357"] = function(player)
		PlayerState.Set(player, "HasVIP", true)
		PlayerState.Increment(player, "Crystals", 500)
	end,
	
	["1820945671"] = function(player)
		PlayerState.Set(player, "Has2xLuck", true)
	end,

	["1821113626"] = function(player)
		PlayerState.Set(player, "Has2xCrystals", true)
	end,

	["1818673261"] = function(player)
		PlayerState.Set(player, "Has2xXP", true)
	end,
	
	["1867393182"] = function(player)
		PlayerState.Set(player, "HasBattlepassPremium", true)
	end,
	
	["1861482165"] = function(player) -- anime emotes
		for key, _ in pairs(EmotesData.Emotes.ANIME) do
			EmotesServer.GiveEmote(player, key) 
		end
	end,
	
	["1859909683"] = function(player) -- toxic emotes
		for key, _ in pairs(EmotesData.Emotes.TOXIC) do
			EmotesServer.GiveEmote(player, key)
		end
	end,
	
	["1861806892"] = function(player) -- shiro alternate style
		UnlockSkinEvent:Fire(player, "Shiro", "AlternateStyle")
	end,
	
	["1860804120"] = function(player) -- shiro alternate style
		UnlockSkinEvent:Fire(player, "Bolg", "AlternateStyle")
	end,
	
	["1861025072"] = function(player) -- shiro alternate style
		UnlockSkinEvent:Fire(player, "Draug", "AlternateStyle")
	end,
}

StoreConfig.Products = {
	["3537313634"] = function(player)
		PlayerState.Increment(player, "Crystals", 350)
	end,
	
	["3561088373"] = function(player)
		PlayerState.Increment(player, "Crystals", 750)
	end,
	
	["3583555727"] = function(player)
		PlayerState.Increment(player, "Crystals", 750)
		PlayerState.Set(player, 'ClaimedCrystalDiscount', true)
		UpdateShopDiscountsEvent:FireClient(player, 'Disable10000CrystalsDiscount')
	end,
	
	["3561089212"] = function(player)
		PlayerState.Increment(player, "Crystals", 1250)
	end,
	
	["3561089500"] = function(player)
		PlayerState.Increment(player, "Crystals", 95000)
	end,
	
	["3551935497"] = function(player)
		PlayerState.Increment(player, "Rolls", 3)
	end,
	
	["3537325312"] = function(player)
		PlayerState.Increment(player, "Rolls", 5)
	end,
	
	["3561009249"] = function(player)
		PlayerState.Increment(player, "Rolls", 10)
	end,
	
	["3537326134"] = function(player)
		PlayerState.Increment(player, "Rolls", 25)
	end,
	
	["3583555464"] = function(player)
		PlayerState.Increment(player, "Rolls", 25)
		PlayerState.Set(player, 'ClaimedRollDiscount', true)
		UpdateShopDiscountsEvent:FireClient(player, 'Disable25RollsDiscount')
	end,
	
	["3603538714"] = function(player)
		PlayerState.Increment(player, "Crystals", 150)
		PlayerState.Set(player, 'ClaimedStarterBundle', true)
		UpdateShopDiscountsEvent:FireClient(player, 'HideFTUEPopup')
		UnlockSkinEvent:Fire(player, "Sparrow", "AlternateStyle")
	end,
	
	["3579481656"] = function(player)
		PlayerState.Increment(player, "Diamonds", 350)
	end,

	["3579481775"] = function(player)
		PlayerState.Increment(player, "Diamonds", 750)
	end,

	["3579481864"] = function(player)
		PlayerState.Increment(player, "Diamonds", 1250)
	end,

	["3579481965"] = function(player)
		PlayerState.Increment(player, "Diamonds", 95000)
	end,

	
	["3537333479"] = function(player)
		--fazer a logica do pack de Fogo
		PlayerState.Increment(player, "Crystals", 10000)
		--PlayerState.Increment(player, "Diamonds", 10000)
		PlayerState.Increment(player, "Rolls", 10)
		UnlockSkinEvent:Fire(player, "Bolg", "AlternateStyle")
	end,

	["3537333976"] = function(player)
		--fazer a logica do pack de Gelo
		PlayerState.Increment(player, "Crystals", 5000)
		PlayerState.Increment(player, "Diamonds", 5000)
		UnlockSkinEvent:Fire(player, "Draug", "AlternateStyle")
		--PlayerState.Increment(player, "Rolls", 100)
	end,
	
	--2X Luck
	["3538144708"] = function(player)
		warn(" COMPRADO 2X LUCK")
	end,
	
	--4x Luck
	["3538144935"] = function(player)
		warn("COMPRADO 4X LUCK")
	end,
	
	--2x xp
	["3538146162"] = function(player)
		warn(" COMPRADO 2X XP")
	end,
	
	--4x xp
	["3538146466"] = function(player)
		warn(" COMPRADO 4X Xp")
	end,
	
	--2x crystalls
	["3538145688"] = function(player)
		warn(" COMPRADO 2X crystalls")
	end,
	
	--4x crystalls
	["3538145857"] = function(player)
		warn(" COMPRADO 4x crystalls")
	end,
	

	["3573095511"] = function(player)
		local targetName = GiftServer.GetPending(player.UserId)
		if targetName then
			local target = game:GetService("Players"):FindFirstChild(targetName)
			if target then
				SlotServer.GiveSlot(target, 1)
				GiftPurchaseEvent:FireClient(target, "GiftReceived", player.Name)
				print(`[Store] {player.Name} gifted slot para {target.Name}`)
			else
				warn(`[Store] Target "{targetName}" saiu antes do ProcessReceipt.`)
			end
			GiftServer.ClearPending(player.UserId)
		else
			-- Sem pending: dá pro próprio comprador
			SlotServer.GiveSlot(player, 1)
		end
	end,
	
	["3573175827"] = function(player)
		warn(" COMPRADO Slot")
		SlotServer.GiveSlot(player)
	end,
}


return StoreConfig