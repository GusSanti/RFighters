local module = {}

local QuestTemplates = require(script.Parent.QuestTemplates)
local EnumTriggers = require(game.ReplicatedStorage.QuestAchievementsSystem.TriggersEnum)
local PlayerState = require(game.ReplicatedStorage.PlayerState.PlayerStateServer)
local ClaimQuest = game.ReplicatedStorage.QuestAchievementsSystem.Events.ClaimQuest

-- Expiração em dias por tipo
local EXPIRY_DAYS = {
	Daily   = 1,
	Weekly  = 7,
	Monthly = 30,
}

-- Retorna timestamp atual em dias (os.time() / 86400 arredondado)
local function GetDayStamp()	
	return math.floor(os.time() / 86400)
end

-- Gera uma quest de um template (preenche X, Y, Triggers, Reward)
local function BuildQuestFromTemplate(templateData)
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

	for i, templateData in ipairs(templates) do
		generated[i] = BuildQuestFromTemplate(templateData)
	end

	return {
		Quests    = generated,
		DayStamp  = GetDayStamp(), -- dia em que foram geradas
		QuestType = questType,
	}
end

-- Verifica e renova cada tipo de quest conforme a expiração
local function RefreshQuests(plr)
	local Quests = PlayerState.Get(plr, "Quests")
	local changed = false

	for questType, expiryDays in pairs(EXPIRY_DAYS) do
		local bucket = Quests[questType]

		-- Sem bucket: gera do zero
		if not bucket then
			Quests[questType] = GenerateQuestsByType(questType)
			changed = true
			continue
		end

		-- Checa se passaram dias suficientes desde a geração
		local daysPassed = GetDayStamp() - (bucket.DayStamp or 0)
		if daysPassed >= expiryDays then
			Quests[questType] = GenerateQuestsByType(questType)
			changed = true
		end
	end

	if changed then
		PlayerState.Set(plr, "Quests", Quests)
	end
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
local SendTriggerQuestsEvent = game.ReplicatedStorage.QuestAchievementsSystem.Events.SendTriggerQuests

SendTriggerQuestsEvent.Event:Connect(function(player, TriggerEnum, TriggerArgs)
	local Quests = PlayerState.Get(player, "Quests")
	if not Quests then warn('[QUESTS] SEM DADOS DE QUESTS PARA PLAYER') return end

	local changed = false

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
ClaimQuest.OnServerEvent:Connect(function(plr, questLabel)
	if type(questLabel) ~= "string" then return end

	local Quests = PlayerState.Get(plr, "Quests")
	if not Quests then return end

	-- Procura a quest em todos os buckets (Daily/Weekly/Monthly)
	for questType, bucket in pairs(Quests) do
		if not bucket or not bucket.Quests then continue end

		for i, quest in ipairs(bucket.Quests) do
			if quest.Label == questLabel then
				-- Valida se está completa e ainda não foi reivindicada
				if not quest.Completed then
					warn(plr.Name .. " tentou reivindicar quest incompleta: " .. questLabel)
					return
				end

				if quest.Claimed then
					warn(plr.Name .. " tentou reivindicar quest já reivindicada: " .. questLabel)
					return
				end

				-- Aplica o reward
				local reward = quest.Reward
				if reward.Type == "PlayerStateIncrement" then
					local current = PlayerState.Get(plr, reward.StateKey)
					if type(current) == "number" then
						PlayerState.Increment(plr, reward.StateKey, reward.IncrementValue)
					end
				end

				-- Marca como reivindicada
				Quests[questType].Quests[i].Claimed = true
				Quests[questType].Quests[i].Completed = true
				PlayerState.Set(plr, "Quests", Quests)

				print(plr.Name .. " reivindicou quest '" .. questLabel .. "' | Reward: +" .. tostring(reward.IncrementValue) .. " " .. tostring(reward.StateKey))
				return
			end
		end
	end

	warn(plr.Name .. " tentou reivindicar quest inexistente: " .. questLabel)
end)

return module
