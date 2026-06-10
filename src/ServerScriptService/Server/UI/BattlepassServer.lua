local module = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

---------------- MODULES ----------------

local BattlepassData = require(ReplicatedStorage.UI.Systems.Battlepass.BattlepassData)
local PlayerState = require(ReplicatedStorage.PlayerState.PlayerStateServer)

---------------- EVENTS ----------------

local ClaimEvent: RemoteEvent = ReplicatedStorage.Events.Battlepass.ClaimEvent
local UnlockSkinEvent: BindableEvent = ReplicatedStorage.Events.Skins:WaitForChild("UnlockSkin")

---------------- HELPERS ----------------

local function GiveReward(player, data)
	if data.Type == "Diamonds" then
		PlayerState.Increment(player, "Diamonds", data.Amount)

	elseif data.Type == "Crystals" then
		PlayerState.Increment(player, "Crystals", data.Amount)

	elseif data.Type == "Rolls" then
		PlayerState.Increment(player, "Rolls", data.Amount)

	elseif data.Type == "Skin" then
		UnlockSkinEvent:Fire(player, data.SkinCharacter, data.SkinName)
	end
end

-- Mesma lógica de validação do client, porém autoritativa no server
local function GetRewardStatus(player, rankNumber, isPremium, isFirst)
	local playerHasPremium       = PlayerState.Get(player, "HasBattlepassPremium")
	local playerLevel            = PlayerState.Get(player, "Level")
	local claimedBattlepassRewards = PlayerState.Get(player, "ClaimedBattlepassRewards")

	if isPremium and not playerHasPremium then
		return "Locked"
	end

	if rankNumber and playerLevel < rankNumber then
		return "Locked"
	end

	local typeKey  = isPremium and "Premium" or "Free"
	local typeData = claimedBattlepassRewards[typeKey]

	if isFirst and typeData.First == true then
		return "Claimed"
	end

	if not isFirst and typeData.Ranks[tostring(rankNumber)] == true then
		return "Claimed"
	end

	return "Claimable"
end

local function MarkAsClaimed(player, rankNumber, isPremium, isFirst)
	local claimedBattlepassRewards = PlayerState.Get(player, "ClaimedBattlepassRewards")
	local typeKey = isPremium and "Premium" or "Free"

	-- Clona profundamente para não mutar a referência diretamente
	local updated = {
		Free    = { First = claimedBattlepassRewards.Free.First,    Ranks = {} },
		Premium = { First = claimedBattlepassRewards.Premium.First, Ranks = {} },
	}

	for k, v in pairs(claimedBattlepassRewards.Free.Ranks) do
		updated.Free.Ranks[k] = v
	end
	for k, v in pairs(claimedBattlepassRewards.Premium.Ranks) do
		updated.Premium.Ranks[k] = v
	end

	if isFirst then
		updated[typeKey].First = true
	else
		updated[typeKey].Ranks[tostring(rankNumber)] = true
	end

	PlayerState.Set(player, "ClaimedBattlepassRewards", updated)
end

---------------- HANDLERS ----------------

local function HandleGetFirstReward(player, isPremium)
	local status = GetRewardStatus(player, nil, isPremium, true)

	if status ~= "Claimable" then
		warn("[BattlepassServer] FirstReward bloqueado para", player.Name, "| isPremium:", isPremium, "| status:", status)
		return
	end

	local typeKey  = isPremium and "Premium" or "Free"
	local rewardData = BattlepassData.BattlepassData.FirstRewards[typeKey]

	GiveReward(player, rewardData)
	MarkAsClaimed(player, nil, isPremium, true)
end

local function HandleClaimReward(player, args)
	if type(args) ~= "table" then return end

	local rank      = tonumber(args.Rank)
	local isPremium = args.IsPremium == true

	if not rank then
		warn("[BattlepassServer] Rank inválido recebido de", player.Name, " Args.Rank: ", args.Rank)
		return
	end

	local status = GetRewardStatus(player, rank, isPremium, false)

	if status ~= "Claimable" then
		warn("[BattlepassServer] Reward bloqueado para", player.Name, "| rank:", rank, "| isPremium:", isPremium, "| status:", status)
		return
	end

	local typeKey    = isPremium and "Premium" or "Free"
	local rewardData = BattlepassData.BattlepassData.Rewards[typeKey][rank]

	if not rewardData then
		warn("[BattlepassServer] Reward não encontrado no BattlepassData | rank:", rank, "| isPremium:", isPremium)
		return
	end

	GiveReward(player, rewardData)
	MarkAsClaimed(player, rank, isPremium, false)
end

---------------- INIT ----------------

ClaimEvent.OnServerEvent:Connect(function(player, action, args)
	if action == "GetFirstFreeReward" then
		HandleGetFirstReward(player, false)

	elseif action == "GetFirstPremiumReward" then
		HandleGetFirstReward(player, true)

	elseif action == "ClaimReward" then
		HandleClaimReward(player, args)

	else
		warn("[BattlepassServer] Action desconhecida recebida de", player.Name, ":", action)
	end
end)


return module