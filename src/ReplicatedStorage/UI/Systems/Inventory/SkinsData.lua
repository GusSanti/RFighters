local module = {}

module.SkinsData = {
	Shiro = {
		AlternateStyle = {
			ModelName = "AlternateStyle",
			DisplayName = "Alternate Style",
			IsUnlocked = false,	
			IsEquiped = false
		}
	},

	Bolg = {
		AlternateStyle = {
			ModelName = "AlternateStyle",
			DisplayName = "Alternate Style",
			IsUnlocked = false,	
			IsEquiped = false
		}
	},
	
	Draug = {
		AlternateStyle = {
			ModelName = "AlternateStyle",
			DisplayName = "Alternate Style",
			IsUnlocked = false,
			IsEquiped = false
		}
	},
	
	Sparrow = {
		AlternateStyle = {
			ModelName = "AlternateStyle",
			DisplayName = "Alternate Style",
			IsUnlocked = false,
			IsEquiped = false
		}
	},
	
	TomTheTitanShark = {
		AlternateStyle = {
			ModelName = "AlternateStyle",
			DisplayName = "Alternate Style",
			IsUnlocked = false,
			IsEquiped = false
		}
	},
}

module.LimitedSkins = {
	{
		Skin = module.SkinsData.Bolg.AlternateStyle,
		DisplayTitle = "MAGMA SKIN (BOLG)",
		ProductID = 1860804120
	},
	{
		Skin = module.SkinsData.Draug.AlternateStyle,
		DisplayTitle = "FROST SKIN (DRAUG)",
		ProductID = 1861025072
	}
}

return module
