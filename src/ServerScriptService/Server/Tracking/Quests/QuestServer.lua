local module = {}

local QuestTemplates = require(script.Parent.QuestTemplates)
local PlayerState = require(game.ReplicatedStorage.PlayerState.PlayerStateServer)
local ClaimQuest = game.ReplicatedStorage.QuestAchievementsSystem.Events.ClaimQuest

local SECONDS_PER_DAY = 86400
local REFRESH_CHECK_INTERVAL = 5

-- Expiração em dias por tipo
local EXPIRY_DAYS = {
	Daily   = 1,
	Weekly  = 7,
	Monthly = 30,
}

-- Retorna timestamp atual em dias (os.time() / 86400 arredondado)
local function GetDayStamp()	
	return math.floor(os.time() / SECONDS_PER_DAY)
end

local function GetNextRefreshTimestamp(dayStamp, expiryDays)
	return (dayStamp + expiryDays) * SECONDS_PER_DAY
end

local function CloneQuests(quests)
	if typeof(quests) ~= "table" then
		return nil
	end

	return PlayerState.Clone(quests, true)
end

local function GetQuestTemplate(questType, questIndex)
	local bucket = QuestTemplates.QuestTemplates[questType]
	if not bucket then
		return nil
	end

	return bucket[questIndex]
end

local function BuildTriggerList(triggerMap)
	local triggers = {}
	local seen = {}

	for _, trigger in pairs(triggerMap or {}) do
		if type(trigger) == "string" and not seen[trigger] then
			seen[trigger] = true
			table.insert(triggers, trigger)
		end
	end

	table.sort(triggers)

	return triggers
end

local function AreTriggersEqual(currentTriggers, expectedTriggers)
	if typeof(currentTriggers) ~= "table" then
		return false
	end

	if #currentTriggers ~= #expectedTriggers then
		return false
	end

	local current = table.clone(currentTriggers)
	table.sort(current)

	for index, trigger in ipairs(expectedTriggers) do
		if current[index] ~= trigger then
			return false
		end
	end

	return true
end

local function ExtractQuestTemplateValues(templateData, quest)
	local tmpl = templateData.Template
	local label = type(quest.Label) == "string" and quest.Label or templateData.Label

	local requiredTriggers = tonumber(quest.RequiredTriggers)
	if not requiredTriggers or requiredTriggers <= 0 then
		requiredTriggers = tonumber(label:match("(%d+)"))
	end

	local mode = type(quest.Mode) == "string" and quest.Mode or nil

	if tmpl.YOptions then
		if not mode or not tmpl.TriggerMap[mode] then
			for _, option in ipairs(tmpl.YOptions) do
				if label:find(option, 1, true) then
					mode = option
					break
				end
			end
		end

		if (not mode or not tmpl.TriggerMap[mode]) and typeof(quest.Triggers) == "table" then
			for option, trigger in pairs(tmpl.TriggerMap) do
				if table.find(quest.Triggers, trigger) then
					mode = option
					break
				end
			end
		end
	else
		mode = "any"
	end

	return requiredTriggers, mode, label
end

