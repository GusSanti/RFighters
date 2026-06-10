local module = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local PlayerState = require(ReplicatedStorage.PlayerState.PlayerStateServer)

local RedeemCodeRF = ReplicatedStorage.Events.RedemCodeRemoteFunction

local CodesList = {
	["RELEASE"] = { Crystals = 10, Diamonds = 10 },
	["200K"] = { Diamonds = 500, Xp = 200 },
	["EPIC_START"] = { Level = 1, Spins = 10, Crystals = 50 }
}

RedeemCodeRF.OnServerInvoke = function(player, codeString)
	local codeUpper = string.upper(codeString)

	local rewards = CodesList[codeUpper]
	if not rewards then
		return false, "Código inválido ou expirado."
	end

	local alreadyRedeemed = PlayerState.GetFromDict(player, "RedeemedCodes", codeString)
	if alreadyRedeemed then
		return false, "Você já resgatou este código!"
	end

	for statName, amount in pairs(rewards) do
		PlayerState.Increment(player, statName, amount)
	end

	PlayerState.SetInDict(player, "RedeemedCodes", codeString, true)

	return true, rewards
end

return module