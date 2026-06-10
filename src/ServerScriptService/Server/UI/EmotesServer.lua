-- EmoteService (Server)
-- Localização sugerida: ServerScriptService/Services/EmoteService.lua
--
-- Responsabilidades:
--   • Dar / tirar emotes do inventário persistido do player
--   • Equipar / desequipar slots do wheel (máx. 8)
--   • Responder ao cliente com o inventário completo
--
-- Depende de:
--   • PlayerState  (server-side) com suporte a Get / Set
--   • EmotesData   (ReplicatedStorage) — mesmo módulo usado pelo client
--   • RemoteEvents / RemoteFunctions em ReplicatedStorage.Remotes.Emotes

local EmoteService = {}

-- ── Serviços ──────────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Módulos ───────────────────────────────────────────────────────────────────
-- Ajuste o caminho conforme a estrutura do seu projeto
local PlayerState = require(game.ReplicatedStorage.PlayerState.PlayerStateServer)
local EmotesData  = require(ReplicatedStorage.UI.Systems.Emotes.EmotesData)

-- ── Constantes ────────────────────────────────────────────────────────────────
local MAX_EMOTE_SLOTS = 8

-- Chaves usadas no PlayerState (save)
local KEY_OWNED_EMOTES    = "OwnedEmotes"    -- { [emoteName] = true }
local KEY_EQUIPPED_EMOTES = "EquippedEmotes" -- { [1..8] = emoteName | "" }

-- ── Remotes ───────────────────────────────────────────────────────────────────
-- Crie uma pasta  ReplicatedStorage.Remotes.Emotes  com estes filhos,
-- ou adapte GetRemote() para a estrutura que você já usa.
local RemotesFolder -- resolvido em Init()

local REMOTE_GET_INVENTORY    = "GetEmoteInventory"   -- RemoteFunction  client→server
local REMOTE_EQUIP_SLOT       = "EquipEmoteSlot"      -- RemoteEvent     client→server
local REMOTE_UNEQUIP_SLOT     = "UnequipEmoteSlot"    -- RemoteEvent     client→server
local REMOTE_INVENTORY_UPDATE = "EmoteInventoryUpdate" -- RemoteEvent    server→client

-- ── Default data (cole isto no seu PlayerState default table) ─────────────────
--[[
    Adicione ao seu defaultData / template:

    [KEY_OWNED_EMOTES]    = {}   -- tabela vazia; emotes são concedidos pelo servidor
    [KEY_EQUIPPED_EMOTES] = {"","","","","","","",""}  -- 8 slots vazios

    Exemplo:
    local defaultData = {
        ...
        OwnedEmotes    = {},
        EquippedEmotes = {"","","","","","","",""},
        ...
    }
]]

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function GetOrCreate(parent, class, name)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(class)
		obj.Name   = name
		obj.Parent = parent
	end
	return obj
end

local function NormalizeEquipped(raw)
	local result = {}
	for i = 1, MAX_EMOTE_SLOTS do
		local v = (type(raw) == "table") and raw[i] or nil
		result[i] = (type(v) == "string" and v ~= "") and v or ""
	end
	return result
end

local function NormalizeOwned(raw)
	if type(raw) ~= "table" then return {} end
	local clean = {}
	for k, v in pairs(raw) do
		-- Formato dicionário: {TESTEMOTE = true}
		if type(k) == "string" and v == true then
			clean[k] = true
			-- Formato array: {"TESTEMOTE"}
		elseif type(k) == "number" and type(v) == "string" and v ~= "" then
			clean[v] = true
		end
	end
	return clean
end

local function IsValidEmote(emoteName)
	if type(emoteName) ~= "string" or emoteName == "" then return false end

	-- Nível raiz (ex: TESTEMOTE)
	if EmotesData.Emotes[emoteName] ~= nil then return true end

	-- Subcategorias (ex: ANIME.JOJO_POSE)
	for _, category in pairs(EmotesData.Emotes) do
		if type(category) == "table" and category[emoteName] ~= nil then
			return true
		end
	end

	return false
end

-- ── Acesso ao PlayerState ─────────────────────────────────────────────────────

local function GetOwned(player)
	return NormalizeOwned(PlayerState.Get(player, KEY_OWNED_EMOTES))
end

local function GetEquipped(player)
	return NormalizeEquipped(PlayerState.Get(player, KEY_EQUIPPED_EMOTES))
end

local function SetOwned(player, owned)
	-- Converte dicionário de volta para array ao salvar
	local arr = {}
	for name in pairs(owned) do
		table.insert(arr, name)
	end
	table.sort(arr)
	PlayerState.Set(player, KEY_OWNED_EMOTES, arr)
end

local function SetEquipped(player, equipped)
	PlayerState.Set(player, KEY_EQUIPPED_EMOTES, equipped)
end

-- ── Notificar client ──────────────────────────────────────────────────────────

local function PushInventoryToClient(player)
	local updateRemote = RemotesFolder and RemotesFolder:FindFirstChild(REMOTE_INVENTORY_UPDATE)
	if not updateRemote then return end

	local owned    = GetOwned(player)
	local equipped = GetEquipped(player)

	-- Envia lista ordenada de emotes possuídos para facilitar UI
	local ownedList = {}
	for name in pairs(owned) do
		table.insert(ownedList, name)
	end
	table.sort(ownedList)

	updateRemote:FireClient(player, {
		OwnedList = ownedList,           -- array de nomes para popular o menu de seleção
		Equipped  = equipped,            -- array [1..8] para o wheel
	})
