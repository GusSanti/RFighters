local NotificationRemoteFunction = game.ReplicatedStorage.Events.Notification.NotificationRemoteFunctions
local NotificationRemoteEvent    = game.ReplicatedStorage.Events.Notification.NotificationRemoteEvents

local Players = game:GetService("Players")

-- Referência ao módulo Party para aceitar/recusar convites
-- Carregado lazy para evitar dependência circular na inicialização
local PartyRemote = game.ReplicatedStorage.Events:WaitForChild("Party"):WaitForChild("PartyRemoteEvent")

local playerGui                    = Players.LocalPlayer:WaitForChild("PlayerGui")
local MainUI                       = playerGui:WaitForChild("UI")
local NotificationUI               = MainUI:WaitForChild("Notification")
local NotificationScrollingFrame   = NotificationUI:WaitForChild("ScrollingFrame")
local NotificationTeamTemplate     = NotificationScrollingFrame:WaitForChild("Invite2v2Template")
local NotificationFightTemplate    = NotificationScrollingFrame:WaitForChild("InviteFightTemplate")
local NotificationMessageTemplate  = NotificationScrollingFrame:WaitForChild("MessageTemplate")
local Notification2v2FightTemplate = NotificationScrollingFrame:FindFirstChild("Invite2v2FightTemplate")

-- Template dedicado de convite de party.
-- Se não existir, reutiliza o FightTemplate (mesmos campos: PlayerHead, PlayerName, Accept, Close).
local NotificationPartyTemplate = NotificationScrollingFrame:FindFirstChild("PartyInviteTemplate")
	or NotificationTeamTemplate

NotificationUI.Visible = false

-- Rastreia notificações ativas para evitar duplicatas
local activeNotifications = {}

local function getKey(action, identifier)
	return action .. "|" .. tostring(identifier)
end

local function registerNotification(key)
	activeNotifications[key] = true
end

local function unregisterNotification(key)
	activeNotifications[key] = nil
end

local function isDuplicate(key)
	return activeNotifications[key] == true
end

-- ================================================================
-- Clone helpers
-- ================================================================

local function getUserThumbnail(playerName: string): string
	local ok, content = pcall(function()
		local userId = Players:GetUserIdFromNameAsync(playerName)
		local url, _ = Players:GetUserThumbnailAsync(
			userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size420x420
		)
		return url
	end)
	return ok and content or ""
end

local function cloneTeamNotificationTemplate(PlayerName)
	NotificationUI.Visible = true
	local newTemplate = NotificationTeamTemplate:Clone()
	newTemplate.Parent = NotificationScrollingFrame
	newTemplate:FindFirstChild("PlayerHead").Image = getUserThumbnail(PlayerName)
	newTemplate.PlayerName.Text = PlayerName
	newTemplate.Visible = true
	return newTemplate
end

local function cloneFightNotificationTemplate(PlayerName)
	NotificationUI.Visible = true
	local newTemplate = NotificationFightTemplate:Clone()
	newTemplate.Parent = NotificationScrollingFrame
	newTemplate:FindFirstChild("PlayerHead").Image = getUserThumbnail(PlayerName)
	newTemplate.PlayerName.Text = PlayerName
	newTemplate.Visible = true
	return newTemplate
end

local function clone2v2FightNotificationTemplate(Player1, Player2)
	NotificationUI.Visible = true
	local newTemplate = Notification2v2FightTemplate:Clone()
	newTemplate.Parent = NotificationScrollingFrame
	newTemplate.Player1Name.Text = Player1.Name
	newTemplate.Player2Name.Text = Player2.Name
	newTemplate.Visible = true
	return newTemplate
end

local function cloneMessageNotificationTemplate(message)
	local newTemplate = NotificationMessageTemplate:Clone()
	newTemplate.Parent = NotificationScrollingFrame
	newTemplate.Label.Text = message
	newTemplate.Visible = true
	return newTemplate
end

