-- =============================================================
-- Party.lua  (CLIENT)
-- Party = time no MatchModule. Party solo = sem time.
-- =============================================================

local Party = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
if not game:IsLoaded() then game.Loaded:Wait() end

local Effects = require(script.Parent.Parent.Effects)

-- Remotes
local PartyEvents = ReplicatedStorage.Events:WaitForChild("Party")
local PartyRemote = PartyEvents:WaitForChild("PartyRemoteEvent")
local PartyFunc   = PartyEvents:WaitForChild("PartyRemoteFunction")

-- UI
local playerGui = localPlayer:WaitForChild("PlayerGui")
local MainUI    = playerGui:WaitForChild("UI")
local PartyUI   = MainUI:WaitForChild("Party")

local OwnerSlot      = PartyUI:WaitForChild("Owner")
--local PlayerInParty1 = PartyUI:WaitForChild("PlayerInParty1")
--local PlayerInParty2 = PartyUI:WaitForChild("PlayerInParty2")
--local PlayerInParty3 = PartyUI:WaitForChild("PlayerInParty3")
--local PlayerInParty4 = PartyUI:WaitForChild("PlayerInParty4")
local LobbyFrame       = PartyUI:WaitForChild("Lobby")

--local MemberSlots = { PlayerInParty1, PlayerInParty2, PlayerInParty3, PlayerInParty4 }
local MemberSlots = {}

local BUTTON_COOLDOWN     = 2
local partyActionLastUsed = 0

---------------------------------------------------------------------
-- Thumbnail assíncrono
---------------------------------------------------------------------
local function applyThumbnailAsync(imgLabel: ImageLabel, userId: number)
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size420x420
			)
		end)
		if ok and url and imgLabel and imgLabel.Parent then
			imgLabel.Image = url
		end
	end)
end

local function applyPlatformIcon(card: Frame, platformName: string?)
	local avatarContainer = card:FindFirstChildWhichIsA("ImageLabel")
	if not avatarContainer then return end
	for _, name in ipairs({ "Mobile", "Console", "PC" }) do
		local icon = avatarContainer:FindFirstChild(name)
		if icon then icon.Visible = (platformName == name) end
	end
end

---------------------------------------------------------------------
-- Slot helpers
---------------------------------------------------------------------
local function getSlotPlayerImage(slot: Frame): ImageLabel?
	local container = slot:FindFirstChild("SlotPlayerImage")
	if not container then return nil end
	return container:FindFirstChild("PlayerImage") :: ImageLabel
end

local function getCardPlayerImage(card: Frame): ImageLabel?
	local container = card:FindFirstChildWhichIsA("ImageLabel")
	if not container then return nil end
	return container:FindFirstChild("PlayerImage") :: ImageLabel
end

local function clearSlot(slot: Frame)
	local img = getSlotPlayerImage(slot)
	if img then img.Image = "" end
	local n = slot:FindFirstChild("RealPlayerName")
	local d = slot:FindFirstChild("displayname")
	if n then n.Text = "" end
	if d then d.Text = "" end
end

local function fillSlotFromData(slot: Frame, data)
	local img = getSlotPlayerImage(slot)
	if img then applyThumbnailAsync(img, data.UserId) end
	local n = slot:FindFirstChild("RealPlayerName")
	local d = slot:FindFirstChild("displayname")
	if n then n.Text = data.DisplayName or "" end
	if d then d.Text = "@" .. (data.Name or "") end
end

local function FillOwnerSlotLocally()
	fillSlotFromData(OwnerSlot, {
		UserId      = localPlayer.UserId,
		DisplayName = localPlayer.DisplayName,
		Name        = localPlayer.Name,
	})
end

---------------------------------------------------------------------
-- Atualiza slots com payload de UpdateParty
---------------------------------------------------------------------
local function UpdatePartyUI(payload)
	if not payload or not payload.Members then
		FillOwnerSlotLocally()
		for _, slot in ipairs(MemberSlots) do clearSlot(slot) end
		return
	end

	local ownerData = nil
	local members   = {}
	for _, d in ipairs(payload.Members) do
		if d.IsOwner then ownerData = d
		else table.insert(members, d) end
	end

	if ownerData then fillSlotFromData(OwnerSlot, ownerData)
	else FillOwnerSlotLocally() end

	for i, slot in ipairs(MemberSlots) do
		if members[i] then fillSlotFromData(slot, members[i])
		else clearSlot(slot) end
	end
end

---------------------------------------------------------------------
-- LOBBY
---------------------------------------------------------------------
local PlayerTemplate = LobbyFrame:FindFirstChild("PlayerTemplate")
if PlayerTemplate then PlayerTemplate.Visible = false end

local EmptyLabel = LobbyFrame:FindFirstChild("EmptyLabel")
if not EmptyLabel then
	EmptyLabel                        = Instance.new("TextLabel")
	EmptyLabel.Name                   = "EmptyLabel"
	EmptyLabel.Size                   = UDim2.new(1, 0, 0, 40)
	EmptyLabel.BackgroundTransparency = 1
	EmptyLabel.Text                   = "No players avaliable right now"
	EmptyLabel.TextColor3             = Color3.fromRGB(180, 180, 180)
	EmptyLabel.Font                   = Enum.Font.GothamMedium
	EmptyLabel.TextSize               = 14
	EmptyLabel.Parent                 = LobbyFrame
end

local function updateEmptyState()
	local hasCards = false
	for _, item in ipairs(LobbyFrame:GetChildren()) do
		if item:IsA("ImageLabel") and item.Name ~= "PlayerTemplate" then
			hasCards = true; break
		end
	end
	EmptyLabel.Visible = not hasCards
