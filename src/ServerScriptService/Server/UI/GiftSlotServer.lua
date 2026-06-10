local module = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerState = require(ReplicatedStorage.PlayerState.PlayerStateServer)

local GiftRemoteFunction: RemoteFunction = ReplicatedStorage.Events:WaitForChild("GiftSlotRemoteFunction")
local GiftPurchaseEvent:  RemoteEvent   = ReplicatedStorage.Events:WaitForChild("GiftSlotPurchaseEvent")

-- pendingGifts fica aqui, mas o ProcessReceipt é da loja
local pendingGifts: { [number]: string } = {}

function module.SetPending(userId: number, targetName: string)
	pendingGifts[userId] = targetName
end

function module.GetPending(userId: number): string?
	return pendingGifts[userId]
end

function module.ClearPending(userId: number)
	pendingGifts[userId] = nil
end

GiftRemoteFunction.OnServerInvoke = function(player: Player, action: string, targetName: string)
	if action == "ValidateTarget" then
		if not targetName or targetName == "" then
			return false, "Nome inválido."
		end

		local targetPlayer = Players:FindFirstChild(targetName)
		if not targetPlayer then
			return false, `Jogador "{targetName}" não está online.`
		end

		if targetPlayer == player then
			return false, "Você não pode dar um gift para si mesmo."
		end

		if not PlayerState.IsPlayerDataReady(targetPlayer :: Player) then
			return false, "Dados do jogador ainda carregando."
		end

		-- Registra o pending aqui
		pendingGifts[player.UserId] = targetName
		print(`[GiftServer] {player.Name} quer giftar para {targetName}`)
		return true, "ok"
	end

	return false, "Ação inválida."
end

GiftPurchaseEvent.OnServerEvent:Connect(function(buyer: Player, action: string)
	if action == "CancelGift" then
		pendingGifts[buyer.UserId] = nil
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	pendingGifts[player.UserId] = nil
end)

function module.Init()
	print("[GiftServer] Initialized")
end

return module