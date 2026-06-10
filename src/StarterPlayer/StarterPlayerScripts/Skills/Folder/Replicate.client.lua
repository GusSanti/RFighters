--// Services \\--
local rs = game:GetService("ReplicatedStorage")

--// Remotes \\--
local remote = rs.SkillStorage.Shiro.Events:WaitForChild("Replicate")

--// Modules \\--
local module = require(script:WaitForChild("ShiroVFX"))


local function effect(effectname, params)
	local efunction = module[effectname]
	if efunction then
		efunction(params)
	else
		warn(effectname.. " does not exist for replication.")
	end
end

remote.OnClientEvent:Connect(effect)
