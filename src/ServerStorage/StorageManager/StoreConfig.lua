local PlayerState = require(game:GetService("ReplicatedStorage").PlayerState.PlayerStateServer)
local SlotServer = require(game:GetService("ServerScriptService").Server.UI.SlotServer)
local GiftServer    = require(game:GetService("ServerScriptService").Server.UI.GiftSlotServer)
local EmotesServer = require(game:GetService("ServerScriptService").Server.UI.EmotesServer)
local EmotesData = require(game:GetService("ReplicatedStorage").UI.Systems.Emotes.EmotesData)
local UnlockSkinEvent: BindableEvent = game:GetService("ReplicatedStorage").Events.Skins:WaitForChild("UnlockSkin")
local GiftPurchaseEvent: RemoteEvent = game:GetService("ReplicatedStorage").Events:WaitForChild("GiftSlotPurchaseEvent")
local UpdateShopDiscountsEvent: RemoteEvent = game:GetService("ReplicatedStorage").Events:WaitForChild("UpdateShopDiscounts")
local NotificationModule = require(game.ReplicatedStorage.Modules.NotificationModule)

local StoreConfig = {}

StoreConfig.Gamepasses = {
	["1822156357"] = function(player)
		PlayerState.Set(player, "HasVIP", true)
		NotificationModule.SendMessageToClient(player, "You Have Bought VIP!")
	end,
	
	["1820945671"] = function(player)
		PlayerState.Set(player, "Has2xLuck", true)
		NotificationModule.SendMessageToClient(player, "You Have Bought 2x Luck!")
	end,

	["1821113626"] = function(player)
		PlayerState.Set(player, "Has2xCrystals", true)
		NotificationModule.SendMessageToClient(player, "You Have Bought 2x Crystals!")
	end,

	["1818673261"] = function(player)
		PlayerState.Set(player, "Has2xXP", true)
		NotificationModule.SendMessageToClient(player, "You Have Bought 2x XP!")
	end,
	
	["1867393182"] = function(player)
		PlayerState.Set(player, "HasBattlepassPremium", true)
		NotificationModule.SendMessageToClient(player, "You Have Bought Battlepass!")
	end,
	
	["1861482165"] = function(player) -- anime emotes
		for key, _ in pairs(EmotesData.Emotes.ANIME) do
			EmotesServer.GiveEmote(player, key) 
		end
		NotificationModule.SendMessageToClient(player, "You Have Bought Anime Emotes!")
	end,
	
	["1859909683"] = function(player) -- toxic emotes
		for key, _ in pairs(EmotesData.Emotes.TOXIC) do
			EmotesServer.GiveEmote(player, key)
		end
		NotificationModule.SendMessageToClient(player, "You Have Bought Toxic Emotes!")
	end,
	
	["1861806892"] = function(player) -- shiro alternate style
		UnlockSkinEvent:Fire(player, "Shiro", "AlternateStyle")
		NotificationModule.SendMessageToClient(player, "You Have Bought Shiro Alternate Style Skin!")
	end,
	
	["1860804120"] = function(player) -- shiro alternate style
		UnlockSkinEvent:Fire(player, "Bolg", "AlternateStyle")
		NotificationModule.SendMessageToClient(player, "You Have Bought Bolg Alternate Style Skin!")
	end,
	
	["1861025072"] = function(player) -- shiro alternate style
		UnlockSkinEvent:Fire(player, "Draug", "AlternateStyle")
		NotificationModule.SendMessageToClient(player, "You Have Bought Draug Alternate Style Skin!")
	end,
}

