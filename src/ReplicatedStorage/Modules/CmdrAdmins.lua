--!strict
-- Shared list of UserIds allowed to open the Cmdr command bar (F2) and run commands.
-- Used by both the server (gates command execution) and the client (gates the F2 bar).
-- Add an admin by putting their UserId here.

local CmdrAdmins = {}

CmdrAdmins.UserIds = {
	[534803720] = true, -- col_derr
} :: { [number]: boolean }

function CmdrAdmins.IsAdmin(player: Player): boolean
	return CmdrAdmins.UserIds[player.UserId] == true
end

return CmdrAdmins
