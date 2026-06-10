local CharacterManager = {}
local RunService = game:GetService('RunService')

local PlayerState = nil
local CombatStorageFolder = nil

if RunService:IsServer() then
	PlayerState = require(game.ReplicatedStorage.PlayerState.PlayerStateServer)
	CombatStorageFolder = game.ServerStorage.CombatStorage.CharacterStorage
else
	PlayerState = require(game.ReplicatedStorage.PlayerState.PlayerStateClient)
end

function CharacterManager.GetActiveCharacterName(plr)
	if RunService:IsServer() then
		local ActiveCharacter = PlayerState.Get(plr, 'ActiveCharacter')

		return ActiveCharacter or 'None'
	else
		local ActiveCharacter = PlayerState.Get('ActiveCharacter')
		
		return ActiveCharacter or 'None'
	end
end

function CharacterManager.GetModule(player)
	if RunService:IsClient() then
		error('This function can only be used on the server')
		
		return
	end
	
	local ActiveCharacter = PlayerState.Get(player, 'ActiveCharacter')
	
	return require(CombatStorageFolder:FindFirstChild(ActiveCharacter):FindFirstChild('StorageModule'))

end

return CharacterManager
