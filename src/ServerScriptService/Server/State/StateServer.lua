local module = {}

local STATE_ENUM_MODULE = require(game.ReplicatedStorage.StateManager.ENUM)
local STATES_ENUM = STATE_ENUM_MODULE.STATES_ENUM

local GET_CLIENT_REMOTE = game.ReplicatedStorage.StateManager.Remotes.GET
local POST_CLIENT_REMOTE = game.ReplicatedStorage.StateManager.Remotes.POST
local REMOVE_CLIENT_REMOTE = game.ReplicatedStorage.StateManager.Remotes.REMOVE

local POST_SERVER_BINDABLE = game.ReplicatedStorage.StateManager.Remotes.POST_SV
local GET_SERVER_BINDABLE = game.ReplicatedStorage.StateManager.Remotes.GET_SV
local REMOVE_SERVER_BINDABLE = game.ReplicatedStorage.StateManager.Remotes.REMOVE_SV

local UPDATE_EVENT = game.ReplicatedStorage.StateManager.Remotes.UPDATE_EVENT

local CHARACTERS_LIST = {
	Players = {},
	NPCs = {}
}

local DEFAULT_WALKSPEED = 17
local DEFAULT_JUMPHEIGHT = 7.2

-- Tabela de prioridades (maior número = maior prioridade)
local STATE_PRIORITY = {
	[STATES_ENUM.COMBAT_COUNTDOWN_STUNNED] = 11,
	[STATES_ENUM.COMBAT_FULL_STUNNED] = 10,
	[STATES_ENUM.COMBAT_FROZEN_STUNNED] = 9.9,
	[STATES_ENUM.COMBAT_PARRYING] = 9.5,
	[STATES_ENUM.COMBAT_BLOCKING] = 5,
	[STATES_ENUM.COMBAT_BEING_ATTACKED] = 9,
	[STATES_ENUM.COMBAT_CROUCHING] = 8,
	[STATES_ENUM.COMBAT_CHARGING_ATTACK] = 7,
	[STATES_ENUM.COMBAT_SLIGHTLY_STUNNED] = 6,
	[STATES_ENUM.COMBAT_DOING_COMBAT] = 5,
	[STATES_ENUM.MOVEMENT_RUNNING] = 4,
	[STATES_ENUM.COMBAT_CLICKING] = 3,
	[STATES_ENUM.COMBAT_INSKILL] = 2,
}

local STATE_STATS = {
	[STATES_ENUM.COMBAT_FULL_STUNNED] = {WalkSpeed = 0, JumpHeight = 0},
	[STATES_ENUM.COMBAT_FROZEN_STUNNED] = {WalkSpeed = 0, JumpHeight = 0},
	[STATES_ENUM.COMBAT_COUNTDOWN_STUNNED] = {WalkSpeed = 0, JumpHeight = 0},
	[STATES_ENUM.COMBAT_PARRYING] = {WalkSpeed = 0, JumpHeight = 0},
	[STATES_ENUM.COMBAT_BLOCKING] = {WalkSpeed = 6, JumpHeight = 0},
	[STATES_ENUM.COMBAT_CROUCHING] = {WalkSpeed = 2, JumpHeight = 0},
	[STATES_ENUM.COMBAT_SLIGHTLY_STUNNED] = {WalkSpeed = 6, JumpHeight = 4},
	[STATES_ENUM.COMBAT_DOING_COMBAT] = {WalkSpeed = DEFAULT_WALKSPEED / 4, JumpHeight = 0},
	[STATES_ENUM.MOVEMENT_RUNNING] = {WalkSpeed = 34, JumpHeight = 7.2},
	[STATES_ENUM.COMBAT_BEING_ATTACKED] = {WalkSpeed = 0, JumpHeight = 0},
	[STATES_ENUM.COMBAT_CHARGING_ATTACK] = {WalkSpeed = 0, JumpHeight = 0}
}

local TestStatusDebug = false

local function GetCharacter(TARGET)
	if TARGET:IsA("Player") then
		return TARGET.Character
	elseif TARGET:IsA("Model") and TARGET:FindFirstChild("Humanoid") then
		return TARGET
	end
	return nil
end

-- ========================================
-- FUNÇÃO GET: Retorna a tabela de estados
-- ========================================
local function GET(TARGET)
	local character = GetCharacter(TARGET)
	if not character then return {} end

	local plr = game.Players:GetPlayerFromCharacter(character)

	if plr then
		if not CHARACTERS_LIST.Players[character] then
			CHARACTERS_LIST.Players[character] = {}
		end
		return CHARACTERS_LIST.Players[character]
	else
		if not CHARACTERS_LIST.NPCs[character] then
			CHARACTERS_LIST.NPCs[character] = {}
		end
		return CHARACTERS_LIST.NPCs[character]
	end
