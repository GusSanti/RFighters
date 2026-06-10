local module = {}

--[[
	Listener — MatchFound
	---------------------
	• Recebe o broadcast "MatchFound" de qualquer servidor.
	• SÓ teleporta players que estejam NESTE servidor E que estavam
	  explicitamente na fila (PlayersInQueue).
	• Se ninguém daqui faz parte da partida, ignora silenciosamente.
--]]

local MessagingService = game:GetService("MessagingService")
local TeleportService  = game:GetService("TeleportService")
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")

local PLACE_ID = 91510030565074  -- ⚠️ seu PlaceId

-- Importa o módulo de matchmaking para acessar PlayersInQueue
-- Ajuste o caminho conforme onde está o MatchmakingModule no seu jogo
local MatchmakingModule = require(game.ReplicatedStorage.MatchSystem.MatchmakingModule)
local PlayersInQueue    = MatchmakingModule.PlayersInQueue

MessagingService:SubscribeAsync("MatchFound", function(message)
	local ok, data = pcall(function()
		return HttpService:JSONDecode(message.Data)
	end)

	if not ok or not data then
		warn("[Listener] Falha ao decodificar mensagem MatchFound")
		return
	end

	local allTeams   = { data.teamA, data.teamB }
	local toTeleport = {}

	for _, team in ipairs(allTeams) do
		for _, member in ipairs(team.members) do

			-- ✅ GUARDA DUPLA:
			-- 1. O player existe neste servidor?
			-- 2. Ele estava na fila (pediu uma partida global)?
			local player = Players:GetPlayerByUserId(member.userId)
			if player and PlayersInQueue[member.userId] then
				table.insert(toTeleport, player)
				PlayersInQueue[member.userId] = nil  -- remove da fila local
				-- Limpa atributos
				player:SetAttribute("TeamId",   nil)
				player:SetAttribute("TeamSize", nil)
			end
		end
	end

	-- Ninguém deste servidor faz parte dessa partida → ignora
	if #toTeleport == 0 then return end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = data.reservedCode
	options:SetTeleportData({
		reservedCode = data.reservedCode,
		teamSize     = data.teamSize,
		teamA        = data.teamA,
		teamB        = data.teamB,
	})

	local teleOk, teleErr = pcall(function()
		TeleportService:TeleportAsync(PLACE_ID, toTeleport, options)
	end)

	if not teleOk then
		warn("[Listener] Erro ao teleportar:", teleErr)
	else
		print(("[Listener] %d player(s) teleportados para partida %s"):format(
			#toTeleport, data.teamA.teamId:sub(1,8)))
	end
end)

return module
