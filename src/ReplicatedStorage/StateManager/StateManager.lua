local module = {}

local RunService = game:GetService("RunService")

local STATE_ENUM_MODULE = require(script.Parent.ENUM)
local STATE_ENUM = STATE_ENUM_MODULE.STATES_ENUM

-- Pasta onde estão os remotes / bindables
local Remotes = script.Parent.Remotes

local IS_SERVER = RunService:IsServer()
local WAIT_TIMEOUT = 15

-- Só esperamos os remotes do lado que realmente os usa, com timeout para
-- não travar o boot caso a pasta/remote esteja ausente.
local GET, POST, REMOVE
local GET_SV, POST_SV, REMOVE_SV

if IS_SERVER then
	GET_SV = Remotes:WaitForChild("GET_SV", WAIT_TIMEOUT)
	POST_SV = Remotes:WaitForChild("POST_SV", WAIT_TIMEOUT)
	REMOVE_SV = Remotes:WaitForChild("REMOVE_SV", WAIT_TIMEOUT)
else
	GET = Remotes:WaitForChild("GET", WAIT_TIMEOUT)
	POST = Remotes:WaitForChild("POST", WAIT_TIMEOUT)
	REMOVE = Remotes:WaitForChild("REMOVE", WAIT_TIMEOUT)
end

-- API unificada:
-- Client: InvokeServer(...)
-- Server: Invoke(player, ...)
local function Invoke(remoteClient: RemoteFunction?, bindableServer: BindableFunction?, player: Player?, ...)
	if IS_SERVER then
		assert(player, "No Server é obrigatório passar o Player como primeiro argumento.")
		assert(bindableServer, "[StateManager] BindableFunction do servidor ausente")
		return bindableServer:Invoke(player, ...)
	else
		if not remoteClient then
			warn("[StateManager] RemoteFunction do cliente ausente")
			return nil
		end
		local args = table.pack(...)
		local ok, result = pcall(function()
			return remoteClient:InvokeServer(table.unpack(args, 1, args.n))
		end)
		if not ok then
			warn("[StateManager] InvokeServer falhou:", result)
			return nil
		end
		return result
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
