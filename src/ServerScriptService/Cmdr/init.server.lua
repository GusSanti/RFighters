local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cmdr = require(ReplicatedStorage.Modules.Packages.Cmdr)

local CmdrAdmins = require(ReplicatedStorage.Modules.CmdrAdmins)

Cmdr:RegisterDefaultCommands()

Cmdr:RegisterTypesIn(script.CmdrTypes)
Cmdr:RegisterCommandsIn(script.CmdrCommands)

Cmdr.Registry:RegisterHook("BeforeRun", function(context)
	if not CmdrAdmins.IsAdmin(context.Executor) then
		return "You do not have permission to use commands."
	end
	return nil -- nil = allow the command to run
end)

print("[CmdrServer] boot complete")
