local module = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
if not game:IsLoaded() then game.Loaded:Wait() end

---------------- MODULES ----------------

local BattlepassData = require(script.BattlepassData)
local PlayerState = require(ReplicatedStorage.PlayerState.PlayerStateClient)
local RewardNotificationModule = require(ReplicatedStorage.Modules.RewardNotificationModule)

---------------- EVENTS -----------------

local ClaimEvent = ReplicatedStorage.Events.Battlepass.ClaimEvent

---------------- UI -----------------

local playerGui = localPlayer:WaitForChild("PlayerGui")
local MainUI    = playerGui:WaitForChild("UI")

local BattlepassUI = MainUI:WaitForChild("Battlepass")
local BattlepassRewardsFrame = BattlepassUI:WaitForChild("Rewards"):WaitForChild("Rewards")
local BattlepassFirstRewards = BattlepassRewardsFrame:WaitForChild("1stRewards")

local BattlepassRewardsFreeFrame = BattlepassRewardsFrame:WaitForChild("Free")
local BattlepassRewardsPremiumFrame = BattlepassRewardsFrame:WaitForChild("Premium")
local BattlepassPremiumScrollingFrame = BattlepassRewardsPremiumFrame:WaitForChild("ScrollingFrame")
local BattlepassFreeScrollingFrame = BattlepassRewardsFreeFrame:WaitForChild("ScrollingFrame")

local FreeRewardTemplate = BattlepassFreeScrollingFrame:WaitForChild("RewardTemplate")
local PremiumRewardTemplate = BattlepassPremiumScrollingFrame:WaitForChild("RewardTemplate")

local FirstRewardsFree = BattlepassFirstRewards:WaitForChild("Free")
local FirstRewardsPremium = BattlepassFirstRewards:WaitForChild("Premium")

local function ShowBattlepassLockedNotification(isPremium)
	if isPremium then
		RewardNotificationModule.ShowLockedReward("THIS PREMIUM REWARD IS STILL LOCKED")
		return
	end

	RewardNotificationModule.ShowLockedReward("THIS BATTLEPASS REWARD IS STILL LOCKED")
end

local function GetRewardFrameFromButton(button)
	local current = button

	while current and current ~= BattlepassUI do
		if current.Parent == BattlepassFreeScrollingFrame or current.Parent == BattlepassPremiumScrollingFrame then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function HandleRewardsGroupWithData(rewardsGroupFrame, Data)
	if Data.Type == "None" then return end

	if Data.Type == "Diamonds" or Data.Type == "Crystals" or Data.Type == "Rolls" then
		local rewardGroup = rewardsGroupFrame:WaitForChild(Data.Type) :: ImageLabel
		rewardGroup.Visible = true
		rewardGroup:WaitForChild("Amount").Text = Data.Amount .. "x"
	end

	if Data.Type == "Skin" then
		local findViewportName = Data.SkinCharacter .. Data.SkinName
		local rewardGroup = rewardsGroupFrame:WaitForChild("Skin") :: ImageLabel
		local ViewportFrameSkin = rewardGroup:WaitForChild("Skins"):FindFirstChild(findViewportName)
		rewardGroup:WaitForChild("SkinName").Text = Data.SkinName

		if not ViewportFrameSkin then
			warn("VIEWPORT DE NOME: ", findViewportName, " NÃO FOI ENCONTRADO NA PASTA SKINS")
			return
		end

		rewardGroup.Visible = true
		ViewportFrameSkin.Visible = true
	end
end

local function GetBattlepassRewardStatus(rankNumber, IsPremium, IsFirst)
	local playerHasPremium = PlayerState.Get("HasBattlepassPremium")
	local playerLevel = PlayerState.Get("Level")
	local claimedBattlepassRewards = PlayerState.Get("ClaimedBattlepassRewards")

	if IsPremium and not playerHasPremium then
		return "Locked"
	end

	if tonumber(rankNumber) and playerLevel < tonumber(rankNumber) then
		return "Locked"
	end

	local typeKey = IsPremium and "Premium" or "Free"
	local typeData = claimedBattlepassRewards[typeKey]

	if IsFirst and typeData.First == true then
		return "Claimed"
	end

	if typeData.Ranks[tostring(rankNumber)] == true then
		return "Claimed"
	end

	return "Claimable"
end

local function UpdateRewardButton(button, status)
	local Collected = button:WaitForChild("Collected")
	local Locked = button:WaitForChild("Locked")

	if status == "Claimable" then
		Collected.Visible = false
		Locked.Visible = false
	end

	if status == "Locked" then
		Collected.Visible = false
		Locked.Visible = true
	end

	if status == "Claimed" then
		Collected.Visible = true
		Locked.Visible = false
	end
end

