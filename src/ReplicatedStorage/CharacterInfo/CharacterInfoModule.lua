--!strict
export type SkillInfo = {
	name : string,
	bind : string,
	description : string,
}

export type CharacterData = {
	id          : string,
	name        : string,
	rarity      : "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary",
	description : string,
	AnimId      : number?,
	Skills      : { SkillInfo },
}

local Characters: { CharacterData } = {
	-- ============ COMMON ============
	{
		id          = "Shiro",
		name        = "Shiro",
		rarity      = "Common",
		description = "An elite swordsman with ultimate mastery of all forms of blades. ",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "8 dagger slice combo (short melee)" },
			{ name = "Skill2",  bind = "Two", description = "8 broadsword slice combo (long melee)" },
			{ name = "Ultimate", bind = "G",   description = "Energy blast from the sword (range)" },
		},
	},
	{
		id          = "Draug",
		name        = "Draug",
		rarity      = "Uncommon",
		description = "Six months ago, Blackspire scientists resurrected Draug, a Viking who was killed while invading England in 1067 C.E.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Axe attack (melee)" },
			{ name = "Skill2",  bind = "Two", description = "A deadly scream to pierce the soul and stun the opponent (range)" },
			{ name = "Ultimate", bind = "G",   description = "Raise the undead to attack the opponent (AOE)" },
		},
	},
	{
		id          = "Bolg",
		name        = "Bolg",
		rarity      = "Common",
		description = "Once an indigenous tribe on Mimas, all but Bolg has been wiped out after Blackspire’s colonisation. ",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Fire arrows to burn the opponent (range)" },
			{ name = "Skill2",  bind = "Two", description = "Triple-shot frost arrows to freeze the opponent (range)" },
			{ name = "Ultimate", bind = "G",   description = "Orc Rage (4 seconds) — 200% increase in strength and attack damage (buff)" },
		},
	},
	--[[
	{
		id          = "Snapper",
		name        = "Snapper",
		rarity      = "Common",
		description = "A turtle-like fighter who launches rockets from his shell and delivers crushing melee slams.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Shell slam — Jumps and slams onto the opponent (melee)" },
			{ name = "Skill2",  bind = "Two", description = "Spinning leg kick (melee)" },
			{ name = "Ultimate", bind = "G",   description = "Launches a rocket from his shell and gives an AOE damage when it explodes (range / AOE)" },
		},
	},

	{
		id          = "EvilBunny",
		name        = "Evil Bunny",
		rarity      = "Common",
		description = "A deceptively dangerous rabbit experiment gone wrong.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Stings the opponent with a poison that slows and deals damage over time (stun)" },
			{ name = "Skill2",  bind = "Two", description = "Shoots a poison dart, which causes the opponent to attack itself for 5 seconds" },
			{ name = "Ultimate", bind = "G",   description = "Shoots out her tongue and catches the opponent to pull them into range and deals a 5-hit combo (range)" },
		},
	},
	]]
	-- ============ UNCOMMON ============
	{
		id          = "TomTheTitanShark",
		name        = "Tom the Titan Shark",
		rarity      = "Epic",
		description = "A human-shark hybrid that escaped from the Blackspire lab.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Chomp! — Bites down on opponent (melee)" },
			{ name = "Skill2",  bind = "Two", description = "Tail Spin — Massive 360° tail slap (melee)" },
			{ name = "Ultimate", bind = "G",   description = "Fin Beam — Fires an energy beam from his top fin (ranged)" },
		},
	},
	{
		id          = "Sparrow",
		name        = "Sparrow",
		rarity      = "Rare",
		description = "A charismatic pirate who vows to destroy the enemies who destroyed his ship.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Feather dust (4 seconds) — debuff opponent's attack speed and damage (debuff)" },
			{ name = "Skill2",  bind = "Two", description = "Heal a portion of his health (save)" },
			{ name = "Ultimate", bind = "G",   description = "Swashbuckling — powerful sword attack (melee)" },
		},
	},
	--[[
	{
		id          = "SirusTheClown",
		name        = "Sirus the Clown",
		rarity      = "Uncommon",
		description = "A terrifying clown who uses fear and laughter to freeze and crush opponents with a giant colourful hammer.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Fear — Aura to reduce/slow opponent defences" },
			{ name = "Skill2",  bind = "Two", description = "Laughter — Freezes opponent for 2.5 seconds" },
			{ name = "Ultimate", bind = "G",   description = "Smashes the opponent with a giant colourful hammer. Explodes upon impact (melee)" },
		},
	},
	{
		id          = "IstemiCapy",
		name        = "Istemi Capy",
		rarity      = "Uncommon",
		description = "A Capybara mecha monstrosity from one of the Scientist's earliest experiments. Istemi hides his wrath behind the Capybara's calm exterior.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "5 punch combo (melee)" },
			{ name = "Skill2",  bind = "Two", description = "Gatling gun (range)" },
			{ name = "Ultimate", bind = "G",   description = "Grabs opponent and lifts opponent in the air before slamming into the ground (AOE)" },
		},
	},

	-- ============ RARE ============
	{
		id          = "Molten",
		name        = "Molten",
		rarity      = "Rare",
		description = "Test subject #54 fell into lava and absorbed its natural properties. A fiery creature that burns everything in his path — Molten will only rest when he has his revenge against the Scientist.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Earth pulse — Small ground shockwave" },
			{ name = "Skill2",  bind = "Two", description = "Mountain stance — Heavy armour for 2 seconds" },
			{ name = "Ultimate", bind = "G",   description = "Seismic Rupture — Crack the ground to erupt molten lava" },
		},
	},
	{
		id          = "Thoosa",
		name        = "Thoosa",
		rarity      = "Rare",
		description = "A Cyclops who lost her eyes as a child. She gained powerful abilities after signing up as a test subject.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Spinning heel kick (melee)" },
			{ name = "Skill2",  bind = "Two", description = "Harden shield (4 seconds) — 200% increase in armour (buff)" },
			{ name = "Ultimate", bind = "G",   description = "Fires a powerful energy beam from the eyes (range)" },
		},
	},
	{
		id          = "Bloom",
		name        = "Bloom",
		rarity      = "Rare",
		description = "A tree-like Nature Guardian who traps opponents with thorns and heals himself over time.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Thorn Trap — Ground snare" },
			{ name = "Skill2",  bind = "Two", description = "Bloom Heal — Self-heal over time" },
			{ name = "Ultimate", bind = "G",   description = "Verdant Bloom — Giant flower explosion" },
		},
	},
	{
		id          = "LenamaOcto",
		name        = "Lenama Octo",
		rarity      = "Rare",
		description = "A human octopus hybrid remotely controlled by a microchip implant in the brain. A short circuit freed her from the Scientist's control.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Psychic siren call that immobilises the opponent (Psychic)" },
			{ name = "Skill2",  bind = "Two", description = "Whirlpool that lifts the opponent to the air and slams to the ground (AOE)" },
			{ name = "Ultimate", bind = "G",   description = "8-Legged attack (melee)" },
		},
	},

	{
		id          = "Panda",
		name        = "Panda",
		rarity      = "Rare",
		description = "A cheerful panda with a hidden ruthless side, blending charm with overwhelming brute strength in battle.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Skill1" },
			{ name = "Skill2",  bind = "Two", description = "Skill2" },
			{ name = "Ultimate", bind = "G",   description = "Ultimate" },
		},
	},

	-- ============ EPIC ============
	{
		id          = "GladhorTheGladiator",
		name        = "Gladhor the Gladiator",
		rarity      = "Epic",
		description = "A Butcher kidnapped on Earth. The Scientist turned him into a ruthless assassin by wiping his memory and equipping him with alien technology. All he remembers is slicing and dicing whoever stands in his way.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Releases an energy blast from his sword (range)" },
			{ name = "Skill2",  bind = "Two", description = "Slams his sword on his shield, creating a shockwave, stunning his opponent for 1 second (stun)" },
			{ name = "Ultimate", bind = "G",   description = "12 Slice combo (melee)" },
		},
	},
	{
		id          = "Bolt",
		name        = "Bolt (Cyber Brawler)",
		rarity      = "Epic",
		description = "A Speedster who wears an orange suit with 'B' as his logo. Fused with electricity, he is able to travel close to the speed of light.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Volt punch — Electrical stun on heavy attacks" },
			{ name = "Skill2",  bind = "Two", description = "Circuit dash — Lightning speed micro-dash" },
			{ name = "Ultimate", bind = "G",   description = "Thunder Collapse — Massive lightning pillar drop" },
		},
	},
	]]
	{
		id          = "Grimm",
		name        = "Grimm - The Death Watcher",
		rarity      = "Legendary",
		description = "The death reaper transformed into a fighting machine after Blackspire scientists altered his consciousness.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Slows the opponent's movements for 5 seconds (slow)" },
			{ name = "Skill2",  bind = "Two", description = "Life steal — Steals a portion of the opponent's health" },
			{ name = "Ultimate", bind = "G",   description = "Scythe slice — Damage done based on the opponent's missing health" },
		},
	},
	--[[
	{
		id          = "Chicken",
		name        = "Chicken",
		rarity      = "Epic",
		description = "A fierce and unpredictable chicken warrior, striking fast with blinding speed and explosive energy.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Skill1" },
			{ name = "Skill2",  bind = "Two", description = "Skill2" },
			{ name = "Ultimate", bind = "G",   description = "Ultimate" },
		},
	},

	{
		id          = "Toad",
		name        = "Toad",
		rarity      = "Epic",
		description = "A stealthy ninja frog wielding a sharp kunai, combining swift kung fu strikes with deadly precision.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Stings the opponent with a poison that slows and deals damage over time (stun)" },
			{ name = "Skill2",  bind = "Two", description = "Shoots a poison dart, which causes the opponent to attack itself for 5 seconds" },
			{ name = "Ultimate", bind = "G",   description = "Shoots out her tongue and catches the opponent to pull them into range and deals a 5-hit combo (range)" },
		},
	},

	-- ============ LEGENDARY ============
	{
		id          = "JunoTheBear",
		name        = "Juno The Bear (Frost Monk)",
		rarity      = "Legendary",
		description = "A Frost Polar Bear. Being in Juno's presence feels like the North Pole. He freezes everything he touches.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Frozen Palm — Freezes opponent on hits" },
			{ name = "Skill2",  bind = "Two", description = "Ice Wall — Short-lasting ice barrier" },
			{ name = "Ultimate", bind = "G",   description = "Absolute Zero — Freezes time briefly for heavy strikes" },
		},
	},

	{
		id          = "Severa",
		name        = "Severa",
		rarity      = "Legendary",
		description = "A merge of the Cat and Fox characters into conjoined twins. Male and Female conjoined twins weirdly fused from the experimentations.",
		Skills = {
			{ name = "Skill1",  bind = "One", description = "Pulls opponent towards the impact point — opponent is unable to attack during pull" },
			{ name = "Skill2",  bind = "Two", description = "Projectiles pass through the opponent's shield/guard" },
			{ name = "Ultimate", bind = "G",   description = "Steals the opponent's Super ability and uses it against them (melee)" },
		},
	},
	]]
}

return Characters
