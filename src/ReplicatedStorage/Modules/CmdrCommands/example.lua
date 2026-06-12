-- Command definition (shared). Paired with exampleServer.luau which holds the Run.
-- Copy this pair to make new commands: <name>.luau + <name>Server.luau
return {
	Name = "example",
	Aliases = {},
	Description = "Example command. Greets a player.",
	Group = "Admin",
	Args = {
		{
			Type = "player",
			Name = "target",
			Description = "Player to greet.",
		},
	},
}
