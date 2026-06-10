local IndexCharacters = {}
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
--Gui
local UI = playerGui:WaitForChild("UI")
local CharacterIndexFrame = UI:WaitForChild("CharacterIndex")
local MAIN = CharacterIndexFrame:WaitForChild("MAIN")
local UnlockedCharacters = MAIN:WaitForChild("UnlockedCharacters")
local ScrollingFrame = MAIN:WaitForChild("ScrollingFrame")
local CharacterDescription = MAIN:WaitForChild("CharacterDescription")
local CharacterImageMain = MAIN:WaitForChild("CharacterImageMain")
local CharacterName = CharacterImageMain:WaitForChild("CharacterName")
local Skill1 = MAIN:WaitForChild("Skill1")
local Skill2 = MAIN:WaitForChild("Skill2")
local Ultimate = MAIN:WaitForChild("Ultimate")

local BlueReward = MAIN:WaitForChild("Rewards"):WaitForChild("BlueReward")
local GreenReward = MAIN:WaitForChild("Rewards"):WaitForChild("GreenReward")
local RedReward = MAIN:WaitForChild("Rewards"):WaitForChild("RedReward")

-- events
local GetData = game.ReplicatedStorage.Events.RequestCharacterIndexData
local ClaimRewards = game.ReplicatedStorage.Events.ClaimIndexCharactersRewards

local PlayerState = require(game.ReplicatedStorage.PlayerState.PlayerStateClient)
local RewardData = require(script.IndexCharactersRewardsData)

local selectedCharacter = nil
local TotalCharacters = 6

local function BlockSlotIndex(slot: GuiButton)
	if slot:FindFirstChild("Locked") then
		slot.Locked.Visible = true
	end
	slot.Interactable = false
end

local function EnableSlotIndex(slot: GuiButton)
	if slot:FindFirstChild("Locked") then
		slot.Locked.Visible = false
	end
	slot.Interactable = true
end

local function UpdateSlots()
	print('update slots')
	local data = GetData:InvokeServer('GetIndexCharacters')
	if not data then return end
	local unlockedNames = {}
	for _, charData in ipairs(data) do
		if charData and charData.CharacterName then
			unlockedNames[charData.CharacterName] = true
		end
	end

	local unlockedCount = 0

	for _, button in ipairs(ScrollingFrame:GetDescendants()) do
		if button:IsA("TextButton") or button:IsA("ImageButton") then
			if unlockedNames[button.Name] then
				EnableSlotIndex(button)
				unlockedCount += 1
			else
				BlockSlotIndex(button)
			end
		end
	end

	UnlockedCharacters.Text = unlockedCount .. "/" .. TotalCharacters

	return unlockedNames
end

local function UpdateCollected(charName)
	local status = GetData:InvokeServer("GetRewardStatus", charName)
	local isClaimed = (status == "Claimed")

	BlueReward:WaitForChild("Collected").Visible  = isClaimed
	GreenReward:WaitForChild("Collected").Visible = isClaimed
	RedReward:WaitForChild("Collected").Visible   = isClaimed
end

function IndexCharacters.ButtonAction(button: GuiButton, action)
	if action == "SelectCharacter" then
		local data = GetData:InvokeServer('GetIndexCharacters')
		for _, charData in ipairs(data) do
			if charData and charData.CharacterName == button.Name then
				selectedCharacter = charData.CharacterName

				CharacterName.Text = charData.CharacterName
				CharacterDescription.Text = charData.CharacterDescription

				for _, skill in charData.Skills do
					if skill.name == "Skill1" then
						Skill1.SkillName1.Text = skill.name
						Skill1.Description.Text = skill.description
					elseif skill.name == "Skill2" then
						Skill2.SkillName2.Text = skill.name
						Skill2.Description.Text = skill.description
					elseif skill.name == 'Ultimate' then
						Ultimate.SkillName3.Text = skill.name
						Ultimate.Description.Text = skill.description
					end
				end

				local rewardData = RewardData.Rewards[charData.CharacterName]

				for _, rewardImg in BlueReward:WaitForChild("RewardsGroup"):GetChildren() do
					if rewardImg:IsA("ImageLabel") then
						rewardImg.Visible = false
					end
				end

				for _, rewardImg in GreenReward:WaitForChild("RewardsGroup"):GetChildren() do
					if rewardImg:IsA("ImageLabel") then
						rewardImg.Visible = false
					end
				end

				for _, rewardImg in RedReward:WaitForChild("RewardsGroup"):GetChildren() do
					if rewardImg:IsA("ImageLabel") then
						rewardImg.Visible = false
					end
				end

				if rewardData then
					BlueReward:WaitForChild("RewardsGroup"):WaitForChild(rewardData[1].Type).Visible = true
					BlueReward:WaitForChild("RewardsGroup"):WaitForChild(rewardData[1].Type):WaitForChild("Amount").Text = rewardData[1].Amount .. "x"

					GreenReward:WaitForChild("RewardsGroup"):WaitForChild(rewardData[2].Type).Visible = true
					GreenReward:WaitForChild("RewardsGroup"):WaitForChild(rewardData[2].Type):WaitForChild("Amount").Text = rewardData[2].Amount .. "x"

					RedReward:WaitForChild("RewardsGroup"):WaitForChild(rewardData[3].Type).Visible = true
					RedReward:WaitForChild("RewardsGroup"):WaitForChild(rewardData[3].Type):WaitForChild("Amount").Text = rewardData[3].Amount .. "x"

					-- ✅ Atualiza visibilidade do Collected
					UpdateCollected(charData.CharacterName)
				else
					-- Personagem sem reward — esconde Collected
					BlueReward:WaitForChild("Collected").Visible  = false
					GreenReward:WaitForChild("Collected").Visible = false
					RedReward:WaitForChild("Collected").Visible   = false
				end

				for _, image in pairs(CharacterImageMain:GetDescendants()) do
					if image:IsA("ViewportFrame") then
						image.Visible = false
					end
				end

				local CharacterIndexImage = CharacterImageMain:FindFirstChild("Characters"):FindFirstChild(charData.CharacterName)
				
				CharacterImageMain.Image = button.Image
				
				if CharacterIndexImage then
					CharacterIndexImage.Visible = true
				end

				break
			end
		end
	end

	if action == "ClaimReward" then
		if not selectedCharacter then return end

		-- InvokeServer garante que o claim processou antes de atualizar o visual
		local success = GetData:InvokeServer("ClaimIndexReward", selectedCharacter)
		if success then
			UpdateCollected(selectedCharacter)
		end
	end
end

local function SelectFirstAvailable()
	if selectedCharacter then return end

	local data = GetData:InvokeServer('GetIndexCharacters')
	if not data or #data == 0 then return end

	local firstChar = data[1]
	if not firstChar or not firstChar.CharacterName then return end

	local button = ScrollingFrame:FindFirstChild(firstChar.CharacterName, true)
	if button and (button:IsA("TextButton") or button:IsA("ImageButton")) then
		IndexCharacters.ButtonAction(button, "SelectCharacter")
	end
end

CharacterIndexFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if CharacterIndexFrame.Visible then
		selectedCharacter = nil -- ✅ reseta seleção ao reabrir para forçar re-render
		SelectFirstAvailable()
	end
end)

PlayerState.OnChanged('CharacterIndex', function()
	UpdateSlots()
end)

function IndexCharacters.Init()
	UpdateSlots()
end

return IndexCharacters