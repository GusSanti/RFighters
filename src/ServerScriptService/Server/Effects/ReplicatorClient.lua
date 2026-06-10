local module = {}

local EffectsReplicatorEvent = game.ReplicatedStorage.CombatSystem.Events.ClientToServerEffect
local ServerEffectsReplicatorEvent = game.ReplicatedStorage.CombatSystem.Events.EffectsReplicatorEvent

EffectsReplicatorEvent.OnServerEvent:Connect(function(plr, ...)
	ServerEffectsReplicatorEvent:FireAllClients(...)
end)

return module