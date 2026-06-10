local module = {}

local Players           = game:GetService("Players")
local PlayerState       = require(game.ReplicatedStorage.PlayerState.PlayerStateServer)

-- ── Lista de admins (coloque os UserId dos admins aqui) ───────────────────────
local ADMIN_USER_IDS: {number} = {
	10452837434,  -- kaos9
	10375114330 -- kaos7
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function IsAdmin(player: Player): boolean
	for _, id in ipairs(ADMIN_USER_IDS) do
		if player.UserId == id then
			return true
		end
	end
	return false
end

local function FindPlayerByName(name: string): Player?
	-- Busca exata primeiro
	local exact = Players:FindFirstChild(name)
	if exact then return exact :: Player end

	-- Busca parcial (case-insensitive)
	local lower = name:lower()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name:lower():find(lower, 1, true) then
			return player
		end
	end

	return nil
end

local function Notify(player: Player, message: string)
	-- Devolve feedback pelo chat do servidor para o admin
	-- (não há API nativa para mandar mensagem privada no server-side,
	--  então usamos um RemoteEvent se disponível, ou apenas warn/print)
	warn(string.format("[AdminCommands] (%s) %s", player.Name, message))

	-- Se você tiver um sistema de notificação no client, dispare aqui.
	-- Exemplo com um RemoteEvent genérico:
	-- local notify = game.ReplicatedStorage:FindFirstChild("AdminNotify")
	-- if notify then notify:FireClient(player, message) end
end

-- ── Comando: /resetdata <username> ────────────────────────────────────────────

local function HandleResetData(admin: Player, targetName: string)
	if targetName == "" then
		Notify(admin, "Uso correto: /resetdata <username>")
		return
	end

	local target = FindPlayerByName(targetName)

	if not target then
		-- Tenta wipe offline pelo nome (requer UserId — não disponível offline por nome)
		-- Retorna erro amigável
		Notify(admin, string.format("Player '%s' não encontrado online. Para resetar offline, use o UserId.", targetName))
		return
	end

	if not PlayerState.IsPlayerDataReady(target) then
		Notify(admin, string.format("Os dados de '%s' ainda não carregaram. Aguarde.", target.Name))
		return
	end

	local success = PlayerState.WipePlayerData(target)

	if success then
		Notify(admin, string.format("✔ Dados de '%s' resetados com sucesso.", target.Name))
		print(string.format("[AdminCommands] %s resetou os dados de %s (UserId: %d)",
			admin.Name, target.Name, target.UserId))
	else
		Notify(admin, string.format("✘ Falha ao resetar dados de '%s'. Verifique os logs.", target.Name))
	end
end

-- Versão offline: /resetdatauid <userId>
local function HandleResetDataUid(admin: Player, userIdStr: string)
	local userId = tonumber(userIdStr)
	if not userId then
		Notify(admin, "Uso correto: /resetdatauid <userId>  (apenas números)")
		return
	end

	-- Verifica se está online primeiro
	local onlineTarget = Players:GetPlayerByUserId(userId)
	if onlineTarget then
		-- Redireciona para o wipe online (mais seguro)
		HandleResetData(admin, onlineTarget.Name)
		return
	end

	-- Player offline
	local success = PlayerState.WipeOfflinePlayerData(userId)
	if success then
		Notify(admin, string.format("✔ Dados offline do UserId %d resetados com sucesso.", userId))
		print(string.format("[AdminCommands] %s resetou dados offline do UserId %d", admin.Name, userId))
	else
		Notify(admin, string.format("✘ Falha ao resetar dados offline do UserId %d.", userId))
	end
end

-- ── Roteador de comandos ──────────────────────────────────────────────────────

local COMMANDS: {[string]: (admin: Player, args: string) -> ()} = {
	["/resetdata"]    = HandleResetData,
	["/resetdatauid"] = HandleResetDataUid,
}

local function OnPlayerChatted(player: Player, message: string)
	if not IsAdmin(player) then return end

	-- Normaliza: minúsculas, sem espaços extras
	local trimmed = message:match("^%s*(.-)%s*$")
	local lower   = trimmed:lower()

	for prefix, handler in pairs(COMMANDS) do
		if lower:sub(1, #prefix) == prefix then
			-- Extrai argumentos (tudo após o comando + espaço)
			local args = trimmed:sub(#prefix + 1):match("^%s*(.-)%s*$") or ""
			handler(player, args)
			return
		end
	end
end

-- ── Conecta o evento de chat para cada player ─────────────────────────────────

Players.PlayerAdded:Connect(function(player: Player)
	player.Chatted:Connect(function(message: string)
		OnPlayerChatted(player, message)
	end)
end)

-- Conecta para players já presentes (caso o script carregue depois)
for _, player in ipairs(Players:GetPlayers()) do
	player.Chatted:Connect(function(message: string)
		OnPlayerChatted(player, message)
	end)
end

print("[AdminCommands] Carregado. Comandos disponíveis: /resetdata, /resetdatauid")

return module
