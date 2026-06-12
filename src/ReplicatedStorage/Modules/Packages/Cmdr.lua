-- Resolve the Cmdr server ModuleScript across sync layouts.
-- Rojo (honoring the package's nested default.project.json) collapses the
-- `cmdr` folder directly into the Cmdr ModuleScript. Tools that ignore the
-- nested project file leave `cmdr` as a Folder whose child `Cmdr` is the module.
local cmdr = script.Parent._Index["evaera_cmdr@1.12.0"]["cmdr"]
if not cmdr:IsA("ModuleScript") then
	cmdr = cmdr:WaitForChild("Cmdr")
end
return require(cmdr)
