-- CharacterShake (Server)
-- Só dispara FireAllClients. O shake executa no client de cada jogador.

local ShakeEvent = game.ReplicatedStorage.CombatSystem.Events.CharacterShake
-- Crie um RemoteEvent chamado "CharacterShake" dentro de CombatSystem/Events

local CharacterShake = {}

function CharacterShake.hit(character, options)
	if not character then return end
	ShakeEvent:FireAllClients(character, options or {})
end

return CharacterShake