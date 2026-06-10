local Achievements = {}
local localPlayer = game.Players.LocalPlayer

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local PlayerState = require(game.ReplicatedStorage.PlayerState.PlayerStateClient)
local playerGui = localPlayer:WaitForChild("PlayerGui")
local MainUI = playerGui:WaitForChild("UI")
local AchievementsUI = MainUI:WaitForChild("Quests")
local ScrollingFrame = AchievementsUI.MAIN.ScrollingFrame
local QuestTemplate = ScrollingFrame.QuestTemplate
local DailyButton = AchievementsUI.MAIN.Daily
local WeeklyButton = AchievementsUI.MAIN.Weekly
local MonthlyButton = AchievementsUI.MAIN.Monthly
local ClaimQuestRemote = game.ReplicatedStorage.QuestAchievementsSystem.Events.ClaimQuest

local ASSET_GRAY_BUTTON = "rbxassetid://114921624481011"
local ASSET_BLUE_BUTTON = "rbxassetid://126735802810977"
local ASSET_CLAIM_NORMAL = "rbxassetid://71512746197648"
local ASSET_CLAIM_GRAY = "rbxassetid://114921624481011"
local ASSET_CRYSTALS = "rbxassetid://124856269825747"
local ASSET_DIAMONDS = "rbxassetid://91460785817697"

local currentTab = nil
local questsChangedConnection = nil

local TAB_BUTTONS = {
	DailyButton = DailyButton,
	WeeklyButton = WeeklyButton,
	MonthlyButton = MonthlyButton,
}

local TAB_TYPES = {
	DailyButton = "Daily",
	WeeklyButton = "Weekly",
	MonthlyButton = "Monthly",
}

local function SetTabVisual(button, selected)
	local textLabel = button:FindFirstChild("TextLabel")
	if textLabel then
		local selectedGradient = textLabel:FindFirstChild("Selected")
		local unselectedGradient = textLabel:FindFirstChild("Unselected")

		if selectedGradient then
			selectedGradient.Enabled = selected
		end

		if unselectedGradient then
			unselectedGradient.Enabled = not selected
		end
	end

	button.Image = selected and ASSET_BLUE_BUTTON or ASSET_GRAY_BUTTON
end

local function ClearQuestCards()
	for _, child in ipairs(ScrollingFrame:GetChildren()) do
		if child:IsA("ImageLabel") and child ~= QuestTemplate then
			child:Destroy()
		end
	end
end

local function UpdateProgressBar(card, ratio)
	ratio = math.clamp(ratio, 0, 1)

	local barBG = card:FindFirstChild("BarBG")
	if not barBG then
		return
	end

	local bar = barBG:FindFirstChild("Bar")
	if not bar then
		return
	end

	local gradient = bar:FindFirstChildOfClass("UIGradient")
	if gradient then
		local offsetX = -1 + ratio
		gradient.Offset = Vector2.new(offsetX, gradient.Offset.Y)
	end
end

local function UpdateCompletionPercentage(card, ratio)
	ratio = math.clamp(ratio, 0, 1)

	local barBG = card:FindFirstChild("BarBG")
	if not barBG then
		return
	end

	local label = barBG:FindFirstChild("CompletionPercentage")
	if label then
		label.Text = math.floor(ratio * 100) .. "%"
	end
end

local function IsQuestCompleted(questData)
	local progress = tonumber(questData.Progress) or 0
	local required = tonumber(questData.RequiredTriggers) or 0

	if questData.Completed == true then
		return true
	end

	return required > 0 and progress >= required
end

local function CanClaimQuest(questData)
	local completed = IsQuestCompleted(questData)
	local claimed = questData.Claimed == true
	return completed and not claimed
end

local function GetQuestByLocation(quests, questType, questIndex)
	local bucket = quests[questType]
	if not bucket or not bucket.Quests then
		return nil
	end

	return bucket.Quests[questIndex]
end

