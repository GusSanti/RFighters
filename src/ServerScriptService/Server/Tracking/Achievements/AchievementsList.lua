local module = {}
local TriggerEnums = require(game.ReplicatedStorage.QuestAchievementsSystem.TriggersEnum)
module.Achievements = {
	Cave = {
		[1] = {
			Label = 'Kill 25 Players In 1v1 Mode',
			Triggers = {TriggerEnums.EnumList.CombatKillPlayer1v1},
			RequiredTriggers = 25,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Crystals', IncrementValue = 150},
			CurrentTriggers = 0,
			Completed = false,
		},
		[2] = {
			Label = 'Win 15 Matches In 2v2 Mode',
			Triggers = {TriggerEnums.EnumList.MatchWinMatch2v2},
			RequiredTriggers = 15,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Diamonds', IncrementValue = 100},
			CurrentTriggers = 0,
			Completed = false,	
		},
		[3] = {
			Label = 'Win 40 Rounds In 1v1 Mode',
			Triggers = {TriggerEnums.EnumList.MatchWinRound1v1},
			RequiredTriggers = 40,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Crystals', IncrementValue = 200},
			CurrentTriggers = 0,
			Completed = false,
		}
	},
	
	Palace = {
		[1] = {
			Label = 'Kill 10 Players In 2v2 Mode',
			Triggers = {TriggerEnums.EnumList.CombatKillPlayer2v2},
			RequiredTriggers = 10,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Crystals', IncrementValue = 100},
			CurrentTriggers = 0,
			Completed = false,
		},
		[2] = {
			Label = 'Win 10 Matches In 1v1 Mode',
			Triggers = {TriggerEnums.EnumList.MatchWinMatch1v1},
			RequiredTriggers = 10,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Diamonds', IncrementValue = 120},
			CurrentTriggers = 0,
			Completed = false,
		},
		[3] = {
			Label = 'Use Your Ultimate Attack 35 Times',
			Triggers = {TriggerEnums.EnumList.CombatUsedUlt},
			RequiredTriggers = 35,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Crystals', IncrementValue = 75},
			CurrentTriggers = 0,
			Completed = false,
		}
	},
	
	Portal = {
		[1] = {
			Label = 'Kill 30 Players In 1v1 And 2v2 Mode',
			Triggers = {TriggerEnums.EnumList.CombatKillPlayer1v1, TriggerEnums.EnumList.CombatKillPlayer2v2},
			RequiredTriggers = 30,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Diamonds', IncrementValue = 175},
			CurrentTriggers = 0,
			Completed = false,
		},
		[2] = {
			Label = 'Win 20 Rounds In 2v2 Mode',
			Triggers = {TriggerEnums.EnumList.MatchWinRound2v2},
			RequiredTriggers = 20,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Crystals', IncrementValue = 130},
			CurrentTriggers = 0,
			Completed = false,
		},
		[3] = {
			Label = 'Use Your Ultimate Attack 50 Times',
			Triggers = {TriggerEnums.EnumList.CombatUsedUlt},
			RequiredTriggers = 50,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Diamonds', IncrementValue = 90},
			CurrentTriggers = 0,
			Completed = false,
		}
	},
	
	Skyruins = {
		[1] = {
			Label = 'Win 25 Matches In 1v1 And 2v2 Mode',
			Triggers = {TriggerEnums.EnumList.MatchWinMatch1v1, TriggerEnums.EnumList.MatchWinMatch2v2},
			RequiredTriggers = 25,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Diamonds', IncrementValue = 200},
			CurrentTriggers = 0,
			Completed = false,
		},
		[2] = {
			Label = 'Kill 20 Players In 2v2 Mode',
			Triggers = {TriggerEnums.EnumList.CombatKillPlayer2v2},
			RequiredTriggers = 20,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Crystals', IncrementValue = 110},
			CurrentTriggers = 0,
			Completed = false,
		},
		[3] = {
			Label = 'Win 30 Rounds In 1v1 Mode',
			Triggers = {TriggerEnums.EnumList.MatchWinRound1v1},
			RequiredTriggers = 30,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Crystals', IncrementValue = 160},
			CurrentTriggers = 0,
			Completed = false,
		}
	},
	
	Wasteland = {
		[1] = {
			Label = 'Kill 40 Players In 1v1 Mode',
			Triggers = {TriggerEnums.EnumList.CombatKillPlayer1v1},
			RequiredTriggers = 40,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Crystals', IncrementValue = 250},
			CurrentTriggers = 0,
			Completed = false,
		},
		[2] = {
			Label = 'Win 35 Rounds In 1v1 And 2v2 Mode',
			Triggers = {TriggerEnums.EnumList.MatchWinRound1v1, TriggerEnums.EnumList.MatchWinRound2v2},
			RequiredTriggers = 35,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Diamonds', IncrementValue = 150},
			CurrentTriggers = 0,
			Completed = false,
		},
		[3] = {
			Label = 'Use Your Ultimate Attack 75 Times',
			Triggers = {TriggerEnums.EnumList.CombatUsedUlt},
			RequiredTriggers = 75,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Diamonds', IncrementValue = 220},
			CurrentTriggers = 0,
			Completed = false,
		}
	},
}

return module