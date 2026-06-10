--!strict
local RollServer = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerState       = require(ReplicatedStorage.PlayerState.PlayerStateServer)
local CharacterRegistry = require(ReplicatedStorage:WaitForChild("CharacterInfo"):WaitForChild("CharacterInfoModule"))
local SlotServer = require(script.Parent.SlotServer)

local Events         = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RollSystemEvents")
local RollRemote: RemoteFunction = Events:WaitForChild("RollRequest") :: RemoteFunction
local GetCharacterPoolData = game.ReplicatedStorage.Events.GetCharacterPoolData
local RegisterNewCharacterIndexEvent = ReplicatedStorage.Events.RegisterNewCharacterIndex

local ADMINS = {
	["kaosgamess7"] = true,
	["kaosgamess9"] = true,
	["herckaos"] = true
}

local CONFIG = {
	ROLL_COOLDOWN = 1,
	ROLLS_PER_USE = 1,
}

local RARITY_WEIGHTS = {
	Common    = 57,
	Uncommon  = 25,
	Rare      = 10,
	Epic      = 6,
	Legendary = 2,
}

local PITY_THRESHOLDS = {
	Rare      = 50,
	Epic      = 100,
	Legendary = 200,
}

type PoolEntry = {
	id          : string,
	name        : string,
	rarity      : string,
	description : string,
	AnimId      : number?,
	weight      : number,
	Skills      : {string}
}

local characterPool: { PoolEntry } = {}
local totalWeight = 0

local function buildPool()
	local countPerRarity: { [string]: number } = {}
	for _, char in ipairs(CharacterRegistry) do
		countPerRarity[char.rarity] = (countPerRarity[char.rarity] or 0) + 1
	end

	for _, char in ipairs(CharacterRegistry) do
		local rarityWeight = RARITY_WEIGHTS[char.rarity]
		if not rarityWeight then
			warn(`[RollServer] Unknown rarity "{char.rarity}" on "{char.id}" — skipped`)
			continue
		end

		local weight = rarityWeight / countPerRarity[char.rarity]
		table.insert(characterPool, {
			id          = char.id,
			name        = char.name,
			rarity      = char.rarity,
			description = char.description,
			Skills      = char.Skills,
			AnimId      = char.AnimId,
			weight      = weight,
		})
		totalWeight += weight
	end

	print(`[RollServer] {#characterPool} characters loaded. Total weight: {totalWeight}`)
	for _, entry in ipairs(characterPool) do
		print(`  {entry.name} ({entry.rarity}): {string.format("%.2f", (entry.weight / totalWeight) * 100)}%`)
	end
end

-- Retorna o multiplicador de weight para uma raridade, dado o estado do player.
-- Has2xLuck dobra os pesos de Rare+ e tem prioridade sobre HasVIP.
-- HasVIP aumenta 20% os pesos de Rare+.
-- Common e Uncommon nunca recebem bônus.
local function getWeightMultiplier(player: Player, rarity: string): number
	local rarityOrder = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
	if (rarityOrder[rarity] or 0) < rarityOrder["Rare"] then
		return 1
	end

	if PlayerState.Get(player, "Has2xLuck") then
		return 2
	end

	if PlayerState.Get(player, "HasVIP") then
		return 1.2
	end

	return 1
end

