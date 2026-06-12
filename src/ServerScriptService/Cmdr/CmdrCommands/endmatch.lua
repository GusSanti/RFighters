-- Command definition (shared). Paired with endmatchServer.luau which holds the Run.
-- Force-ends a player's match and shows the WinnerScreen, for testing the end screen.
return {
	Name = "endmatch",
	Aliases = { "forcewin" },
	Description = "Ends a player's match and shows the WinnerScreen (test).",
	Group = "Admin",
	Args = {
		{
			Type = "player",
			Name = "target",
			Description = "Player whose match to end.",
		},
		{
			Type = "string",
			Name = "result",
			Description = "Show target as 'win' or 'lose'. Default win.",
			Optional = true,
		},
	},
}