-- Clone do card de convite de party.
-- Reaproveita o mesmo layout do FightTemplate (PlayerHead, PlayerName, Accept, Close).
local function clonePartyInviteTemplate(fromName: string)
	print('clonning invite template')
	NotificationUI.Visible = true
	local newTemplate = NotificationPartyTemplate:Clone()
	newTemplate.Parent = NotificationScrollingFrame

	local head = newTemplate:FindFirstChild("PlayerHead")
	if head then head.Image = getUserThumbnail(fromName) end

	local nameLabel = newTemplate:FindFirstChild("PlayerName")
	if nameLabel then nameLabel.Text = fromName end

	-- Rótulo opcional de contexto ("Party Invite") se o template tiver um campo Title
	local titleLabel = newTemplate:FindFirstChild("Title") or newTemplate:FindFirstChild("InviteTitle")
	if titleLabel then titleLabel.Text = "Party Invite" end

	newTemplate.Visible = true
	return newTemplate
end

-- ================================================================
-- UI helpers
-- ================================================================

local function checkAndHideUI()
	for _, child in ipairs(NotificationScrollingFrame:GetChildren()) do
		if (child:IsA("Frame") or child:IsA("ImageLabel")) and child.Visible then
			return
		end
	end
	NotificationUI.Visible = false
end

-- ================================================================
-- Handler de eventos
-- ================================================================

