return {
	Crystals = 0, 
	Diamonds = 0,
	Xp = 0,
	Level = 0,
	Wins = 0,
	Kills = 0,
	KillStreak = 0,
	PlayTime = 0,
	Rolls = 1000,
	DiscountExpiry = 0,
	
	HasVIP = false,
	Has2xLuck = false,
	Has2xXP = false,
	Has2xCrystals = false,
	
	HasDoneTutorial = false, 
	HasBattlepassPremium = false,
	
	ClaimedRollDiscount = false,
	ClaimedCrystalDiscount = false,
	ClaimedStarterBundle = false,
	
	ActiveCharacter = 'Shiro',
	
	CharacterIndex = {
		
	},	
	
	UnlockedSkins = {},
	
	ClaimedBattlepassRewards = {
		Free = {
			First = false,
			Ranks = {}
		},
		
		Premium = {
			First = false,
			Ranks = {}
		}
	},
	
	ClaimedIndexRewards = {},
	
	OwnedEmotes    = {},
	EquippedEmotes = {"","","","","","","",""},
	
	Inputs = {
		RIGHT = {Enum.KeyCode.D.Name, Enum.KeyCode.Right.Name, Enum.KeyCode.Thumbstick1.Name .. "_RIGHT"},
		LEFT = {Enum.KeyCode.A.Name, Enum.KeyCode.Left.Name, Enum.KeyCode.Thumbstick1.Name .. "_LEFT"},
		JUMP = {Enum.KeyCode.W.Name, Enum.KeyCode.Up.Name, Enum.KeyCode.ButtonA.Name},
		CROUCH = {Enum.KeyCode.S.Name, Enum.KeyCode.Down.Name, Enum.KeyCode.Thumbstick1.Name .. "_DOWN"},

		LIGHTATK = {Enum.KeyCode.U.Name, Enum.UserInputType.MouseButton1.Name, Enum.KeyCode.ButtonX.Name},
		HARDATK = {Enum.KeyCode.I.Name, Enum.UserInputType.MouseButton2.Name, Enum.KeyCode.ButtonY.Name},
		CHARGEATK = {Enum.KeyCode.O.Name, Enum.KeyCode.Q.Name, Enum.KeyCode.ButtonB.Name},
		GRAB = {Enum.KeyCode.P.Name, Enum.KeyCode.E.Name, Enum.KeyCode.ButtonR1.Name},
		BLOCK = {Enum.KeyCode.F.Name, Enum.KeyCode.Y.Name},

		ULTIMATE = {Enum.KeyCode.G.Name, Enum.KeyCode.ButtonL1.Name},

		EMOTE = {Enum.KeyCode.B.Name},

		SKILL1 = {Enum.KeyCode.One.Name, Enum.KeyCode.ButtonR2.Name},
		SKILL2 = {Enum.KeyCode.Two.Name, Enum.KeyCode.ButtonL2.Name},
		SKILL3 = {Enum.KeyCode.Three.Name},
		SKILL4 = {Enum.KeyCode.Four.Name}
	},
	
	Achievements = nil,
	
	Quests = nil,
	
	Tags = nil,
	EquippedTag = nil,
	
	Daily = {
		CurrentDay = 1,
		LastClaim = 0,	
	},

	Gifts = {},

	["leaderstats"] = {
		["Wins"] = "Wins",
		["Level"] = "Level",
		["PlayTime"] = "PlayTime",
		['KillStreak'] = 'KillStreak'
	}
}