StoreConfig.Products = {
	["3537313634"] = function(player)
		PlayerState.Increment(player, "Crystals", 350)
		NotificationModule.SendMessageToClient(player, "You Have Bought 350 Crystals!")
	end,
	
	["3561088373"] = function(player)
		PlayerState.Increment(player, "Crystals", 750)
		NotificationModule.SendMessageToClient(player, "You Have Bought 750 Crystals!")
	end,
	
	["3583555727"] = function(player)
		PlayerState.Increment(player, "Crystals", 750)
		PlayerState.Set(player, 'ClaimedCrystalDiscount', true)
		UpdateShopDiscountsEvent:FireClient(player, 'Disable10000CrystalsDiscount')
		NotificationModule.SendMessageToClient(player, "You Have Bought 750 Crystals!")
	end,
	
	["3561089212"] = function(player)
		PlayerState.Increment(player, "Crystals", 1250)
		NotificationModule.SendMessageToClient(player, "You Have Bought 1250 Crystals!")
	end,
	
	["3561089500"] = function(player)
		PlayerState.Increment(player, "Crystals", 95000)
		NotificationModule.SendMessageToClient(player, "You Have Bought 95000 Crystals!")
	end,
	
	["3551935497"] = function(player)
		PlayerState.Increment(player, "Rolls", 3)
		NotificationModule.SendMessageToClient(player, "You Have Bought 3 Rolls!")
	end,
	
	["3537325312"] = function(player)
		PlayerState.Increment(player, "Rolls", 5)
		NotificationModule.SendMessageToClient(player, "You Have Bought 5 Rolls!")
	end,
	
	["3561009249"] = function(player)
		PlayerState.Increment(player, "Rolls", 10)
		NotificationModule.SendMessageToClient(player, "You Have Bought 10 Rolls!")
	end,
	
	["3537326134"] = function(player)
		PlayerState.Increment(player, "Rolls", 25)
		NotificationModule.SendMessageToClient(player, "You Have Bought 25 Rolls!")
	end,
	
	["3583555464"] = function(player)
		PlayerState.Increment(player, "Rolls", 25)
		PlayerState.Set(player, 'ClaimedRollDiscount', true)
		UpdateShopDiscountsEvent:FireClient(player, 'Disable25RollsDiscount')
		NotificationModule.SendMessageToClient(player, "You Have Bought 25 Rolls!")
	end,
	
	["3603538714"] = function(player)
		PlayerState.Increment(player, "Crystals", 150)
		PlayerState.Set(player, 'ClaimedStarterBundle', true)
		UpdateShopDiscountsEvent:FireClient(player, 'HideFTUEPopup')
		UnlockSkinEvent:Fire(player, "Sparrow", "AlternateStyle")
		NotificationModule.SendMessageToClient(player, "You Have Bought 150 Crystals!")
	end,
	
	["3579481656"] = function(player)
		PlayerState.Increment(player, "Diamonds", 350)
		NotificationModule.SendMessageToClient(player, "You Have Bought 350 Diamonds!")
	end,

	["3579481775"] = function(player)
		PlayerState.Increment(player, "Diamonds", 750)
		NotificationModule.SendMessageToClient(player, "You Have Bought 750 Diamonds!")
	end,

	["3579481864"] = function(player)
		PlayerState.Increment(player, "Diamonds", 1250)
		NotificationModule.SendMessageToClient(player, "You Have Bought 1250 Diamonds!")
	end,

	["3579481965"] = function(player)
		PlayerState.Increment(player, "Diamonds", 95000)
		NotificationModule.SendMessageToClient(player, "You Have Bought 95000 Diamonds!")
	end,

	
	["3537333479"] = function(player)
		--fazer a logica do pack de Fogo
		PlayerState.Increment(player, "Crystals", 10000)
		--PlayerState.Increment(player, "Diamonds", 10000)
		PlayerState.Increment(player, "Rolls", 10)
		UnlockSkinEvent:Fire(player, "Bolg", "AlternateStyle")
		NotificationModule.SendMessageToClient(player, "You Have Bought the Fire Pack!")
	end,

	["3537333976"] = function(player)
		--fazer a logica do pack de Gelo
		PlayerState.Increment(player, "Crystals", 5000)
		PlayerState.Increment(player, "Diamonds", 5000)
		UnlockSkinEvent:Fire(player, "Draug", "AlternateStyle")
		--PlayerState.Increment(player, "Rolls", 100)
		NotificationModule.SendMessageToClient(player, "You Have Bought the Ice Pack!")
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
		NotificationModule.SendMessageToClient(player, "You Have Bought a Slot!")
	end,
}


return StoreConfig