local function RepairQuestFromTemplate(questType, questIndex, quest)
	local templateData = GetQuestTemplate(questType, questIndex)
	if not templateData or typeof(quest) ~= "table" then
		return false
	end

	local tmpl = templateData.Template
	local changed = false
	local requiredTriggers, mode, label = ExtractQuestTemplateValues(templateData, quest)
	local expectedTriggers

	if tmpl.YOptions then
		if mode and tmpl.TriggerMap[mode] then
			expectedTriggers = { tmpl.TriggerMap[mode] }
		else
			expectedTriggers = BuildTriggerList(tmpl.TriggerMap)
		end
	else
		expectedTriggers = { tmpl.TriggerMap["any"] }
	end

	if requiredTriggers and requiredTriggers > 0 and quest.RequiredTriggers ~= requiredTriggers then
		quest.RequiredTriggers = requiredTriggers
		changed = true
	end

	if quest.Mode ~= mode then
		quest.Mode = mode
		changed = true
	end

	if quest.TemplateIndex ~= questIndex then
		quest.TemplateIndex = questIndex
		changed = true
	end

	if quest.QuestType ~= questType then
		quest.QuestType = questType
		changed = true
	end

	if quest.TemplateAction ~= tmpl.Action then
		quest.TemplateAction = tmpl.Action
		changed = true
	end

	if expectedTriggers and not AreTriggersEqual(quest.Triggers, expectedTriggers) then
		quest.Triggers = expectedTriggers
		changed = true
	end

	local expectedLabel = nil
	if requiredTriggers and requiredTriggers > 0 then
		expectedLabel = templateData.Label:gsub("{X}", tostring(requiredTriggers))
		if tmpl.YOptions and mode then
			expectedLabel = expectedLabel:gsub("{Y}", mode)
		end
	end

	if type(quest.Label) ~= "string"
		or quest.Label == ""
		or quest.Label:find("{X}", 1, true)
		or quest.Label:find("{Y}", 1, true)
	then
		quest.Label = expectedLabel or label
		changed = true
	end

	local expectedIncrement = nil
	if requiredTriggers and requiredTriggers > 0 then
		expectedIncrement = requiredTriggers * tmpl.RewardPerUnit
	end

	if typeof(quest.Reward) ~= "table" then
		quest.Reward = {}
		changed = true
	end

	if quest.Reward.Type ~= templateData.Reward.Type then
		quest.Reward.Type = templateData.Reward.Type
		changed = true
	end

	if quest.Reward.StateKey ~= tmpl.RewardKey then
		quest.Reward.StateKey = tmpl.RewardKey
		changed = true
	end

	if expectedIncrement and quest.Reward.IncrementValue ~= expectedIncrement then
		quest.Reward.IncrementValue = expectedIncrement
		changed = true
	end

	return changed
end

local function NormalizeQuestState(quest)
	local changed = false

	local progress = tonumber(quest.Progress) or 0
	if progress < 0 then
		progress = 0
	end
	if quest.Progress ~= progress then
		quest.Progress = progress
		changed = true
	end

	local requiredTriggers = tonumber(quest.RequiredTriggers) or 0
	if requiredTriggers < 0 then
		requiredTriggers = 0
	end
	if quest.RequiredTriggers ~= requiredTriggers then
		quest.RequiredTriggers = requiredTriggers
		changed = true
	end

	local claimed = quest.Claimed == true
	if quest.Claimed ~= claimed then
		quest.Claimed = claimed
		changed = true
	end

	local completed = quest.Completed == true or claimed or (requiredTriggers > 0 and progress >= requiredTriggers)
	if quest.Completed ~= completed then
		quest.Completed = completed
		changed = true
	end

	return changed
end

local function NormalizeQuestBuckets(quests)
	if typeof(quests) ~= "table" then
		return false
	end

	local changed = false

	for questType, bucket in pairs(quests) do
		if bucket and bucket.Quests then
			for questIndex, quest in ipairs(bucket.Quests) do
				if RepairQuestFromTemplate(questType, questIndex, quest) then
					changed = true
				end

				if NormalizeQuestState(quest) then
					changed = true
				end
			end
		end
	end

	return changed
end

local function NormalizeQuestBucketMetadata(questType, bucket)
	if typeof(bucket) ~= "table" then
		return false
	end

	local expiryDays = EXPIRY_DAYS[questType]
	if not expiryDays then
		return false
	end

	local changed = false

	if bucket.QuestType ~= questType then
		bucket.QuestType = questType
		changed = true
	end

	local dayStamp = tonumber(bucket.DayStamp)
	if not dayStamp then
		local nextRefreshAt = tonumber(bucket.NextRefreshAt)
		if nextRefreshAt then
			dayStamp = math.max(math.floor(nextRefreshAt / SECONDS_PER_DAY) - expiryDays, 0)
		else
			dayStamp = GetDayStamp()
		end

		bucket.DayStamp = dayStamp
		changed = true
	end

	local expectedNextRefreshAt = GetNextRefreshTimestamp(dayStamp, expiryDays)
	if bucket.NextRefreshAt ~= expectedNextRefreshAt then
		bucket.NextRefreshAt = expectedNextRefreshAt
		changed = true
	end

	return changed
end

