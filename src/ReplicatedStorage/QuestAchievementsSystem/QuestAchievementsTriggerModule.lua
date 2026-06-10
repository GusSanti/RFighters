local module = {}
local TriggersEnums = require(game.ReplicatedStorage.QuestAchievementsSystem.TriggersEnum)
local QuestTriggerEvent = game.ReplicatedStorage.QuestAchievementsSystem.Events.SendTriggerQuests
local TagsTriggerEvent = game.ReplicatedStorage.QuestAchievementsSystem.Events.SendTriggerTags
local AchievementsTriggerEvent = game.ReplicatedStorage.QuestAchievementsSystem.Events.SendTriggerAchievements

function module.Trigger(player, TriggerEnum, TriggerArgs)
	if not player or not game.Players:FindFirstChild(player.Name) then warn('[QUESTS / ACHIEVEMENTS TRIGGER MODULE]: INVALID PLAYER') return end
	if not TriggerEnum or not TriggersEnums.EnumList[TriggerEnum] then warn('[QUESTS / ACHIEVEMENTS TRIGGER MODULE]: INVALID ENUM') return end
	
	print("[QUESTS / ACHIEVEMENTS TRIGGER MODULE]: TRIGGERING EVENTS")
	print("ARGS AND ENUM",TriggerEnum, TriggerArgs)
	QuestTriggerEvent:Fire(player, TriggerEnum, TriggerArgs)
	AchievementsTriggerEvent:Fire(player, TriggerEnum, TriggerArgs)
	TagsTriggerEvent:Fire(player, TriggerEnum, TriggerArgs)
end

return module
