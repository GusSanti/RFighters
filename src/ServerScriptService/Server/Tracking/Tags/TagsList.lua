local module = {}
local TriggerEnums = require(game.ReplicatedStorage.QuestAchievementsSystem.TriggersEnum)

module.Tags = {
	[1] = {
		Label = 'Novice Slayer',
		Description = 'Kill 10 players in any mode',
		Triggers = {TriggerEnums.EnumList.CombatKillPlayer1v1, TriggerEnums.EnumList.CombatKillPlayer2v2},
		RequiredTriggers = 10,
		CurrentTriggers = 0,
		Completed = false,
	},
	[2] = {
		Label = 'Slayer',
		Description = 'Kill 50 players in any mode',
		Triggers = {TriggerEnums.EnumList.CombatKillPlayer1v1, TriggerEnums.EnumList.CombatKillPlayer2v2},
		RequiredTriggers = 50,
		CurrentTriggers = 0,
		Completed = false,
	},
	[3] = {
		Label = 'Elite Slayer',
		Description = 'Kill 150 players in any mode',
		Triggers = {TriggerEnums.EnumList.CombatKillPlayer1v1, TriggerEnums.EnumList.CombatKillPlayer2v2},
		RequiredTriggers = 150,
		CurrentTriggers = 0,
		Completed = false,
	},
	[4] = {
		Label = 'Rookie',
		Description = 'Win 5 matches in any mode',
		Triggers = {TriggerEnums.EnumList.MatchWinMatch1v1, TriggerEnums.EnumList.MatchWinMatch2v2},
		RequiredTriggers = 5,
		CurrentTriggers = 0,
		Completed = false,
	},
	[5] = {
		Label = 'Experienced',
		Description = 'Win 25 matches in any mode',
		Triggers = {TriggerEnums.EnumList.MatchWinMatch1v1, TriggerEnums.EnumList.MatchWinMatch2v2},
		RequiredTriggers = 25,
		CurrentTriggers = 0,
		Completed = false,
	},
	[6] = {
		Label = 'Veteran',
		Description = 'Win 75 matches in any mode',
		Triggers = {TriggerEnums.EnumList.MatchWinMatch1v1, TriggerEnums.EnumList.MatchWinMatch2v2},
		RequiredTriggers = 75,
		CurrentTriggers = 0,
		Completed = false,
	},
	[7] = {
		Label = 'Ult Apprentice',
		Description = 'Use your ultimate attack 20 times',
		Triggers = {TriggerEnums.EnumList.CombatUsedUlt},
		RequiredTriggers = 20,
		CurrentTriggers = 0,
		Completed = false,
	},
	[8] = {
		Label = 'Ult Master',
		Description = 'Use your ultimate attack 100 times',
		Triggers = {TriggerEnums.EnumList.CombatUsedUlt},
		RequiredTriggers = 100,
		CurrentTriggers = 0,
		Completed = false,
	},
	[9] = {
		Label = 'Round Grinder',
		Description = 'Win 30 rounds in any mode',
		Triggers = {TriggerEnums.EnumList.MatchWinRound1v1, TriggerEnums.EnumList.MatchWinRound2v2},
		RequiredTriggers = 30,
		CurrentTriggers = 0,
		Completed = false,
	},
	[10] = {
		Label = 'Round Champion',
		Description = 'Win 100 rounds in any mode',
		Triggers = {TriggerEnums.EnumList.MatchWinRound1v1, TriggerEnums.EnumList.MatchWinRound2v2},
		RequiredTriggers = 100,
		CurrentTriggers = 0,
		Completed = false,
	},
}

return module