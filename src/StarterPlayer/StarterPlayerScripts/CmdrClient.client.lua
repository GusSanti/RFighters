-- Boots the Cmdr client UI and disables the command bar (F2) for non-admins.
-- The server moves CmdrClient into ReplicatedStorage during Cmdr init.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CmdrAdmins = require(ReplicatedStorage.Modules.CmdrAdmins)
local CmdrClient = require(ReplicatedStorage:WaitForChild("CmdrClient", math.huge))

-- Players without access can't open the bar with F2.
-- SetEnabled(false) makes Show/Toggle no-op, so the activation key does nothing.
if not CmdrAdmins.IsAdmin(Players.LocalPlayer) then
	CmdrClient:SetEnabled(false)
end
