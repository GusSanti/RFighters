--!strict
-- InviteRewardsServer.lua

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerState       = require(ReplicatedStorage.PlayerState.PlayerStateServer)

local InviteEvents: RemoteEvent   = ReplicatedStorage.Events:WaitForChild("InviteEvents")
local UnlockSkinEvent: BindableEvent = ReplicatedStorage.Events.Skins:WaitForChild("UnlockSkin")

local MAX_INVITES = 3

-- Recompensa por tier (exclusiva — só a do tier atingido)
local REWARDS: { [number]: (player: Player) -> () } = {
	[1] = function(player)
		PlayerState.Increment(player, "Rolls", 10)
		warn(string.format("[InviteRewards] %s — tier 1: +10 Rolls.", player.Name))
		InviteEvents:FireClient(player, "InviteReward", 1)
	end,
	[2] = function(player)
		PlayerState.Increment(player, "Crystals", 50)
		warn(string.format("[InviteRewards] %s — tier 2: +50 Crystals.", player.Name))
		InviteEvents:FireClient(player, "InviteReward", 2)
	end,
	[3] = function(player)
		UnlockSkinEvent:Fire(player, "TomTheTitanShark", "AlternateStyle")
		warn(string.format("[InviteRewards] %s — tier 3: skin TomTheTitanShark.", player.Name))
		InviteEvents:FireClient(player, "InviteReward", 3)
	end,
}

-- ─────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────

local function getInviteCount(player: Player): number
	return PlayerState.Get(player, "InviteCount") or 0
end

local function syncClient(player: Player)
	local count = getInviteCount(player)
	InviteEvents:FireClient(player, "SyncInvites", count, MAX_INVITES)
end

-- ─────────────────────────────────────────
-- Lógica principal
-- ─────────────────────────────────────────

local InviteRewardsServer = {}

function InviteRewardsServer.RegisterInvite(inviter: Player)
	if not inviter or not inviter.Parent then return end

	local current = getInviteCount(inviter)
	if current >= MAX_INVITES then return end

	local newCount = current + 1
	PlayerState.Set(inviter, "InviteCount", newCount)

	warn(string.format("[InviteRewards] %s convidou %d/%d.", inviter.Name, newCount, MAX_INVITES))
	InviteEvents:FireClient(inviter, "InviteAdded", newCount, MAX_INVITES)

	local reward = REWARDS[newCount]
	if reward then
		reward(inviter)
	end
end

-- ─────────────────────────────────────────
-- Detecta quem veio por convite
-- ─────────────────────────────────────────

local processedJoins: { [number]: boolean } = {}

Players.PlayerAdded:Connect(function(newPlayer: Player)
	task.wait(2)
	syncClient(newPlayer)

	if processedJoins[newPlayer.UserId] then return end

	local joinData           = newPlayer:GetJoinData()
	local referrerId: number = joinData.ReferredByPlayerId or 0

	if referrerId == 0 then return end
	if referrerId == newPlayer.UserId then return end

	processedJoins[newPlayer.UserId] = true

	local inviter = Players:GetPlayerByUserId(referrerId)
	if inviter then
		InviteRewardsServer.RegisterInvite(inviter)
	else
		local conn: RBXScriptConnection
		conn = Players.PlayerAdded:Connect(function(p: Player)
			if p.UserId == referrerId then
				conn:Disconnect()
				InviteRewardsServer.RegisterInvite(p)
			end
		end)
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
end)

-- ─────────────────────────────────────────
-- [DEV] /invite e /resetinvite no chat
-- ─────────────────────────────────────────

Players.PlayerAdded:Connect(function(player: Player)
	player.Chatted:Connect(function(msg: string)
		if msg:lower() == "/invite" then
			InviteRewardsServer.RegisterInvite(player)
		elseif msg:lower() == "/resetinvite" then
			PlayerState.Set(player, "InviteCount", 0)
			processedJoins = {}
			syncClient(player)
			warn("[InviteRewards] Resetado para", player.Name)
		end
	end)
end)

return InviteRewardsServer