end


local function ApplyStats(Character)
	if not Character then return end
	local humanoid = Character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local states = GET(Character)
	if not states then return end

	local highestPriority = -1
	local activeState = nil

	for state, _ in pairs(states) do
		local priority = STATE_PRIORITY[state] or 0
		if priority > highestPriority and STATE_STATS[state] then
			highestPriority = priority
			activeState = state
		end
	end

	if activeState and STATE_STATS[activeState] then
		local stats = STATE_STATS[activeState]
		humanoid.WalkSpeed = stats.WalkSpeed
		humanoid.JumpHeight = stats.JumpHeight
	else
		humanoid.WalkSpeed = DEFAULT_WALKSPEED
		humanoid.JumpHeight = DEFAULT_JUMPHEIGHT
	end
end

-- ========================================
-- FUNÇÃO POST: Ativa um estado
-- ========================================
local function POST(TARGET, ENUM)
	-- Valida se o ENUM existe
	local check = false
	for i, v in pairs(STATES_ENUM) do
		if i == ENUM and v == ENUM then check = true end
	end
	if check == false then return false end

	local character = GetCharacter(TARGET)
	if not character then 
		warn("POST: Character não encontrado")
		return false 
	end

	local plr = game.Players:GetPlayerFromCharacter(character)
	local isPlayer = plr ~= nil

	local get = GET(character)
	if not get then 
		warn("GET não encontrado em POST")
		return false 
	end

	-- Debug
	if TestStatusDebug == true then
		if isPlayer then
			print("[PLAYER STATE POST] →", character.Name, "ativou", ENUM)
		else
			print("[NPC STATE POST] →", character.Name, "ativou", ENUM)
		end
	end

	if not get[ENUM] then get[ENUM] = {ENUM} else table.insert(get[ENUM], ENUM) end

	ApplyStats(character)

	local plr = game.Players:GetPlayerFromCharacter(character)
	local isPlayer = plr ~= nil
	if isPlayer then
		local get = GET(character)
		UPDATE_EVENT:FireClient(plr,get)
		if TestStatusDebug == true then warn("STATES UPDATED: NEW STASTES: ",get) end
	end

	return true
end

local function REMOVE(TARGET, ENUM)
	-- Valida se o ENUM existe
	local check = false
	for i, v in pairs(STATES_ENUM) do
		if i == ENUM and v == ENUM then check = true end
	end
	if check == false then return false end

	local character = GetCharacter(TARGET)
	if not character then 
		warn("REMOVE: Character não encontrado")
		return false 
	end

	local get_result = GET(character)
	if not get_result then
		warn("REMOVE: Tabela de estados não encontrada")
		return false
	end

	local stateTable = get_result[ENUM]
	if not stateTable then 
		return false 
	end

	-- Remove o último valor da tabela
	table.remove(stateTable)

	-- Se a tabela ficar vazia, apaga completamente o estado
	if #stateTable == 0 then
		get_result[ENUM] = nil
	end

	-- Debug opcional
	if TestStatusDebug == true then
		print("[STATE REMOVE] →", character.Name, "desativou", ENUM)
	end

	-- Reaplica stats baseadas nos estados restantes
	ApplyStats(character)

	local plr = game.Players:GetPlayerFromCharacter(character)
	local isPlayer = plr ~= nil
	if isPlayer then
		local get = GET(character)
		UPDATE_EVENT:FireClient(plr,get)
		if TestStatusDebug == true then warn("STATES UPDATED: NEW STASTES: ",get) end
	end

	return true
end

GET_CLIENT_REMOTE.OnServerInvoke = function(plr)
	return GET(plr)
end

POST_CLIENT_REMOTE.OnServerInvoke = function(plr, ENUM)
	return POST(plr, ENUM)
end

REMOVE_CLIENT_REMOTE.OnServerInvoke = function(plr, ENUM)
	return REMOVE(plr, ENUM)
end

GET_SERVER_BINDABLE.OnInvoke = function(plr)
	return GET(plr)
end

POST_SERVER_BINDABLE.OnInvoke = function(plr, ENUM)
	return POST(plr, ENUM)
end

REMOVE_SERVER_BINDABLE.OnInvoke = function(plr, ENUM)
	return REMOVE(plr, ENUM)
end

return module
