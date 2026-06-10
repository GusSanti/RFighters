local module = {}

local TagsList = require(script.Parent.TagsList)
local ClaimTag = game.ReplicatedStorage.QuestAchievementsSystem.Events.ClaimTag
local SendTriggerTagsEvent = game.ReplicatedStorage.QuestAchievementsSystem.Events.SendTriggerTags
local PlayerState = require(game.ReplicatedStorage.PlayerState.PlayerStateServer)
local SelectTag = game.ReplicatedStorage.QuestAchievementsSystem.Events.SelectTag

-- ─── SelectTag ───────────────────────────────────────────────────────────────

SelectTag.OnServerEvent:Connect(function(player, action, tagIndex)
	if action == 'Select' then
		if type(tagIndex) ~= "number" then return end
		PlayerState.Set(player, 'EquippedTag', tagIndex)
		print('[TAGS] Tag equipada:', tagIndex, '| Player:', player.Name)

	elseif action == 'Deselect' then
		PlayerState.Set(player, 'EquippedTag', nil)
		print('[TAGS] Tag desequipada | Player:', player.Name)
	end
end)

-- ─── PlayerAdded ─────────────────────────────────────────────────────────────

game.Players.PlayerAdded:Connect(function(player)
	local TagsData = PlayerState.Get(player, 'Tags')
	if not TagsData then
		warn('[TAGS] NO DATA FOUND FOR PLAYER')
		PlayerState.Set(player, 'Tags', TagsList.Tags)
	end
end)

for _, player in game.Players:GetChildren() do
	local TagsData = PlayerState.Get(player, 'Tags')
	if not TagsData then
		warn('[TAGS] NO DATA FOUND FOR PLAYER')
		PlayerState.Set(player, 'Tags', TagsList.Tags)
	end
end

-- ─── SendTriggerTags ─────────────────────────────────────────────────────────

SendTriggerTagsEvent.Event:Connect(function(player, TriggerEnum)
	local PlayerTags = PlayerState.Get(player, 'Tags')
	if not PlayerTags then warn('[TAGS] NO TAGS DATA FOR PLAYER') return end

	for index, tagInfo in ipairs(PlayerTags) do
		if not tagInfo.Completed and table.find(tagInfo.Triggers, TriggerEnum) then
			PlayerTags[index].CurrentTriggers = math.min(
				PlayerTags[index].CurrentTriggers + 1,
				tagInfo.RequiredTriggers
			)
		end
	end

	PlayerState.Set(player, 'Tags', PlayerTags)
end)

-- ─── ClaimTag ────────────────────────────────────────────────────────────────

ClaimTag.OnServerEvent:Connect(function(player, tagIndex)
	if type(tagIndex) ~= "number" then return end

	local PlayerTags = PlayerState.Get(player, 'Tags')
	if not PlayerTags then
		warn('[TAGS] Sem dados de tags para:', player.Name)
		return
	end

	local tag = PlayerTags[tagIndex]
	if not tag then
		warn('[TAGS] Tag não encontrada, index:', tagIndex)
		return
	end

	if tag.CurrentTriggers < tag.RequiredTriggers then
		warn('[TAGS] Tag incompleta:', tag.Label, '| Player:', player.Name)
		return
	end

	if tag.Completed then
		warn('[TAGS] Tag já reivindicada:', tag.Label, '| Player:', player.Name)
		return
	end

	PlayerTags[tagIndex].Completed = true
	PlayerState.Set(player, 'Tags', PlayerTags)
	print('[TAGS] Tag reivindicada:', tag.Label, '| Player:', player.Name)
end)

-- ─── Helper: atualiza o BillboardGui no character do player ──────────────────
local function UpdateNametagLabel(player, tagLabel)
	local character = player.Character
	if not character then return end

	local playerInfo = character:FindFirstChild("PlayerInfo") -- nome da Part clonada
	if not playerInfo then return end

	local billboardGui = playerInfo:FindFirstChildWhichIsA("BillboardGui")
	if not billboardGui then return end

	local frame = billboardGui:FindFirstChildWhichIsA("Frame")
	if not frame then return end

	local tagTextLabel = frame:FindFirstChild("Tag") -- ajuste pro nome real
	if tagTextLabel then
		tagTextLabel.Text = "[" .. string.upper(tagLabel or "NEWCOMMER") .. "]"
	end
	-- Se tiver o Text2 (outline/shadow)
	local tag2 = tagTextLabel and tagTextLabel:FindFirstChild("Text2")
	if tag2 then
		tag2.Text = tagTextLabel.Text
	end
end

-- ─── SelectTag ───────────────────────────────────────────────────────────────
SelectTag.OnServerEvent:Connect(function(player, action, tagIndex)
	if action == 'Select' then
		if type(tagIndex) ~= "number" then return end
		PlayerState.Set(player, 'EquippedTag', tagIndex)

		-- Busca o label da tag pra exibir no nametag
		local PlayerTags = PlayerState.Get(player, 'Tags')
		local tagLabel = PlayerTags and PlayerTags[tagIndex] and PlayerTags[tagIndex].Label
		UpdateNametagLabel(player, tagLabel)

		print('[TAGS] Tag equipada:', tagIndex, '| Player:', player.Name)

	elseif action == 'Deselect' then
		PlayerState.Set(player, 'EquippedTag', nil)
		UpdateNametagLabel(player, nil) -- volta pra "NEWCOMMER"

		print('[TAGS] Tag desequipada | Player:', player.Name)
	end
end)

return module
