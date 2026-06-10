local CombatClient = {}

local SendInput = game.ReplicatedStorage.CombatSystem.Events.SendInput

function CombatClient.RegisterInput(inp: string, state: string) -- state is Began or Ended
	SendInput:FireServer(inp, state)
end

return CombatClient