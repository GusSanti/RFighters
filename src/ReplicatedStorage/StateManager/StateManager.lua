local module = {}

local RunService = game:GetService("RunService")

local STATE_ENUM_MODULE = require(script.Parent.ENUM)
local STATE_ENUM = STATE_ENUM_MODULE.STATES_ENUM

-- Pasta onde estão os remotes / bindables
local Remotes = script.Parent.Remotes

-- Client (RemoteFunctions)
local GET = Remotes:WaitForChild("GET")
local POST = Remotes:WaitForChild("POST")
local REMOVE = Remotes:WaitForChild("REMOVE")

-- Server (BindableFunctions)
local GET_SV = Remotes:WaitForChild("GET_SV")
local POST_SV = Remotes:WaitForChild("POST_SV")
local REMOVE_SV = Remotes:WaitForChild("REMOVE_SV")

-- API unificada:
-- Client: InvokeServer(...)
-- Server: Invoke(player, ...)
local function Invoke(remoteClient: RemoteFunction, bindableServer: BindableFunction, player: Player?, ...)
	if RunService:IsServer() then
		assert(player, "No Server é obrigatório passar o Player como primeiro argumento.")
		return bindableServer:Invoke(player, ...)
	else
		return remoteClient:InvokeServer(...)
	end
end

function module.POST(player: Player?, ENUM)
	return Invoke(POST, POST_SV, player, ENUM)
end

function module.GET(player: Player?)
	return Invoke(GET, GET_SV, player)
end

function module.REMOVE(player: Player?, ENUM)
	return Invoke(REMOVE, REMOVE_SV, player, ENUM)
end

function module.POST_REMOVE(player: Player?, ENUM, Time)
	module.POST(player, ENUM)

	task.delay(Time, function()
		module.REMOVE(player, ENUM)
	end)
end

return module
