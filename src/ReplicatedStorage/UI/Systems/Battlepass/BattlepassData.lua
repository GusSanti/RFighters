local module = {}

module.BattlepassData = {
	FirstRewards = {
		Free = {Type = "Crystals", Amount = 500},
		Premium = {Type = "Diamonds", Amount = 1000}
	},
	
	Rewards = {
		Free = {
			[1] = {Type = "Crystals", Amount = 450},
			[2] = {Type = "None"},
			[3] = {Type = "Rolls", Amount = 4},
			[4] = {Type = "None"},
			[5] = {Type = "None"},
			[6] = {Type = "Diamonds", Amount = 150},
			[7] = {Type = "None"},
			[8] = {Type = "None"},
			[9] = {Type = "Crystals", Amount = 900},
			[10] = {Type = "Diamonds", Amount = 250},
			[11] = {Type = "None"},
			[12] = {Type = "Skin", SkinCharacter = "Shiro", SkinName = "AlternateStyle"},
			[13] = {Type = "None"},
			[14] = {Type = "Rolls", Amount = 20},
			[15] = {Type = "Crystals", Amount = 3000},
		},
		
		Premium = {
			[1] = {Type = "Diamonds", Amount = 850},
			[2] = {Type = "Crystals", Amount = 1000},
			[3] = {Type = "Skin", SkinCharacter = "Bolg", SkinName = "AlternateStyle"},
			[4] = {Type = "Diamonds", Amount = 1500},
			[5] = {Type = "Skin", SkinCharacter = "Draug", SkinName = "AlternateStyle"},
			[6] = {Type = "Rolls", Amount = 20},
			[7] = {Type = "Crystals", Amount = 2000},
			[8] = {Type = "Diamonds", Amount = 2250},
			[9] = {Type = "Rolls", Amount = 30},
			[10] = {Type = "Diamonds", Amount = 3000},
			[11] = {Type = "Rolls", Amount = 35},
			[12] = {Type = "Diamonds", Amount = 4400},
			[13] = {Type = "Crystals", Amount = 4900},
			[14] = {Type = "Rolls", Amount = 40},
			[15] = {Type = "Diamonds", Amount = 5550}
		}
	}
}

return module
