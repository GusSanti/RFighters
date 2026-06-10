local module = {}
local TriggerEnums = require(game.ReplicatedStorage.QuestAchievementsSystem.TriggersEnum)

module.QuestTemplates = {
	Daily = {
		[1] = {
			Label = 'Kill {X} Players In {Y} Mode',
			Triggers = {}, -- preenchido na geração: ex TriggerEnums.EnumList.CombatKillPlayer1v1
			RequiredTriggers = 0, -- preenchido na geração: X
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Crystals', IncrementValue = 0}, -- escala com X
			-- variáveis do template
			Template = {
				Action = 'KillPlayers',
				XRange = {min = 2, max = 5},
				YOptions = {'1v1', '2v2'},
				-- mapeia YOption -> Trigger e RewardKey
				TriggerMap = {
					['1v1'] = TriggerEnums.EnumList.CombatKillPlayer1v1,
					['2v2'] = TriggerEnums.EnumList.CombatKillPlayer2v2,
				},
				RewardKey = 'Crystals',
				RewardPerUnit = 8, -- IncrementValue = X * RewardPerUnit
			},
		},
		[2] = {
			Label = 'Win {X} Matches In {Y} Mode',
			Triggers = {},
			RequiredTriggers = 0,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Diamonds', IncrementValue = 0},
			Template = {
				Action = 'WinMatches',
				XRange = {min = 2, max = 6},
				YOptions = {'1v1', '2v2'},
				TriggerMap = {
					['1v1'] = TriggerEnums.EnumList.MatchWinMatch1v1,
					['2v2'] = TriggerEnums.EnumList.MatchWinMatch2v2,
				},
				RewardKey = 'Diamonds',
				RewardPerUnit = 12,
			},
		},
		[3] = {
			Label = 'Win {X} Rounds In {Y} Mode',
			Triggers = {},
			RequiredTriggers = 0,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Crystals', IncrementValue = 0},
			Template = {
				Action = 'WinRounds',
				XRange = {min = 2, max = 7},
				YOptions = {'1v1', '2v2'},
				TriggerMap = {
					['1v1'] = TriggerEnums.EnumList.MatchWinRound1v1,
					['2v2'] = TriggerEnums.EnumList.MatchWinRound2v2,
				},
				RewardKey = 'Crystals',
				RewardPerUnit = 10,
			},
		},
		[4] = {
			Label = 'Use Your Ultimate Attack {X} Times',
			Triggers = {},
			RequiredTriggers = 0,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Diamonds', IncrementValue = 0},
			Template = {
				Action = 'UseUlt',
				XRange = {min = 4, max = 10},
				YOptions = nil, -- sem variável Y, só X
				TriggerMap = {
					['any'] = TriggerEnums.EnumList.CombatUsedUlt,
				},
				RewardKey = 'Diamonds',
				RewardPerUnit = 6,
			},
		},
	},
	Weekly = {
		[1] = {
			Label = 'Kill {X} Players In {Y} Mode',
			Triggers = {},
			RequiredTriggers = 0,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Crystals', IncrementValue = 0},
			Template = {
				Action = 'KillPlayers',
				XRange = {min = 30, max = 60},
				YOptions = {'1v1', '2v2'},
				TriggerMap = {
					['1v1'] = TriggerEnums.EnumList.CombatKillPlayer1v1,
					['2v2'] = TriggerEnums.EnumList.CombatKillPlayer2v2,
				},
				RewardKey = 'Crystals',
				RewardPerUnit = 20,
			},
		},
		[2] = {
			Label = 'Win {X} Matches In {Y} Mode',
			Triggers = {},
			RequiredTriggers = 0,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Diamonds', IncrementValue = 0},
			Template = {
				Action = 'WinMatches',
				XRange = {min = 20, max = 40},
				YOptions = {'1v1', '2v2'},
				TriggerMap = {
					['1v1'] = TriggerEnums.EnumList.MatchWinMatch1v1,
					['2v2'] = TriggerEnums.EnumList.MatchWinMatch2v2,
				},
				RewardKey = 'Diamonds',
				RewardPerUnit = 30,
			},
		},
		[3] = {
			Label = 'Win {X} Rounds In {Y} Mode',
			Triggers = {},
			RequiredTriggers = 0,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Crystals', IncrementValue = 0},
			Template = {
				Action = 'WinRounds',
				XRange = {min = 30, max = 45},
				YOptions = {'1v1', '2v2'},
				TriggerMap = {
					['1v1'] = TriggerEnums.EnumList.MatchWinRound1v1,
					['2v2'] = TriggerEnums.EnumList.MatchWinRound2v2,
				},
				RewardKey = 'Crystals',
				RewardPerUnit = 25,
			},
		},
		[4] = {
			Label = 'Use Your Ultimate Attack {X} Times',
			Triggers = {},
			RequiredTriggers = 0,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Diamonds', IncrementValue = 0},
			Template = {
				Action = 'UseUlt',
				XRange = {min = 50, max = 80},
				YOptions = nil,
				TriggerMap = {
					['any'] = TriggerEnums.EnumList.CombatUsedUlt,
				},
				RewardKey = 'Diamonds',
				RewardPerUnit = 15,
			},
		},
	},
	Monthly = {
		[1] = {
			Label = 'Kill {X} Players In {Y} Mode',
			Triggers = {},
			RequiredTriggers = 0,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Crystals', IncrementValue = 0},
			Template = {
				Action = 'KillPlayers',
				XRange = {min = 150, max = 320},
				YOptions = {'1v1', '2v2'},
				TriggerMap = {
					['1v1'] = TriggerEnums.EnumList.CombatKillPlayer1v1,
					['2v2'] = TriggerEnums.EnumList.CombatKillPlayer2v2,
				},
				RewardKey = 'Crystals',
				RewardPerUnit = 50,
			},
		},
		[2] = {
			Label = 'Win {X} Matches In {Y} Mode',
			Triggers = {},
			RequiredTriggers = 0,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Diamonds', IncrementValue = 0},
			Template = {
				Action = 'WinMatches',
				XRange = {min = 70, max = 88},
				YOptions = {'1v1', '2v2'},
				TriggerMap = {
					['1v1'] = TriggerEnums.EnumList.MatchWinMatch1v1,
					['2v2'] = TriggerEnums.EnumList.MatchWinMatch2v2,
				},
				RewardKey = 'Diamonds',
				RewardPerUnit = 75,
			},
		},
		[3] = {
			Label = 'Win {X} Rounds In {Y} Mode',
			Triggers = {},
			RequiredTriggers = 0,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Crystals', IncrementValue = 0},
			Template = {
				Action = 'WinRounds',
				XRange = {min = 120, max = 180},
				YOptions = {'1v1', '2v2'},
				TriggerMap = {
					['1v1'] = TriggerEnums.EnumList.MatchWinRound1v1,
					['2v2'] = TriggerEnums.EnumList.MatchWinRound2v2,
				},
				RewardKey = 'Crystals',
				RewardPerUnit = 60,
			},
		},
		[4] = {
			Label = 'Use Your Ultimate Attack {X} Times',
			Triggers = {},
			RequiredTriggers = 0,
			Reward = {Type = 'PlayerStateIncrement', StateKey = 'Diamonds', IncrementValue = 0},
			Template = {
				Action = 'UseUlt',
				XRange = {min = 200, max = 380},
				YOptions = nil,
				TriggerMap = {
					['any'] = TriggerEnums.EnumList.CombatUsedUlt,
				},
				RewardKey = 'Diamonds',
				RewardPerUnit = 35,
			},
		},
	},
}
return module