local function FindQuestByIdentifier(quests, questTypeOrLabel, questIndex)
	if type(questTypeOrLabel) == "string" and type(questIndex) == "number" then
		local bucket = quests[questTypeOrLabel]
		local quest = bucket and bucket.Quests and bucket.Quests[questIndex]
		if quest then
			return questTypeOrLabel, questIndex, quest
		end
	end

	if type(questTypeOrLabel) ~= "string" then
		return nil
	end

	for questType, bucket in pairs(quests) do
		if bucket and bucket.Quests then
			for index, quest in ipairs(bucket.Quests) do
				if quest.Label == questTypeOrLabel then
					return questType, index, quest
				end
			end
		end
	end

	return nil
end

-- Gera uma quest de um template (preenche X, Y, Triggers, Reward)
local function BuildQuestFromTemplate(templateData, questType, questIndex)
	-- Deep copy para não mutar o template original
	local quest = {
		Label = templateData.Label,
		Triggers = {},
		RequiredTriggers = 0,
		Reward = {
			Type = templateData.Reward.Type,
			StateKey = templateData.Reward.StateKey,
			IncrementValue = 0,
		},
		Progress = 0,
		Completed = false,
		Claimed = false,
		TemplateIndex = questIndex,
		QuestType = questType,
	}

	local tmpl = templateData.Template

	-- Escolhe X aleatório dentro do range
	local X = math.random(tmpl.XRange.min, tmpl.XRange.max)

	-- Escolhe Y (modo) aleatório, se existir
	local Y = nil
	if tmpl.YOptions then
		Y = tmpl.YOptions[math.random(1, #tmpl.YOptions)]
		quest.Triggers = { tmpl.TriggerMap[Y] }
	else
		quest.Triggers = { tmpl.TriggerMap["any"] }
	end

	quest.Mode = Y or "any"
	quest.TemplateAction = tmpl.Action

	quest.RequiredTriggers = X
	quest.Reward.IncrementValue = X * tmpl.RewardPerUnit

	-- Substitui {X} e {Y} no label
	quest.Label = quest.Label:gsub("{X}", tostring(X))
	if Y then
		quest.Label = quest.Label:gsub("{Y}", Y)
	end

	return quest
end

-- Gera todas as quests de um tipo (Daily/Weekly/Monthly)
local function GenerateQuestsByType(questType)
	local templates = QuestTemplates.QuestTemplates[questType]
	local generated = {}
	local dayStamp = GetDayStamp()

	for i, templateData in ipairs(templates) do
		generated[i] = BuildQuestFromTemplate(templateData, questType, i)
	end

	return {
		Quests    = generated,
		DayStamp  = dayStamp, -- dia em que foram geradas
		NextRefreshAt = GetNextRefreshTimestamp(dayStamp, EXPIRY_DAYS[questType]),
		QuestType = questType,
	}
end

-- Verifica e renova cada tipo de quest conforme a expiração
local function RefreshQuests(plr)
	local currentQuests = PlayerState.Get(plr, "Quests")
	if not currentQuests then
		return
	end

	local Quests = CloneQuests(currentQuests)
	local changed = false

	if NormalizeQuestBuckets(Quests) then
		changed = true
	end

	for questType, expiryDays in pairs(EXPIRY_DAYS) do
		local bucket = Quests[questType]

		-- Sem bucket: gera do zero
		if not bucket then
			Quests[questType] = GenerateQuestsByType(questType)
			changed = true
			continue
		end

		-- Checa se passaram dias suficientes desde a geração
		if NormalizeQuestBucketMetadata(questType, bucket) then
			changed = true
		end

		local nextRefreshAt = tonumber(bucket.NextRefreshAt) or GetNextRefreshTimestamp(bucket.DayStamp or GetDayStamp(), expiryDays)
		if os.time() >= nextRefreshAt then
			Quests[questType] = GenerateQuestsByType(questType)
			changed = true
		end
	end

	if changed then
		PlayerState.Set(plr, "Quests", Quests)
	end
end

local function EnsureFreshQuests(plr)
	RefreshQuests(plr)
	return PlayerState.Get(plr, "Quests")
end

-- Gera quests completas para player novo
local function GenerateAllQuests()
	local quests = {}
	for questType in pairs(EXPIRY_DAYS) do
		quests[questType] = GenerateQuestsByType(questType)
	end
	return quests
end

-- ─── PlayerAdded ────────────────────────────────────────────────────────────
warn("QUESTS RUNNING")

game.Players.PlayerAdded:Connect(function(plr)
	local Quests = PlayerState.Get(plr, "Quests")

	if not Quests or next(Quests) == nil then
		-- Player novo: gera tudo do zero
		PlayerState.Set(plr, "Quests", GenerateAllQuests())
	else
		-- Player existente: verifica expiração de cada tipo
		RefreshQuests(plr)
	end
end)

for _, plr in pairs(game.Players:GetPlayers()) do
	local Quests = PlayerState.Get(plr, "Quests")

	if not Quests or next(Quests) == nil then
		-- Player novo: gera tudo do zero
		PlayerState.Set(plr, "Quests", GenerateAllQuests())
	else
		-- Player existente: verifica expiração de cada tipo
		RefreshQuests(plr)
	end
end

-- ─── Quest Trigger Handler ───────────────────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(REFRESH_CHECK_INTERVAL)

		for _, plr in ipairs(game.Players:GetPlayers()) do
			RefreshQuests(plr)
		end
	end
end)

local SendTriggerQuestsEvent = game.ReplicatedStorage.QuestAchievementsSystem.Events.SendTriggerQuests

SendTriggerQuestsEvent.Event:Connect(function(player, TriggerEnum, TriggerArgs)
	local currentQuests = EnsureFreshQuests(player)
	if not currentQuests then warn('[QUESTS] SEM DADOS DE QUESTS PARA PLAYER') return end

	local Quests = CloneQuests(currentQuests)
	local changed = NormalizeQuestBuckets(Quests)

	for questType, bucket in pairs(Quests) do
		if not bucket or not bucket.Quests then continue end

		for i, quest in ipairs(bucket.Quests) do
			if quest.Completed then continue end
			if table.find(quest.Triggers, TriggerEnum) then
				Quests[questType].Quests[i].Progress += 1
				if Quests[questType].Quests[i].Progress >= quest.RequiredTriggers then
					Quests[questType].Quests[i].Completed = true
					print("[QUESTS] Quest completada:", quest.Label, "| Player:", player.Name)
				end
				changed = true
			end
		end
	end

	if changed then
		PlayerState.Set(player, "Quests", Quests)
		print("[QUESTS] Estado atualizado para", player.Name)
	end
end)

-- ─── ClaimQuest Handler ─────────────────────────────────────────────────────
ClaimQuest.OnServerEvent:Connect(function(plr, questTypeOrLabel, questIndex)
	if type(questTypeOrLabel) ~= "string" then return end

	local currentQuests = EnsureFreshQuests(plr)
	if not currentQuests then return end

	local Quests = CloneQuests(currentQuests)
	local changed = NormalizeQuestBuckets(Quests)

	local questType, questPosition, quest = FindQuestByIdentifier(Quests, questTypeOrLabel, questIndex)
	if not questType or not questPosition or not quest then
		if changed then
			PlayerState.Set(plr, "Quests", Quests)
		end

		warn(plr.Name .. " tentou reivindicar quest inexistente: " .. tostring(questTypeOrLabel))
		return
	end

	if not quest.Completed then
		if changed then
			PlayerState.Set(plr, "Quests", Quests)
		end

		warn(plr.Name .. " tentou reivindicar quest incompleta: " .. quest.Label)
		return
	end

	if quest.Claimed then
		if changed then
			PlayerState.Set(plr, "Quests", Quests)
		end

		warn(plr.Name .. " tentou reivindicar quest já reivindicada: " .. quest.Label)
		return
	end

	local reward = quest.Reward
	if reward.Type == "PlayerStateIncrement" then
		local current = PlayerState.Get(plr, reward.StateKey)
		if type(current) == "number" then
			PlayerState.Increment(plr, reward.StateKey, reward.IncrementValue)
		end
	end

	Quests[questType].Quests[questPosition].Claimed = true
	Quests[questType].Quests[questPosition].Completed = true
	PlayerState.Set(plr, "Quests", Quests)

	print(plr.Name .. " reivindicou quest '" .. quest.Label .. "' | Reward: +" .. tostring(reward.IncrementValue) .. " " .. tostring(reward.StateKey))
end)

return module