NotificationRemoteEvent.onClientEvent:Connect(function(action, args)
	print("[NotificationClient] Evento:", action)

	-- ----------------------------------------------------------------
	-- INVITE DE TEAM (formar time 2v2)
	-- ----------------------------------------------------------------
	if action == "InviteTeamNotification" then
		local key = getKey(action, args.PlayerName)
		if isDuplicate(key) then return end
		registerNotification(key)

		local notif = cloneTeamNotificationTemplate(args.PlayerName)
		local acceptConn, closeConn

		game.ReplicatedStorage.UISoundEffects.Notification:Play()

		acceptConn = notif.Accept.MouseButton1Click:Connect(function()
			NotificationRemoteEvent:FireServer("AcceptInviteTeam", { PlayerName = args.PlayerName })
			game.ReplicatedStorage.UISoundEffects.Confirm:Play()
			unregisterNotification(key)
			acceptConn:Disconnect()
			notif:Destroy()
		end)

		local function delete()
			unregisterNotification(key)
			if notif then
				notif:Destroy()
				NotificationRemoteEvent:FireServer("InviteFightTimeout", { PlayerName = args.PlayerName })
			end
			if acceptConn then acceptConn:Disconnect() end
			if closeConn  then closeConn:Disconnect()  end
			checkAndHideUI()
		end

		closeConn = notif.Close.MouseButton1Click:Connect(delete)
		task.delay(30, delete)
	end

	-- ----------------------------------------------------------------
	-- FIGHT INVITE (1v1)
	-- ----------------------------------------------------------------
	if action == "FightInviteNotification" then
		local key = getKey(action, args.PlayerName)
		if isDuplicate(key) then return end
		registerNotification(key)

		local notif = cloneFightNotificationTemplate(args.PlayerName)
		local acceptConn, closeConn

		game.ReplicatedStorage.UISoundEffects.Notification:Play()

		acceptConn = notif.Accept.MouseButton1Click:Connect(function()
			NotificationRemoteEvent:FireServer("AcceptInviteFight", { PlayerName = args.PlayerName })
			game.ReplicatedStorage.UISoundEffects.Confirm:Play()
			unregisterNotification(key)
			acceptConn:Disconnect()
			notif:Destroy()
		end)

		local function delete()
			unregisterNotification(key)
			if notif then
				notif:Destroy()
				NotificationRemoteEvent:FireServer("InviteFightTimeout", { PlayerName = args.PlayerName })
			end
			if acceptConn then acceptConn:Disconnect() end
			if closeConn  then closeConn:Disconnect()  end
			checkAndHideUI()
		end

		closeConn = notif.Close.MouseButton1Click:Connect(delete)
		task.delay(30, delete)
	end

	-- ----------------------------------------------------------------
	-- TEAM FIGHT INVITE (2v2)
	-- ----------------------------------------------------------------
	if action == "FightTeamInviteNotification" then
		local teamKey = args.SendTeam.Player1.Name .. "+" .. args.SendTeam.Player2.Name
		local key = getKey(action, teamKey)
		if isDuplicate(key) then return end
		registerNotification(key)

		local notif = clone2v2FightNotificationTemplate(args.SendTeam.Player1, args.SendTeam.Player2)
		local acceptConn, closeConn

		game.ReplicatedStorage.UISoundEffects.Notification:Play()

		acceptConn = notif.Fight.MouseButton1Click:Connect(function()
			NotificationRemoteEvent:FireServer("AcceptTeamInviteFight", { Team = args.SendTeam })
			game.ReplicatedStorage.UISoundEffects.Confirm:Play()
			unregisterNotification(key)
			acceptConn:Disconnect()
			notif:Destroy()
		end)

		local function delete()
			unregisterNotification(key)
			if notif then
				notif:Destroy()
				NotificationRemoteEvent:FireServer("TeamInviteFightTimeout", { Team = args.SendTeam })
			end
			if acceptConn then acceptConn:Disconnect() end
			if closeConn  then closeConn:Disconnect()  end
			checkAndHideUI()
		end

		closeConn = notif.Close.MouseButton1Click:Connect(delete)
		task.delay(30, delete)
	end

	-- ----------------------------------------------------------------
	-- MENSAGEM SIMPLES
	-- ----------------------------------------------------------------
	if action == "SendMessage" then
		local message = args
		local key = getKey(action, message)
		if isDuplicate(key) then return end
		registerNotification(key)

		local notif = cloneMessageNotificationTemplate(message)
		local closeConn

		game.ReplicatedStorage.UISoundEffects.Notification:Play()

		local function delete()
			unregisterNotification(key)
			if notif then notif:Destroy() end
			if closeConn then closeConn:Disconnect() end
			checkAndHideUI()
		end

		closeConn = notif.Close.MouseButton1Click:Connect(delete)
		task.delay(15, delete)
	end

	-- ----------------------------------------------------------------
	-- PARTY INVITE NOTIFICATION
	-- Disparado diretamente pelo PartyServer via NotificationRemoteEvent:FireClient.
	-- Botão Accept → PartyRemote:FireServer("AcceptInvite")
	-- Botão Decline/Close → PartyRemote:FireServer("DeclineInvite")
	-- ----------------------------------------------------------------
	if action == "PartyInviteNotification" then
		local fromName = args.FromName
		local key = getKey(action, fromName)
		if isDuplicate(key) then return end
		registerNotification(key)

		warn("[NotificationClient] Party invite de:", fromName)

		local notif = clonePartyInviteTemplate(fromName)
		local acceptConn, declineConn

		game.ReplicatedStorage.UISoundEffects.Notification:Play()

		local function delete(declined: boolean)
			unregisterNotification(key)
			if notif then notif:Destroy() end
			if acceptConn  then acceptConn:Disconnect()  end
			if declineConn then declineConn:Disconnect() end
			if declined then
				PartyRemote:FireServer("DeclineInvite", { OwnerName = fromName })
			end
			checkAndHideUI()
		end

		acceptConn = notif.Accept.MouseButton1Click:Connect(function()
			game.ReplicatedStorage.UISoundEffects.Confirm:Play()
			PartyRemote:FireServer("AcceptInvite", { OwnerName = fromName })
			unregisterNotification(key)
			if notif        then notif:Destroy()           end
			if acceptConn   then acceptConn:Disconnect()   end
			if declineConn  then declineConn:Disconnect()  end
			checkAndHideUI()
		end)

		-- Botão "Decline" ou "Close" — aceita qualquer um dos dois nomes
		local declineBtn = notif:FindFirstChild("Decline") or notif:FindFirstChild("Close")
		if declineBtn then
			declineConn = declineBtn.MouseButton1Click:Connect(function()
				delete(true)
			end)
		end

		-- Timeout de 30 s: expira sem enviar DeclineInvite (convite simplesmente some)
		task.delay(30, function()
			if activeNotifications[key] then
				delete(false)
			end
		end)
	end
end)