local function UpdateRewardButtons()
	UpdateRewardButton(FirstRewardsFree, GetBattlepassRewardStatus(nil, false, true))
	UpdateRewardButton(FirstRewardsPremium, GetBattlepassRewardStatus(nil, true, true))

	for _, v in BattlepassFreeScrollingFrame:GetChildren() do
		if v:IsA("Frame") and v.Name ~= "RewardTemplate" then
			UpdateRewardButton(v, GetBattlepassRewardStatus(v.Name, false, false))
		end
	end

	for _, v in BattlepassPremiumScrollingFrame:GetChildren() do
		if v:IsA("Frame") and v.Name ~= "RewardTemplate" then
			UpdateRewardButton(v, GetBattlepassRewardStatus(v.Name, true, false))
		end
	end
end

local function CreateRewards()
	------ FirstRewards -----

	local FreeFirstRewardData = BattlepassData.BattlepassData.FirstRewards.Free
	local PremiumFirstRewardData = BattlepassData.BattlepassData.FirstRewards.Premium

	local FreeFirstRewardsGroup = FirstRewardsFree:WaitForChild("RewardsGroup")
	local PremiumFirstRewardsGroup = FirstRewardsPremium:WaitForChild("RewardsGroup")

	HandleRewardsGroupWithData(FreeFirstRewardsGroup, FreeFirstRewardData)
	HandleRewardsGroupWithData(PremiumFirstRewardsGroup, PremiumFirstRewardData)

	UpdateRewardButton(FirstRewardsFree, GetBattlepassRewardStatus(nil, false, true))
	UpdateRewardButton(FirstRewardsPremium, GetBattlepassRewardStatus(nil, true, true))

	for rank, data in pairs(BattlepassData.BattlepassData.Rewards.Free) do
		local clone = FreeRewardTemplate:Clone()
		clone.Parent = BattlepassFreeScrollingFrame
		clone.LayoutOrder = rank
		clone.Name = rank
		clone.Visible = true
		clone:WaitForChild("Main"):WaitForChild("RankNumber").Text = rank
		HandleRewardsGroupWithData(clone:WaitForChild("Main"):WaitForChild("RewardsGroup"), data)
		UpdateRewardButton(clone, GetBattlepassRewardStatus(rank, false, false))
		-- Cada tier clona um template com viewport de skin (custoso). Cede o frame
		-- por tier para nunca estourar o watchdog ("exhausted execution time").
		task.wait()
	end

	for rank, data in pairs(BattlepassData.BattlepassData.Rewards.Premium) do
		local clone = PremiumRewardTemplate:Clone()
		clone.Parent = BattlepassPremiumScrollingFrame
		clone.LayoutOrder = rank
		clone.Name = rank
		clone.Visible = true
		clone:WaitForChild("Main"):WaitForChild("RankNumber").Text = rank
		HandleRewardsGroupWithData(clone:WaitForChild("Main"):WaitForChild("RewardsGroup"), data)
		UpdateRewardButton(clone, GetBattlepassRewardStatus(rank, true, false))
		task.wait()
	end
end

function module.ButtonAction(button, action)
	if action == "GetFirstFreeReward" then
		local status = GetBattlepassRewardStatus(nil, false, true)
		if status ~= "Claimable" then
			if status == "Locked" then
				ShowBattlepassLockedNotification(false)
			end

			return
		end

		ClaimEvent:FireServer("GetFirstFreeReward")
	end

	if action == "GetFirstPremiumReward" then
		local status = GetBattlepassRewardStatus(nil, true, true)
		if status ~= "Claimable" then
			if status == "Locked" then
				ShowBattlepassLockedNotification(true)
			end

			return
		end

		ClaimEvent:FireServer("GetFirstPremiumReward")
	end

	if action == "ClaimReward" then
		local rewardFrame = GetRewardFrameFromButton(button)
		if not rewardFrame then
			return
		end

		local rank = tonumber(rewardFrame.Name)
		local buttonIsPremium = rewardFrame:IsDescendantOf(BattlepassPremiumScrollingFrame)
		if not rank then
			return
		end

		local status = GetBattlepassRewardStatus(rank, buttonIsPremium, false)
		if status ~= "Claimable" then
			if status == "Locked" then
				ShowBattlepassLockedNotification(buttonIsPremium)
			end

			return
		end

		ClaimEvent:FireServer("ClaimReward", {Rank = rank, IsPremium = buttonIsPremium})
	end
end

function module.Init()
	-- Não constrói os tiers no boot: clonar os templates (cada um com viewport de
	-- skin) custava ~10s e travava o load de um painel que está escondido.
	-- Constrói na primeira vez que o Battlepass é aberto.
	local built = false
	local function buildOnce()
		if built then return end
		built = true
		CreateRewards()
	end

	BattlepassUI:GetPropertyChangedSignal("Visible"):Connect(function()
		if BattlepassUI.Visible then
			buildOnce()
		end
	end)
	if BattlepassUI.Visible then
		buildOnce()
	end

	PlayerState.OnChanged("HasBattlepassPremium", function()
		UpdateRewardButtons()
	end)

	PlayerState.OnChanged("Level", function()
		UpdateRewardButtons()
	end)

	PlayerState.OnChanged("ClaimedBattlepassRewards", function()
		UpdateRewardButtons()
	end)
end

return module
