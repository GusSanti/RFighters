local SkillModule = {}

function SkillModule.UseSkill(ModuleLocation, Character)
	local Module = require(ModuleLocation)
	Module.UseSkill(Character)
	return Module
end

return SkillModule