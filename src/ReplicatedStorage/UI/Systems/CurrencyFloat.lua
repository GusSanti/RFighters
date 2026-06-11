local module = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyEffect = require(ReplicatedStorage.Modules.CurrencyEffect)
local PlayerState = require(ReplicatedStorage.PlayerState.PlayerStateClient)

local initialized = false
local currentAmounts = {
	Crystals = 0,
	Diamonds = 0,
}

local function bindCurrency(currencyKey)
	PlayerState.OnChanged(currencyKey, function(newAmount)
		local numericAmount = tonumber(newAmount) or 0
		local lastAmount = currentAmounts[currencyKey] or 0

		if numericAmount > lastAmount then
			CurrencyEffect.castEffect(currencyKey, numericAmount - lastAmount)
		end

		currentAmounts[currencyKey] = numericAmount
	end)
end

function module.Init()
	if initialized then
		return
	end

	initialized = true
	currentAmounts.Crystals = tonumber(PlayerState.Get("Crystals")) or 0
	currentAmounts.Diamonds = tonumber(PlayerState.Get("Diamonds")) or 0

	bindCurrency("Crystals")
	bindCurrency("Diamonds")
end

return module
