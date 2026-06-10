local module = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---------------- MODULES ----------------

local PlayerState       = require(ReplicatedStorage.PlayerState.PlayerStateServer)
local RewardData        = require(ReplicatedStorage.UI.Systems.IndexCharacters.IndexCharactersRewardsData)

---------------- EVENTS ----------------

local RequestEvent                 = ReplicatedStorage.Events.RequestCharacterIndexData
local RegisterNewCharacterIndexEvent = ReplicatedStorage.Events.RegisterNewCharacterIndex
local GetCharacterPoolData         = ReplicatedStorage.Events.GetCharacterPoolData
local ClaimIndexRewards            = ReplicatedStorage.Events.ClaimIndexCharactersRewards

---------------- HELPERS ----------------

local function isAlreadyRegistered(characters: {any}, charName: string): boolean
	for _, entry in ipairs(characters) do
		if entry.CharacterName == charName then
			return true
		end
	end
	return false
end

local function registerNewCharacter(plr, character)
	local characters = PlayerState.Get(plr, "CharacterIndex")
	if not characters then characters = {} end
	if isAlreadyRegistered(characters, character.CharacterName) then return end
	table.insert(characters, character)
	PlayerState.Set(plr, "CharacterIndex", characters)
end

local function registerActiveCharacter(plr)
	local character = PlayerState.Get(plr, "ActiveCharacter")
	if not character or character == "" then return end

	local characters = PlayerState.Get(plr, "CharacterIndex") or {}
	local charData = GetCharacterPoolData:Invoke(character)
	if not charData then return end
	if isAlreadyRegistered(characters, charData.name) then return end

	registerNewCharacter(plr, {
		CharacterName        = charData.name,
		CharacterDescription = charData.description,
		Skills               = charData.Skills,
	})
end

---------------- REWARD LOGIC ----------------

-- Verifica se o personagem está desbloqueado no index do player
local function IsCharacterUnlocked(plr, charName: string): boolean
	local characters = PlayerState.Get(plr, "CharacterIndex") or {}
	return isAlreadyRegistered(characters, charName)
end

-- Retorna o status do reward: "Locked" | "Claimed" | "Claimable"
local function GetRewardStatus(plr, charName: string): string
	if not IsCharacterUnlocked(plr, charName) then
		return "Locked"
	end

	if not RewardData.Rewards[charName] then
		return "Locked" -- personagem sem reward configurado
	end

	local claimed = PlayerState.Get(plr, "ClaimedIndexRewards") or {}
	if claimed[charName] == true then
		return "Claimed"
	end

	return "Claimable"
end

local function MarkAsClaimed(plr, charName: string)
	local claimed = PlayerState.Get(plr, "ClaimedIndexRewards") or {}

	-- Deep copy para não mutar a referência
	local updated = {}
	for k, v in pairs(claimed) do
		updated[k] = v
	end
	updated[charName] = true

	PlayerState.Set(plr, "ClaimedIndexRewards", updated)
end

local function GiveRewards(plr, charName: string)
	local rewards = RewardData.Rewards[charName]
	if not rewards then return end

	for _, reward in ipairs(rewards) do
		if reward.Type == "Diamonds" then
			PlayerState.Increment(plr, "Diamonds", reward.Amount)

		elseif reward.Type == "Crystals" then
			PlayerState.Increment(plr, "Crystals", reward.Amount)

		elseif reward.Type == "Rolls" then
			PlayerState.Increment(plr, "Rolls", reward.Amount)
		end
	end
end

---------------- HANDLER ----------------

local function HandleClaimReward(plr, charName)
	if type(charName) ~= "string" or charName == "" then
		warn("[CharacterIndexServer] charName inválido de", plr.Name)
		return
	end

	local status = GetRewardStatus(plr, charName)

	if status ~= "Claimable" then
		warn("[CharacterIndexServer] Reward bloqueado para", plr.Name, "| char:", charName, "| status:", status)
		return
	end

	GiveRewards(plr, charName)
	MarkAsClaimed(plr, charName)

	print("[CharacterIndexServer] Rewards entregues para", plr.Name, "| char:", charName)
end

---------------- INIT ----------------

game.Players.PlayerAdded:Connect(function(plr)
	registerActiveCharacter(plr)
end)

RegisterNewCharacterIndexEvent.Event:Connect(function(plr, character)
	registerNewCharacter(plr, character)
end)

RequestEvent.OnServerInvoke = function(plr, action, args)
	if action == "GetIndexCharacters" then
		registerActiveCharacter(plr)
		return PlayerState.Get(plr, "CharacterIndex")

	elseif action == "GetRewardStatus" then
		if type(args) ~= "string" or args == "" then return "Locked" end
		return GetRewardStatus(plr, args)

	elseif action == "ClaimIndexReward" then
		if type(args) ~= "string" or args == "" then return false end
		local status = GetRewardStatus(plr, args)
		if status ~= "Claimable" then
			warn("[CharacterIndexServer] Reward bloqueado para", plr.Name, "| char:", args, "| status:", status)
			return false
		end
		GiveRewards(plr, args)
		MarkAsClaimed(plr, args)
		print("[CharacterIndexServer] Rewards entregues para", plr.Name, "| char:", args)
		return true
	end
end

-- mantém o OnServerEvent como fallback caso queira, mas o principal agora é o invoke
ClaimIndexRewards.OnServerEvent:Connect(function(plr, charName)
	HandleClaimReward(plr, charName)
end)

return module