local function pickCharacterForPlayer(player: Player): PoolEntry?
	if #characterPool == 0 or totalWeight <= 0 then
		warn("[RollServer] characterPool is empty")
		return nil
	end

	local adjustedTotal = 0
	local adjustedPool: { { entry: PoolEntry, adjustedWeight: number } } = {}

	for _, char in ipairs(characterPool) do
		local mult = getWeightMultiplier(player, char.rarity)
		local w = char.weight * mult
		table.insert(adjustedPool, { entry = char, adjustedWeight = w })
		adjustedTotal += w
	end

	local roll = math.random() * adjustedTotal
	local accumulated = 0
	for _, item in ipairs(adjustedPool) do
		accumulated += item.adjustedWeight
		if roll <= accumulated then
			return item.entry
		end
	end

	return adjustedPool[#adjustedPool].entry
end

local function pickCharacterOfRarityOrAboveForPlayer(player: Player, minRarity: string): PoolEntry?
	local rarityOrder = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
	local minLevel = rarityOrder[minRarity] or 3

	local filtered: { { entry: PoolEntry, adjustedWeight: number } } = {}
	local filteredWeight = 0

	for _, char in ipairs(characterPool) do
		if (rarityOrder[char.rarity] or 0) >= minLevel then
			local mult = getWeightMultiplier(player, char.rarity)
			local w = char.weight * mult
			table.insert(filtered, { entry = char, adjustedWeight = w })
			filteredWeight += w
		end
	end

	if #filtered == 0 then return nil end

	local roll = math.random() * filteredWeight
	local accumulated = 0
	for _, item in ipairs(filtered) do
		accumulated += item.adjustedWeight
		if roll <= accumulated then
			return item.entry
		end
	end

	return filtered[#filtered].entry
end

GetCharacterPoolData.OnInvoke = function(characterName)
	if characterName ~= nil and characterName ~= "" then
		for _, entry in ipairs(characterPool) do
			if entry.name:lower() == characterName:lower() or entry.id:lower() == characterName:lower() then
				return {
					id          = entry.id,
					name        = entry.name,
					rarity      = entry.rarity,
					description = entry.description,
					AnimId      = entry.AnimId,
					weight      = entry.weight,
					Skills      = entry.Skills,
					chance      = (entry.weight / totalWeight) * 100,
				}
			end
		end
		return nil
	end

	local result = {}
	for _, entry in ipairs(characterPool) do
		table.insert(result, {
			id          = entry.id,
			name        = entry.name,
			rarity      = entry.rarity,
			description = entry.description,
			AnimId      = entry.AnimId,
			weight      = entry.weight,
			Skills      = entry.Skills,
			chance      = (entry.weight / totalWeight) * 100,
		})
	end

	return result
end

local function getPityForcedRarity(pity: { [string]: number }): string?
	if (pity["Legendary"] or 0) >= PITY_THRESHOLDS.Legendary then
		return "Legendary"
	elseif (pity["Epic"] or 0) >= PITY_THRESHOLDS.Epic then
		return "Epic"
	elseif (pity["Rare"] or 0) >= PITY_THRESHOLDS.Rare then
		return "Rare"
	end
	return nil
end

local function updatePityCounters(pity: { [string]: number }, rolledRarity: string): { [string]: number }
	local rarityOrder = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
	local rolledLevel = rarityOrder[rolledRarity] or 1

	pity["Rare"]      = (pity["Rare"] or 0) + 1
	pity["Epic"]      = (pity["Epic"] or 0) + 1
	pity["Legendary"] = (pity["Legendary"] or 0) + 1

	if rolledLevel >= rarityOrder["Rare"] then
		pity["Rare"] = 0
	end
	if rolledLevel >= rarityOrder["Epic"] then
		pity["Epic"] = 0
	end
	if rolledLevel >= rarityOrder["Legendary"] then
		pity["Legendary"] = 0
	end

	return pity
end

local cooldowns: { [number]: number } = {}

local function isOnCooldown(userId: number): boolean
	local last = cooldowns[userId]
	return last ~= nil and (tick() - last) < CONFIG.ROLL_COOLDOWN
end

local function getRemainingCooldown(userId: number): number
	local last = cooldowns[userId]
	if not last then return 0 end
	return math.max(0, CONFIG.ROLL_COOLDOWN - (tick() - last))
end

local function handleRollRequest(player: Player): { success: boolean, character: any?, errorMsg: string?, remainingCooldown: number?, pityCounts: any? }
	local userId = player.UserId

	if not PlayerState.IsPlayerDataReady(player) then
		return { success = false, errorMsg = "Data is still loading." }
	end

	if isOnCooldown(userId) then
		return { success = false, errorMsg = "On cooldown.", remainingCooldown = getRemainingCooldown(userId) }
	end

	local currentRolls = PlayerState.Get(player, "Rolls") or 0
	if currentRolls < CONFIG.ROLLS_PER_USE then
		return { success = false, errorMsg = "Not enough rolls." }
	end

	cooldowns[userId] = tick()
	PlayerState.Set(player, "Rolls", currentRolls - CONFIG.ROLLS_PER_USE)

	local pity: { [string]: number } = PlayerState.Get(player, "PityCounters") or { Rare = 0, Epic = 0, Legendary = 0 }

	local forcedRarity = getPityForcedRarity(pity)

	local picked: PoolEntry?
	if forcedRarity then
		print(`[RollServer] PITY ativado para {player.Name}: garantindo {forcedRarity}+`)
		picked = pickCharacterOfRarityOrAboveForPlayer(player, forcedRarity)
	else
		picked = pickCharacterForPlayer(player)
	end

	if not picked then
		PlayerState.Set(player, "Rolls", currentRolls)
		cooldowns[userId] = nil
		return { success = false, errorMsg = "Internal error while picking character." }
	end

	local updatedPity = updatePityCounters(pity, picked.rarity)
	PlayerState.Set(player, "PityCounters", updatedPity)

	local ok = PlayerState.Set(player, "ActiveCharacter", picked.id)
	warn(`[DEBUG] Set ActiveCharacter resultado: {ok} | Valor agora: {PlayerState.Get(player, "ActiveCharacter")}`)
	RegisterNewCharacterIndexEvent:Fire(player, {CharacterName = picked.name, CharacterDescription = picked.description, Skills = picked.Skills})

	if not ok then
		warn(`[RollServer] Failed to set ActiveCharacter for {player.Name}`)
		PlayerState.Set(player, "Rolls", currentRolls)
		cooldowns[userId] = nil
		return { success = false, errorMsg = "Failed to save character." }
	end

	print(`[RollServer] {player.Name} -> {picked.name} ({picked.rarity}) | Pity: R={updatedPity.Rare} E={updatedPity.Epic} L={updatedPity.Legendary} | Rolls: {currentRolls - CONFIG.ROLLS_PER_USE}`)

	SlotServer.FillSlot(player, {
		id          = picked.id,
		name        = picked.name,
		rarity      = picked.rarity,
		description = picked.description,
		AnimId      = picked.AnimId,
	})

	return {
		success   = true,
		character = {
			id          = picked.id,
			name        = picked.name,
			rarity      = picked.rarity,
			description = picked.description,
			AnimId      = picked.AnimId,
		},
		pityCounts = updatedPity,
	}
end

local function handleAdminCommand(player: Player, message: string)
	if not ADMINS[player.Name:lower()] then return end

	local targetName, amount = message:match("^/giverolls%s+(%S+)%s+(%d+)$")
	if targetName and amount then
		local rolls = tonumber(amount)
		if not rolls or rolls <= 0 or rolls > 10000 then
			warn(`[AdminCmd] Invalid amount: {amount}`)
			return
		end

		local targetPlayer: Player? = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Name:lower() == targetName:lower() then
				targetPlayer = p
				break
			end
		end

		if not targetPlayer then
			warn(`[AdminCmd] Player "{targetName}" not found`)
			return
		end

		local function doGive()
			local current = PlayerState.Get(targetPlayer :: Player, "Rolls") or 0
			PlayerState.Set(targetPlayer :: Player, "Rolls", current + (rolls :: number))
			print(`[AdminCmd] {player.Name} gave {rolls} rolls to {(targetPlayer :: Player).Name} | Total: {current + (rolls :: number)}`)
		end

		if not PlayerState.IsPlayerDataReady(targetPlayer) then
			task.spawn(function()
				local attempts = 0
				repeat task.wait(0.5) attempts += 1
				until PlayerState.IsPlayerDataReady(targetPlayer :: Player) or attempts >= 20
				if not PlayerState.IsPlayerDataReady(targetPlayer :: Player) then
					warn(`[AdminCmd] Timeout: data for "{targetName}" never loaded`)
					return
				end
				doGive()
			end)
			return
		end

		doGive()
		return
	end

	local targetName2, charName = message:match("^/setchar%s+(%S+)%s+(.+)$")
	if targetName2 and charName then
		local targetPlayer: Player? = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Name:lower() == targetName2:lower() then
				targetPlayer = p
				break
			end
		end

		if not targetPlayer then
			warn(`[AdminCmd] Player "{targetName2}" not found`)
			return
		end

		local foundChar: PoolEntry? = nil
		for _, entry in ipairs(characterPool) do
			if entry.name:lower() == charName:lower() or entry.id:lower() == charName:lower() then
				foundChar = entry
				break
			end
		end

		if not foundChar then
			warn(`[AdminCmd] Character "{charName}" not found in pool`)
			return
		end

		local function doSet()
			local ok = PlayerState.Set(targetPlayer :: Player, "ActiveCharacter", (foundChar :: PoolEntry).id)
			if ok then
				print(`[AdminCmd] {player.Name} set {(targetPlayer :: Player).Name}'s character to {(foundChar :: PoolEntry).name}`)
			else
				warn(`[AdminCmd] Failed to set character for {(targetPlayer :: Player).Name}`)
			end
		end

		if not PlayerState.IsPlayerDataReady(targetPlayer) then
			task.spawn(function()
				local attempts = 0
				repeat task.wait(0.5) attempts += 1
				until PlayerState.IsPlayerDataReady(targetPlayer :: Player) or attempts >= 20
				if not PlayerState.IsPlayerDataReady(targetPlayer :: Player) then
					warn(`[AdminCmd] Timeout: data for "{targetName2}" never loaded`)
					return
				end
				doSet()
			end)
			return
		end

		doSet()
		return
	end
end

local function connectChat(player: Player)
	player.Chatted:Connect(function(message)
		handleAdminCommand(player, message)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	connectChat(player)
end
Players.PlayerAdded:Connect(connectChat)

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		local attempts = 0
		repeat
			task.wait(0.1)
			attempts += 1
		until PlayerState.IsPlayerDataReady(player) or attempts >= 50

		local activeChar = PlayerState.Get(player, "ActiveCharacter")
		local pity = PlayerState.Get(player, "PityCounters") or { Rare = 0, Epic = 0, Legendary = 0 }
		warn(`[RollServer] {player.Name} entrou com ActiveCharacter: {activeChar} | Pity: R={pity.Rare} E={pity.Epic} L={pity.Legendary}`)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	if PlayerState.IsPlayerDataReady(player) then
		local pity = PlayerState.Get(player, "PityCounters") or { Rare = 0, Epic = 0, Legendary = 0 }
		warn(`[DEBUG REMOVING] {player.Name} saindo com ActiveCharacter: {PlayerState.Get(player, "ActiveCharacter")} | Pity: R={pity.Rare} E={pity.Epic} L={pity.Legendary}`)
	end
	cooldowns[player.UserId] = nil
end)

buildPool()
RollRemote.OnServerInvoke = handleRollRequest

print("[RollServer] Initialized successfully")

return RollServer