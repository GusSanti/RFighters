local module = {}

local AchievementsList = require(script.Parent.AchievementsList)
local PlayerState = require(game.ReplicatedStorage.PlayerState.PlayerStateServer)
local ClaimAchievement = game.ReplicatedStorage.QuestAchievementsSystem.Events.ClaimAchievement

local SendTriggerAchievementsEvent = game.ReplicatedStorage.QuestAchievementsSystem.Events.SendTriggerAchievements

local ModelToNameTable = {
	Map_Cave = 'Cave',
	Map_Dojo = 'Dojo',
	Map_Palace = 'Palace',
	Map_Portal = 'Portal',
	Map_Skyruins = 'Skyruins',
	Map_Wasteland = 'Wasteland'
}

for _, player in game.Players:GetChildren() do
	local PlayerData = PlayerState.Get(player, 'Achievements')
	if not PlayerData then 
		warn('[ACHIEVEMENTS] NO DATA FOUND FOR PLAYER')
		PlayerState.Set(player, 'Achievements', AchievementsList.Achievements)
	end
end

game.Players.PlayerAdded:Connect(function(player)
	local PlayerData = PlayerState.Get(player, 'Achievements')
	if not PlayerData then 
		warn('[ACHIEVEMENTS] NO DATA FOUND FOR PLAYER')
		PlayerState.Set(player, 'Achievements', AchievementsList.Achievements)
	end
end)

for _, player in game.Players:GetChildren() do
	local PlayerData = PlayerState.Get(player, 'Achievements')
	if not PlayerData then 
		warn('[ACHIEVEMENTS] NO DATA FOUND FOR PLAYER')
		PlayerState.Set(player, 'Achievements', AchievementsList.Achievements)
	end
end

SendTriggerAchievementsEvent.Event:Connect(function(player, TriggerEnum, TriggerArgs)
	if not TriggerArgs['Map'] then warn('[ACHIEVEMENTS] MAP NOT FOUND IN TRIGGER ARGS') return end
	local map = ModelToNameTable[TriggerArgs['Map'].Name]

	local AchievementsInfo = AchievementsList.Achievements[map]
	if not AchievementsInfo then warn('[ACHIEVEMENTS] ACHIEVEMENTS INFO NOT FOUND FOR MAP', map) return end

	local PlayerAchievements = PlayerState.Get(player, 'Achievements')

	for index, achievementInfo in ipairs(PlayerAchievements[map]) do
		if table.find(achievementInfo.Triggers, TriggerEnum) then
			warn("[ACHIEVEMENTS] FOUND TRIGGER IN ACHIEVEMENT INFO")
			--achievementInfo.CurrentTriggers += 1
			PlayerAchievements[map][index].CurrentTriggers += 1
		end
	end

	print('[ACHIEVEMENTS] NEW ACHIEVEMENTS: ', PlayerAchievements)
	PlayerState.Set(player, 'Achievements', PlayerAchievements)
	warn('[PLAYER STATE ACHIVEMENTS UPDATE]', PlayerState.Get(player, 'Achievements'))
end)

ClaimAchievement.OnServerEvent:Connect(function(plr, taskKey, selectedMap)
	-- Validação básica dos argumentos
	if type(taskKey) ~= "string" then return end
	if type(selectedMap) ~= "string" then return end

	-- Valida o taskKey e extrai o índice (ClaimTask1 -> 1, etc.)
	local taskIndex = tonumber(taskKey:match("ClaimTask(%d+)"))
	if not taskIndex or taskIndex < 1 or taskIndex > 3 then
		warn("[ACHIEVEMENTS] taskKey inválido:", taskKey, "| Player:", plr.Name)
		return
	end

	-- Valida o mapa usando a ModelToNameTable
	local map = ModelToNameTable[selectedMap]
	if not map then
		warn("[ACHIEVEMENTS] Mapa inválido:", selectedMap, "| Player:", plr.Name)
		return
	end

	local PlayerAchievements = PlayerState.Get(plr, "Achievements")
	if not PlayerAchievements then
		warn("[ACHIEVEMENTS] Sem dados de achievements para:", plr.Name)
		return
	end

	local mapAchievements = PlayerAchievements[map]
	if not mapAchievements then
		warn("[ACHIEVEMENTS] Mapa não encontrado nos achievements do player:", map)
		return
	end

	local achievement = mapAchievements[taskIndex]
	if not achievement then
		warn("[ACHIEVEMENTS] Task não encontrada:", taskKey, "no mapa:", map)
		return
	end

	-- Valida se o progresso foi atingido
	if achievement.CurrentTriggers < achievement.RequiredTriggers then
		warn("[ACHIEVEMENTS] Task incompleta:", taskKey,
			"| Progresso:", achievement.CurrentTriggers, "/", achievement.RequiredTriggers,
			"| Player:", plr.Name)
		return
	end

	-- Valida se já foi reivindicada
	if achievement.Completed then
		warn("[ACHIEVEMENTS] Task já reivindicada:", taskKey, "| Player:", plr.Name)
		return
	end

	-- Aplica o reward
	local reward = achievement.Reward
	if reward and reward.Type == "PlayerStateIncrement" then
		local current = PlayerState.Get(plr, reward.StateKey)
		if type(current) == "number" then
			PlayerState.Set(plr, reward.StateKey, current + reward.IncrementValue)
			print("[ACHIEVEMENTS] Reward aplicado para", plr.Name,
				"| +" .. reward.IncrementValue, reward.StateKey)
		end
	end

	-- Marca como concluída
	PlayerAchievements[map][taskIndex].Completed = true
	PlayerState.Set(plr, "Achievements", PlayerAchievements)

	print("[ACHIEVEMENTS] Achievement reivindicado:", achievement.Label, "| Player:", plr.Name)
end)

return module
