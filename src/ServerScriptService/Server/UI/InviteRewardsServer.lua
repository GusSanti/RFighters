--!strict
-- InviteRewardsServer.lua
-- Coloca em: ServerScript.Systems.InviteRewardsServer

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerState       = require(ReplicatedStorage.PlayerState.PlayerStateServer)

local InviteEvents: RemoteEvent = ReplicatedStorage.Events:WaitForChild("InviteEvents")

local MAX_INVITES  = 3
local REWARD_ROLLS = 50

-- ─────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────

local function getInviteCount(player: Player): number
	return PlayerState.Get(player, "InviteCount") or 0
end

local function hasClaimedReward(player: Player): boolean
	return PlayerState.Get(player, "InviteRewardClaimed") == true
end

local function syncClient(player: Player)
	local count   = getInviteCount(player)
	local claimed = hasClaimedReward(player)
	InviteEvents:FireClient(player, "SyncInvites", count, MAX_INVITES, claimed)
end

-- ─────────────────────────────────────────
-- Lógica principal
-- ─────────────────────────────────────────

local InviteRewardsServer = {}

function InviteRewardsServer.RegisterInvite(inviter: Player)
	if not inviter or not inviter.Parent then return end

	local current = getInviteCount(inviter)
	if current >= MAX_INVITES then return end
	if hasClaimedReward(inviter) then return end

	local newCount = current + 1
	PlayerState.Set(inviter, "InviteCount", newCount)

	warn(string.format("[InviteRewards] %s convidou %d/%d.", inviter.Name, newCount, MAX_INVITES))
	InviteEvents:FireClient(inviter, "InviteAdded", newCount, MAX_INVITES)

	if newCount >= MAX_INVITES then
		PlayerState.Set(inviter, "InviteRewardClaimed", true)
		PlayerState.Increment(inviter, "Rolls", REWARD_ROLLS)
		warn(string.format("[InviteRewards] %s completou! +%d Rolls.", inviter.Name, REWARD_ROLLS))
		InviteEvents:FireClient(inviter, "AllInvitesCompleted", REWARD_ROLLS)
	end
end

-- ─────────────────────────────────────────
-- Detecta quem veio por convite
-- ─────────────────────────────────────────

-- Evita contar o mesmo jogador duas vezes para o mesmo inviter
local processedJoins: { [number]: boolean } = {}  -- UserId de quem entrou

Players.PlayerAdded:Connect(function(newPlayer: Player)
	-- Sincroniza UI do próprio jogador que entrou
	task.wait(2)
	syncClient(newPlayer)

	-- Já processamos este jogador antes? (reconexão na mesma sessão)
	if processedJoins[newPlayer.UserId] then return end

	-- Roblox preenche ReferredByPlayerId quando o jogador
	-- aceitou um convite via SocialService:PromptGameInvite()
	local joinData       = newPlayer:GetJoinData()
	local referrerId: number = joinData.ReferredByPlayerId or 0

	if referrerId == 0 then return end                          -- não veio por convite
	if referrerId == newPlayer.UserId then return end           -- não pode convidar a si mesmo

	processedJoins[newPlayer.UserId] = true

	-- Procura o inviter na sessão atual
	local inviter = Players:GetPlayerByUserId(referrerId)
	if inviter then
		InviteRewardsServer.RegisterInvite(inviter)
	else
		-- Inviter não está online agora; incrementa assim que entrar
		-- (útil se o inviter reiniciar antes do convidado carregar)
		local conn: RBXScriptConnection
		conn = Players.PlayerAdded:Connect(function(p: Player)
			if p.UserId == referrerId then
				conn:Disconnect()
				InviteRewardsServer.RegisterInvite(p)
			end
		end)
		-- Limpa a conexão pendente se o convidado sair antes
		newPlayer.AncestryChanged:Connect(function()
			if not newPlayer.Parent then
				conn:Disconnect()
			end
		end)
	end
end)

-- ─────────────────────────────────────────
-- Eventos recebidos do client
-- ─────────────────────────────────────────

InviteEvents.OnServerEvent:Connect(function(player: Player, action: string)
	if action == "GetInviteData" then
		syncClient(player)
	end
	-- "InviteOpened" removido: não contamos mais o clique, só a entrada real
end)

-- ─────────────────────────────────────────
-- [DEV] /invite e /resetinvite no chat — remova em produção
-- ─────────────────────────────────────────

Players.PlayerAdded:Connect(function(player: Player)
	player.Chatted:Connect(function(msg: string)
		if msg:lower() == "/invite" then
			InviteRewardsServer.RegisterInvite(player)
		elseif msg:lower() == "/resetinvite" then
			PlayerState.Set(player, "InviteCount", 0)
			PlayerState.Set(player, "InviteRewardClaimed", false)
			processedJoins = {}     -- limpa cache de sessão também
			syncClient(player)
			warn("[InviteRewards] Resetado para", player.Name)
		end
	end)
end)

return InviteRewardsServer