end

-- ── API pública (uso server-side, ex.: sistemas de loja / quests) ─────────────

--- Concede um emote ao player. Retorna true se foi adicionado, false se já possuía.
function EmoteService.GiveEmote(player, emoteName)
	if not IsValidEmote(emoteName) then
		warn("[EmoteService] GiveEmote: emote inválido ->", emoteName)
		return false
	end

	local owned = GetOwned(player)
	if owned[emoteName] then
		return false  -- já possui
	end

	owned[emoteName] = true
	SetOwned(player, owned)
	PushInventoryToClient(player)
	return true
end

--- Remove um emote do inventário do player.
--- Também o remove de qualquer slot equipado.
function EmoteService.TakeEmote(player, emoteName)
	if type(emoteName) ~= "string" or emoteName == "" then return false end

	local owned    = GetOwned(player)
	local equipped = GetEquipped(player)

	if not owned[emoteName] then
		return false  -- não possui
	end

	owned[emoteName] = nil
	SetOwned(player, owned)

	-- Remove dos slots se estiver equipado
	local changed = false
	for i = 1, MAX_EMOTE_SLOTS do
		if equipped[i] == emoteName then
			equipped[i] = ""
			changed = true
		end
	end
	if changed then
		SetEquipped(player, equipped)
	end

	PushInventoryToClient(player)
	return true
end

--- Retorna se o player possui determinado emote.
function EmoteService.PlayerOwnsEmote(player, emoteName)
	local owned = GetOwned(player)
	return owned[emoteName] == true
end

--- Retorna a lista de emotes possuídos pelo player.
function EmoteService.GetOwnedEmotes(player)
	local owned = GetOwned(player)
	local list  = {}
	for name in pairs(owned) do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

-- ── Handlers de remotes (requests do client) ──────────────────────────────────

-- RemoteFunction: client pede inventário completo (chamado no carregamento da UI)
local function OnGetEmoteInventory(player)
	print("[EmoteService] OnGetEmoteInventory chamado para:", player.Name)
	local owned    = GetOwned(player)
	local equipped = GetEquipped(player)

	local ownedList = {}
	for name in pairs(owned) do
		table.insert(ownedList, name)
	end
	table.sort(ownedList)

	return {
		OwnedList = ownedList,
		Equipped  = equipped,
	}
end

-- RemoteEvent: client quer equipar um emote num slot
local function OnEquipEmoteSlot(player, slotIndex, emoteName)
	-- Validações de segurança
	if type(slotIndex) ~= "number"
		or slotIndex ~= math.floor(slotIndex)
		or slotIndex < 1
		or slotIndex > MAX_EMOTE_SLOTS then
		return
	end

	if type(emoteName) ~= "string" then return end

	-- Permite string vazia para limpar o slot
	if emoteName ~= "" then
		if not IsValidEmote(emoteName) then return end
		if not EmoteService.PlayerOwnsEmote(player, emoteName) then return end
	end

	local equipped = GetEquipped(player)

	-- Se o emote já está em outro slot, limpa o slot antigo (evita duplicata)
	if emoteName ~= "" then
		for i = 1, MAX_EMOTE_SLOTS do
			if equipped[i] == emoteName and i ~= slotIndex then
				equipped[i] = ""
			end
		end
	end

	equipped[slotIndex] = emoteName
	SetEquipped(player, equipped)

	-- Notifica o client com o estado atualizado
	PushInventoryToClient(player)
end

-- RemoteEvent: client quer remover emote de um slot
local function OnUnequipEmoteSlot(player, slotIndex)
	if type(slotIndex) ~= "number"
		or slotIndex ~= math.floor(slotIndex)
		or slotIndex < 1
		or slotIndex > MAX_EMOTE_SLOTS then
		return
	end

	local equipped = GetEquipped(player)
	equipped[slotIndex] = ""
	SetEquipped(player, equipped)
	PushInventoryToClient(player)
end

-- ── Init ──────────────────────────────────────────────────────────────────────

function EmoteService.ServerInit()
	local events = ReplicatedStorage:WaitForChild("Events")
	RemotesFolder = events:WaitForChild("Emotes")  -- só pega, não recria

	local getInvRemote = RemotesFolder:WaitForChild(REMOTE_GET_INVENTORY)
	getInvRemote.OnServerInvoke = OnGetEmoteInventory

	local equipRemote = RemotesFolder:WaitForChild(REMOTE_EQUIP_SLOT)
	equipRemote.OnServerEvent:Connect(OnEquipEmoteSlot)

	local unequipRemote = RemotesFolder:WaitForChild(REMOTE_UNEQUIP_SLOT)
	unequipRemote.OnServerEvent:Connect(OnUnequipEmoteSlot)

	Players.PlayerAdded:Connect(function(player)
		-- Aguarda o PlayerState sinalizar que os dados estão prontos
		-- ao invés de um wait fixo
		local loaded = false
		for i = 1, 10 do
			task.wait(0.5)
			local owned = PlayerState.Get(player, KEY_OWNED_EMOTES)
			if type(owned) == "table" then
				loaded = true
				break
			end
		end

		if loaded then
			PushInventoryToClient(player)
		end
	end)
end

return EmoteService