end

local function buildLobbyCard(playerData)
	print('BUILDING LOBBY CARD')
	if not PlayerTemplate then return end
	if playerData.Name == localPlayer.Name then return end
	if LobbyFrame:FindFirstChild(playerData.Name) then return end

	local card = PlayerTemplate:Clone()
	card.Name    = playerData.Name
	card.Visible = true
	card.Parent  = LobbyFrame

	local nameLabel    = card:FindFirstChild("PlayerName")
	local displayLabel = card:FindFirstChild("displayname")
	if nameLabel    then nameLabel.Text    = playerData.DisplayName end
	if displayLabel then displayLabel.Text = "@" .. playerData.Name end

	local img = getCardPlayerImage(card)
	if img then applyThumbnailAsync(img, playerData.UserId) end

	applyPlatformIcon(card, playerData.Platform)
	updateEmptyState()
end

local function removeLobbyCard(playerName: string)
	local card = LobbyFrame:FindFirstChild(playerName)
	if card then card:Destroy() end
	updateEmptyState()
end

local function RefreshLobbyUI()
	for _, item in ipairs(LobbyFrame:GetChildren()) do
		if item:IsA("ImageLabel") and item.Name ~= "PlayerTemplate" then
			item:Destroy()
		end
	end
	if PlayerTemplate then PlayerTemplate.Visible = false end
	updateEmptyState()
	PartyRemote:FireServer("RequestLobbyList", {})
end

---------------------------------------------------------------------
-- API pública — chamada pelo NotificationClient ao aceitar/recusar convite
---------------------------------------------------------------------
function Party.AcceptPartyInvite(fromName: string)
	PartyRemote:FireServer("AcceptInvite", { OwnerName = fromName })
end

function Party.DeclinePartyInvite(fromName: string)
	PartyRemote:FireServer("DeclineInvite", { OwnerName = fromName })
end

---------------------------------------------------------------------
-- ButtonAction
---------------------------------------------------------------------
function Party.ButtonAction(button: GuiButton, action: string)

	if action == "OpenParty" then
		local now = tick()
		if now - partyActionLastUsed < BUTTON_COOLDOWN then return end
		partyActionLastUsed = now
		-- Abre a UI e pede ao servidor para atualizar o slot do owner
		PartyRemote:FireServer("CreateParty", {})
		if not PartyUI.Visible then Effects.ToggleUI(PartyUI) end
		RefreshLobbyUI()

	elseif action == "CloseParty" then
		if PartyUI.Visible then Effects.ToggleUI(PartyUI) end

	elseif action == "LeaveParty" then
		PartyRemote:FireServer("LeaveParty", {})
		if PartyUI.Visible then Effects.ToggleUI(PartyUI) end

	elseif action == "InvitePlayer" then
		local targetName = button.Parent and button.Parent.Name
		if not targetName then return end
		local now = tick()
		if now - partyActionLastUsed < BUTTON_COOLDOWN then return end
		partyActionLastUsed = now
		PartyRemote:FireServer("InvitePlayer", { TargetName = targetName })

	elseif action == "KickMember" then
		local targetName = button.Parent and button.Parent.Name
		if not targetName then return end
		PartyRemote:FireServer("KickMember", { TargetName = targetName })
		
	elseif action == 'QueueUp' then
		PartyRemote:FireServer("QueueUp", {})

	elseif action == "RefreshLobby" or action == "RefreshPartyLobby" then
		RefreshLobbyUI()
	end
end

---------------------------------------------------------------------
-- Eventos do servidor → cliente
---------------------------------------------------------------------
PartyRemote.OnClientEvent:Connect(function(action: string, args)
	args = args or {}

	if action == "UpdateParty" then
		UpdatePartyUI(args)

	elseif action == "UpdateLobbyList" then
		print('update lobby list')
		print(args.Players)
		for _, item in ipairs(LobbyFrame:GetChildren()) do
			if item:IsA("ImageLabel") and item.Name ~= "PlayerTemplate" then
				item:Destroy()
			end
		end
		if PlayerTemplate then PlayerTemplate.Visible = false end
		
		local players = args.Players
		if players and #players > 0 then
			for _, playerData in ipairs(players) do
				buildLobbyCard(playerData)
			end
		end
		updateEmptyState()

	elseif action == "LobbyPlayerAdded" then
		print('lobby player added')
		buildLobbyCard(args)

	elseif action == "LobbyPlayerRemoved" then
		removeLobbyCard(args.Name)

	elseif action == "PartyDissolved" then
		if PartyUI.Visible then Effects.ToggleUI(PartyUI) end
		for _, slot in ipairs(MemberSlots) do clearSlot(slot) end
		clearSlot(OwnerSlot)

	elseif action == "InviteDeclined" then
		warn("[Party] Convite recusado por:", args.Name)

	elseif action == "Error" then
		warn("[Party] Erro:", args.Message)
	end
end)

---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------
function Party.Init()
	if PlayerTemplate then PlayerTemplate.Visible = false end
	FillOwnerSlotLocally()
	for _, slot in ipairs(MemberSlots) do clearSlot(slot) end

	task.spawn(function()
		local partyData = PartyFunc:InvokeServer("GetMyParty", {})
		if partyData then UpdatePartyUI(partyData) end
	end)

	PartyRemote:FireServer("RequestLobbyList", {})
	warn("[Party] Módulo de Party inicializado.")
end

return Party