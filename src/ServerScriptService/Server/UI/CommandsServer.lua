local CommandsServer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterInfo = require(ReplicatedStorage.CharacterInfo.CharacterInfoModule)
local KnockbackProfiles = require(ServerStorage.CombatStorage.GlobalStorage.KnockbackProfiles)

local CombatCharacterStorage = ServerStorage:WaitForChild("CombatStorage"):WaitForChild("CharacterStorage")
local CommandDataRemote = ReplicatedStorage
	:WaitForChild("Events")
	:WaitForChild("Commands")
	:WaitForChild("GetCommandData")

local CHARACTER_SKILL_TOKENS = { "SKILL1", "SKILL2", "ULTIMATE", "SKILL3", "SKILL4" }
local PROFILE_NAME_BY_REFERENCE = {}
local CharacterCache = {}

type CommandEntry = {
	label: string,
	tokens: { string },
}

type CommandPayload = {
	characterId: string,
	characterName: string,
	entries: { CommandEntry },
}

for profileName, profileValue in pairs(KnockbackProfiles) do
	if typeof(profileValue) == "table" then
		PROFILE_NAME_BY_REFERENCE[profileValue] = profileName
	end
end

local function splitCamelCase(value: string): string
	local withSpaces = value:gsub("(%l)(%u)", "%1 %2")
	return withSpaces:gsub("_", " ")
end

local function getCharacterInfo(characterId: string)
	for _, characterData in ipairs(CharacterInfo) do
		if characterData.id == characterId then
			return characterData
		end
	end

	return nil
end

local function buildRepeatedTokens(token: string, count: number, prefixToken: string?): { string }
	local tokens = {}

	if prefixToken then
		table.insert(tokens, prefixToken)
	end

	for _ = 1, count do
		table.insert(tokens, token)
	end

	return tokens
end

local function getDescriptorFromProfileName(profileName: string, knockbackData: any): string?
	if profileName == "None" then
		return nil
	end

	if string.find(profileName, "Launcher", 1, true) or string.find(profileName, "UpKnockback", 1, true) then
		return "Launcher"
	end

	if string.find(profileName, "Slide", 1, true) then
		return "Slide"
	end

	if string.find(profileName, "Pull", 1, true) then
		return "Pull"
	end

	if string.find(profileName, "Push", 1, true) then
		return "Push"
	end

	if string.find(profileName, "MaintainAir", 1, true) then
		return "Air"
	end

	if knockbackData
		and typeof(knockbackData) == "table"
		and knockbackData.KnockdownInfo
		and knockbackData.KnockdownInfo.CanContinueCombo
	then
		return "Combo Extend"
	end

	return nil
end

local function getAttackDescriptor(attackData: any): string?
	if typeof(attackData) ~= "table" then
		return nil
	end

	local knockbackTable = attackData.Knockback
	if typeof(knockbackTable) ~= "table" then
		return nil
	end

	local probeOrder = { "Enemy", "EnemyAir", "Self", "SelfAir" }

	for _, probeKey in ipairs(probeOrder) do
		local knockbackData = knockbackTable[probeKey]
		if typeof(knockbackData) ~= "table" then
			continue
		end

		local profileName = PROFILE_NAME_BY_REFERENCE[knockbackData.Profile]
		if profileName then
			local descriptor = getDescriptorFromProfileName(profileName, knockbackData)
			if descriptor then
				return descriptor
			end
		end
	end

	return nil
end

local function appendEntry(entries: { CommandEntry }, label: string, tokens: { string })
	table.insert(entries, {
		label = label,
		tokens = tokens,
	})
end

local function appendSequenceEntries(entries: { CommandEntry }, prefixLabel: string, token: string, sequenceTable: any, startIndex: number, prefixToken: string?)
	if typeof(sequenceTable) ~= "table" then
		return
	end

	local orderedIndexes = {}
	for index in pairs(sequenceTable) do
		if typeof(index) == "number" and index >= startIndex then
			table.insert(orderedIndexes, index)
		end
	end
	table.sort(orderedIndexes)

	for _, index in ipairs(orderedIndexes) do
		local descriptor = getAttackDescriptor(sequenceTable[index])
		local label = string.format("%s %d", prefixLabel, index)
		if descriptor then
			label = string.format("%s - %s", label, descriptor)
		end

		appendEntry(entries, label, buildRepeatedTokens(token, index, prefixToken))
	end
end

local function appendSpecialComboEntries(entries: { CommandEntry }, combosTable: any)
	if typeof(combosTable) ~= "table" then
		return
	end

	local comboNames = {}
	for comboName in pairs(combosTable) do
		table.insert(comboNames, comboName)
	end
	table.sort(comboNames)

	for _, comboName in ipairs(comboNames) do
		local comboData = combosTable[comboName]
		if typeof(comboData) ~= "table" or typeof(comboData.Combo) ~= "table" then
			continue
		end

		appendEntry(entries, splitCamelCase(comboName), table.clone(comboData.Combo))
	end
end

local function buildCharacterPayload(characterId: string): CommandPayload
	local cachedPayload = CharacterCache[characterId]
	if cachedPayload then
		return cachedPayload
	end

	local characterInfo = getCharacterInfo(characterId)
	local characterName = characterInfo and characterInfo.name or characterId
	local payload: CommandPayload = {
		characterId = characterId,
		characterName = characterName,
		entries = {},
	}

	local characterFolder = CombatCharacterStorage:FindFirstChild(characterId)
	local storageModule = characterFolder and characterFolder:FindFirstChild("StorageModule")
	if not storageModule then
		CharacterCache[characterId] = payload
		return payload
	end

	local ok, characterStorageModule = pcall(require, storageModule)
	if not ok then
		warn(string.format("[CommandsServer] Failed to require StorageModule for %s: %s", characterId, characterStorageModule))
		CharacterCache[characterId] = payload
		return payload
	end

	if characterInfo and characterInfo.Skills then
		for index, skillData in ipairs(characterInfo.Skills) do
			local token = CHARACTER_SKILL_TOKENS[index]
			if token then
				appendEntry(payload.entries, skillData.name, { token })
			end
		end
	end

	local logic = characterStorageModule.Logic or {}
	local sequences = logic.Sequences or {}
	local hardSequences = sequences.HardAtks or {}

	appendSequenceEntries(payload.entries, "M1 Combo", "LIGHTATK", sequences.LightAtks, 2)
	appendSequenceEntries(payload.entries, "M2 Combo", "HARDATK", hardSequences.Standing, 2)
	appendSequenceEntries(payload.entries, "Crouch M2 Combo", "HARDATK", hardSequences.Crouching, 1, "CROUCH")
	appendSpecialComboEntries(payload.entries, logic.Combos)

	CharacterCache[characterId] = payload
	return payload
end

function CommandsServer.ServerInit()
	CommandDataRemote.OnServerInvoke = function(_, characterId: string?)
		if typeof(characterId) ~= "string" or characterId == "" then
			return nil
		end

		return buildCharacterPayload(characterId)
	end
end

return CommandsServer