local function PopulateQuests(questType)
	local Quests = PlayerState.Get("Quests")

	local t = 0
	while not Quests and t < 5 do
		task.wait(0.1)
		t += 0.1
		Quests = PlayerState.Get("Quests")
	end

	if not Quests then
		warn("Quests not found")
		return
	end

	local bucket = Quests[questType]
	if not bucket or not bucket.Quests then
		return
	end

	for questIndex, questData in ipairs(bucket.Quests) do
		local card = QuestTemplate:Clone()
		card.Name = "QuestCard_" .. questData.Label
		card.Visible = true
		card:SetAttribute("QuestType", questType)
		card:SetAttribute("QuestIndex", questIndex)

		local questName = card:FindFirstChild("QuestName")
		if questName then
			questName.Text = questData.Label
		end

		local rewardImage = card:FindFirstChild("RewardImage")
		local rewardQty = card:FindFirstChild("RewardQuantity")

		if rewardImage and questData.Reward then
			local key = questData.Reward.StateKey
			rewardImage.Image = (key == "Crystals") and ASSET_CRYSTALS or ASSET_DIAMONDS
		end

		if rewardQty and questData.Reward then
			rewardQty.Text = tostring(questData.Reward.IncrementValue) .. "x"
		end

		local progress = questData.Progress or 0
		local required = questData.RequiredTriggers or 0
		local completed = IsQuestCompleted(questData)

		local ratio = 0
		if required > 0 then
			ratio = math.min(progress / required, 1)
		elseif completed then
			ratio = 1
		end

		UpdateProgressBar(card, ratio)
		UpdateCompletionPercentage(card, ratio)

		local claimButton = card:FindFirstChild("ClaimButton")
		if claimButton and claimButton:IsA("GuiButton") then
			local canClaim = CanClaimQuest(questData)
			claimButton.Image = canClaim and ASSET_CLAIM_NORMAL or ASSET_CLAIM_GRAY
			claimButton.Active = canClaim
			claimButton.AutoButtonColor = canClaim

			claimButton.MouseButton1Click:Connect(function()
				Achievements.ButtonAction(claimButton, "ClaimQuest")
			end)
		end

		card.Parent = ScrollingFrame
	end
end

local function RefreshCurrentTab()
	if not currentTab then
		return
	end

	ClearQuestCards()
	PopulateQuests(TAB_TYPES[currentTab])
end

local function SwitchTab(action)
	currentTab = action

	for btnName, btn in pairs(TAB_BUTTONS) do
		SetTabVisual(btn, btnName == action)
	end

	RefreshCurrentTab()
end

local function BindQuestsChangedListener()
	if questsChangedConnection then
		questsChangedConnection:Disconnect()
		questsChangedConnection = nil
	end

	task.spawn(function()
		local timeout = 0
		while not PlayerState.IsReady() and timeout < 10 do
			task.wait(0.1)
			timeout += 0.1
		end

		if not PlayerState.IsReady() then
			return
		end

		if questsChangedConnection then
			return
		end

		questsChangedConnection = PlayerState.OnChanged("Quests", function()
			task.defer(RefreshCurrentTab)
		end)
	end)
end

function Achievements.Init()
	QuestTemplate.Visible = false

	BindQuestsChangedListener()

	for btnName, btn in pairs(TAB_BUTTONS) do
		btn.MouseButton1Click:Connect(function()
			Achievements.ButtonAction(btn, btnName)
		end)
	end

	SwitchTab("DailyButton")
end

function Achievements.ButtonAction(button: GuiButton, action: string)
	if action == "DailyButton" or action == "WeeklyButton" or action == "MonthlyButton" then
		SwitchTab(action)
		return
	end

	if action ~= "ClaimQuest" then
		return
	end

	local Quests = PlayerState.Get("Quests")
	if not Quests then
		return
	end

	local card = button.Parent
	if not card then
		return
	end

	local questType = card:GetAttribute("QuestType")
	local questIndex = card:GetAttribute("QuestIndex")
	if type(questType) ~= "string" or type(questIndex) ~= "number" then
		return
	end

	local questData = GetQuestByLocation(Quests, questType, questIndex)
	if not questData then
		return
	end

	if not CanClaimQuest(questData) then
		return
	end

	ClaimQuestRemote:FireServer(questType, questIndex)

	button.Image = ASSET_CLAIM_GRAY
	button.Active = false
	button.AutoButtonColor = false

	task.delay(0.25, function()
		RefreshCurrentTab()
	end)
end

return Achievements
