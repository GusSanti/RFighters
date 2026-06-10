
--!strict
local SlotServer = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerState       = require(ReplicatedStorage.PlayerState.PlayerStateServer)

local SlotEvents: RemoteEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SlotEvents")
local GetCharacterPoolData = game.ReplicatedStorage.Events.GetCharacterPoolData
local RegisterNewCharacterIndexEvent = ReplicatedStorage.Events.RegisterNewCharacterIndex

local DEFAULT_SLOTS = 1

type SlotData = {
	id          : string,
	name        : string,
	rarity      : string,
	description : string?,
	AnimId      : number?,
}

-- ─────────────────────────────────────────
-- Helpers internos
-- ─────────────────────────────────────────

local function getSlotCount(player: Player): number
	return PlayerState.Get(player, "SlotCount") or DEFAULT_SLOTS
end

local function getSlots(player: Player): { [number]: SlotData? }
	return PlayerState.Get(player, "Slots") or {}
end

local function saveSlots(player: Player, slots: { [number]: SlotData? })
	PlayerState.Set(player, "Slots", slots)
end

-- ─────────────────────────────────────────
-- API pública
-- ─────────────────────────────────────────

-- Chamado pelo RollServer após roll bem-sucedido
-- Preenche o primeiro slot vazio; se todos cheios, substitui o slot 1
function SlotServer.FillSlot(player: Player, characterData: SlotData)
	local slotCount = getSlotCount(player)
	local slots     = getSlots(player)

	local targetIndex: number = 1
	local foundEmpty = false
	for i = 1, slotCount do
		if slots[i] == nil then
			targetIndex = i
			foundEmpty  = true
			break
		end
	end

	if not foundEmpty then
		-- ✅ Substitui o slot equipado, não o slot 1
		local equippedSlot = PlayerState.Get(player, "EquippedSlot") or 1
		warn(`[SlotServer] {player.Name}: todos os slots cheios, substituindo slot equipado ({equippedSlot})`)
		targetIndex = equippedSlot
	end

	slots[targetIndex] = {
		id          = characterData.id,
		name        = characterData.name,
		rarity      = characterData.rarity,
		description = characterData.description,
		AnimId      = characterData.AnimId,
	}

	saveSlots(player, slots)

	-- ✅ Se o slot preenchido é o único/equipado, re-equipa automaticamente
	local equippedSlot = PlayerState.Get(player, "EquippedSlot") or 0
	if equippedSlot == 0 or equippedSlot == targetIndex then
		PlayerState.Set(player, "ActiveCharacter", characterData.id)
		PlayerState.Set(player, "EquippedSlot", targetIndex)
	end

	SlotEvents:FireClient(player, "SlotFilled", targetIndex, slots[targetIndex])
	print(`[SlotServer] {player.Name} → slot {targetIndex} preenchido: {characterData.name}`)
end

-- Chamado por outro script para dar mais slots ao player
function SlotServer.GiveSlot(player: Player, amount: number?)
	local qty       = amount or 1
	local current   = getSlotCount(player)
	local newCount  = current + qty

	PlayerState.Set(player, "SlotCount", newCount)
	SlotEvents:FireClient(player, "SlotsExpanded", newCount)
	print(`[SlotServer] {player.Name} recebeu {qty} slot(s). Total: {newCount}`)
end

-- ─────────────────────────────────────────
-- Equipar / Desequipar
-- ─────────────────────────────────────────

local function equipSlot(player: Player, slotIndex: number)
	local slotCount = getSlotCount(player)
	if slotIndex < 1 or slotIndex > slotCount then
		SlotEvents:FireClient(player, "EquipResult", false, slotIndex, "Slot inválido.")
		return
	end

	local slots = getSlots(player)
	local slot  = slots[slotIndex]
	if not slot then
		SlotEvents:FireClient(player, "EquipResult", false, slotIndex, "Slot vazio.")
		return
	end

	local ok = PlayerState.Set(player, "ActiveCharacter", slot.id)
	if ok then
		PlayerState.Set(player, "EquippedSlot", slotIndex)
		SlotEvents:FireClient(player, "EquipResult", true, slotIndex, slot)
		print(`[SlotServer] {player.Name} equipou slot {slotIndex}: {slot.name}`)
	else
		SlotEvents:FireClient(player, "EquipResult", false, slotIndex, "Falha ao salvar.")
	end
end

-- ─────────────────────────────────────────
-- Enviar estado completo ao cliente
-- ─────────────────────────────────────────

local function sendStateToClient(player: Player)
	local slotCount    = getSlotCount(player)
	local slots        = getSlots(player)
	local equippedSlot = PlayerState.Get(player, "EquippedSlot") or 0
	SlotEvents:FireClient(player, "SlotsData", slotCount, slots, equippedSlot)
end

-- ─────────────────────────────────────────
-- Eventos do cliente
-- ─────────────────────────────────────────

SlotEvents.OnServerEvent:Connect(function(player: Player, action: string, ...)
	local args = { ... }

	if action == "EquipSlot" then
		local slotIndex = args[1]
		if type(slotIndex) ~= "number" then return end
		equipSlot(player, slotIndex)

	elseif action == "GetSlots" then
		sendStateToClient(player)
	end
end)

-- ─────────────────────────────────────────
-- PlayerAdded
-- ─────────────────────────────────────────

Players.PlayerAdded:Connect(function(player: Player)
	task.spawn(function()
		local attempts = 0
		repeat task.wait(0.1); attempts += 1
		until PlayerState.IsPlayerDataReady(player) or attempts >= 50

		if not PlayerState.IsPlayerDataReady(player) then
			warn(`[SlotServer] Timeout ao aguardar dados de {player.Name}`)
			return
		end

		-- Garante SlotCount inicial
		if not PlayerState.Get(player, "SlotCount") then
			PlayerState.Set(player, "SlotCount", DEFAULT_SLOTS)
		end

		-- ✅ Se o slot 1 está vazio mas o player já tem ActiveCharacter, popula ele
		local slots = getSlots(player)
		local activeChar = PlayerState.Get(player, "ActiveCharacter")
		
		local character = PlayerState.Get(player, 'ActiveCharacter')
		local charData = GetCharacterPoolData:Invoke(character)
		RegisterNewCharacterIndexEvent:Fire(player, {CharacterName = charData.name, CharacterDescription = charData.description, charData.Skills})

		if slots[1] == nil and activeChar and activeChar ~= "" then
			-- Acha os dados do personagem no CharacterRegistry
			local CharacterRegistry = require(ReplicatedStorage:WaitForChild("CharacterInfo"):WaitForChild("CharacterInfoModule"))
			local charData = nil
			for _, char in ipairs(CharacterRegistry) do
				if char.id == activeChar then
					charData = char
					break
				end
			end

			if charData then
				slots[1] = {
					id          = charData.id,
					name        = charData.name,
					rarity      = charData.rarity,
					description = charData.description,
					AnimId      = charData.AnimId,
				}
				saveSlots(player, slots)
				PlayerState.Set(player, "EquippedSlot", 1)
				print(`[SlotServer] {player.Name}: slot 1 populado com ActiveCharacter existente: {charData.name}`)
			end
		end

		sendStateToClient(player)
	end)
end)

function SlotServer.Init()
	print("[SlotServer] Initialized")
end

return SlotServer