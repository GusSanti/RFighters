local LocalQueue = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Local Player
local localPlayer = Players.LocalPlayer
if not game:IsLoaded() then game.Loaded:Wait() end

-- Módulos externos
local Effects            = require(script.Parent.Parent.Effects)
local MatchModule        = require(ReplicatedStorage.MatchSystem.MatchModule)
local NotificationModule = require(ReplicatedStorage.Modules.NotificationModule)
local CameraModule = require(game.ReplicatedStorage.Modules.CameraModule)

-- Módulos filhos
local ZoneController     = require(script.ZoneController)
local FightingHUD        = require(script.FightingHUD)
local MapSelectionModule = require(script.MapSelectionUI)
local ScreenTransition   = require(script.ScreenTransition)

-- Workspace Elements
local AchivementsZonePart = workspace:WaitForChild("Zones"):WaitForChild("Achievements")
local PartyZonePart       = workspace:WaitForChild("Zones"):WaitForChild("Party")
local DailyZonePart       = workspace:WaitForChild("Zones"):WaitForChild("Daily")
local ShopZonePart        = workspace:WaitForChild("Zones"):WaitForChild("Shop")
local IndexZonePart       = workspace:WaitForChild("Zones"):WaitForChild("Index")
local AFKChamberZonePart  = workspace:WaitForChild("Zones"):WaitForChild("AFKChamber")

-- UI Elements
local playerGui            = localPlayer:WaitForChild("PlayerGui")
local MainUI               = playerGui:WaitForChild("UI")
local HUD                  = MainUI:WaitForChild("HUD")
local WinnerScreen         = MainUI:WaitForChild("WinnerScreen")
local LocalQueue1v1UI      = MainUI:WaitForChild("LocalQueue1v1")
local LocalQueue2v2UI      = MainUI:WaitForChild("LocalQueue2v2")
local ChooseTeamateUI      = MainUI:WaitForChild("ChooseTeamateLocal")
local SelectModeUI         = MainUI:WaitForChild("SelectModeLocal")
local CharacterSelectionUI = MainUI:WaitForChild("CharacterSelection")
local FightingFrame        = MainUI:WaitForChild("FightingFrame")
local TeamToggleFrame      = MainUI:WaitForChild("TeamToggleFrame")
local MapSelectionUI       = MainUI:WaitForChild("MapSelection")
local ReturnToLobby        = MainUI:WaitForChild("ReturnToLobby")
local Party                = MainUI:WaitForChild("Party")
local Daily                = MainUI:WaitForChild("DailyRewards")
local Achievements         = MainUI:WaitForChild("Achievements")
local AFKChamber           = MainUI:WaitForChild("AFKChamber")
local Shop                 = MainUI:WaitForChild("Shop")
local Index                = MainUI:WaitForChild("CharacterIndex")

local AbilitiesFrame = FightingFrame:WaitForChild("Abilities")
local ReadyButton    = CharacterSelectionUI:WaitForChild("Main"):WaitForChild("ReadyButton")
local NotReadyButton = CharacterSelectionUI:WaitForChild("Main"):WaitForChild("NotReadyButton")
local Blackout       = playerGui:WaitForChild("CoverScreen"):WaitForChild("Black")

-- WinnerScreen sub-frames
local WinnerFrame         = WinnerScreen:WaitForChild("WinnerFrame")
local LoserFrame          = WinnerScreen:WaitForChild("LoserFrame")
local PlayerCharacterFrame = WinnerScreen:WaitForChild("PlayerCharacter")
local CharactersFolder    = PlayerCharacterFrame:WaitForChild("Characters")

-- Remotes
local MatchSystemRequests       = ReplicatedStorage.Events.Match.MatchRemoteFunction
local MatchSystemEvents         = ReplicatedStorage.Events.Match.MatchRemoteEvent
local MatchUIInteractionsRemote = ReplicatedStorage.Events.Match.MatchUIInteractions
local ReturnToLobbyRemote       = ReplicatedStorage.Events.Match.MatchReturnToLobby

-- Tabelas de mapas
local MapSelectionTable = {
	Dojo   = game.ReplicatedStorage.MatchSystem.Storage.MapVisuals.Map_Dojo,
	Palace = game.ReplicatedStorage.MatchSystem.Storage.MapVisuals.Map_Palace,
}

local MapImageTable = {
	Palace = "rbxassetid://72421921656450",
	Dojo   = "rbxassetid://121801073534591",
}

-- Estado local
local HostAcceptNotificationStorage = nil
local MatchUIInteractionsConnection = nil
local lastMatchOpponent             = nil  -- guarda o último oponente para o rematch
local inRefreshCooldown = false

local BUTTON_COOLDOWN           = 3
local BackButtontoLobbyLastUsed = 0
local offlinePlay1v1LastUsed    = 0
local startMapUILastUsed        = 0

---------------------------------------------------------------------
-- Refresh helpers
---------------------------------------------------------------------

local function RefreshLocalQueue1v1UI()
	for _, item in LocalQueue1v1UI.MAIN.SingleFight:GetChildren() do
		if item:IsA("ImageLabel") and item.Name ~= "Template" then
			item:Destroy()
		end
	end

	for _, player in Players:GetPlayers() do
		if player == localPlayer then continue end

		local status = MatchSystemRequests:InvokeServer("FindPlayer", { PlayerName = player.Name })
		if status == "FreePlayer" then
			local btn = LocalQueue1v1UI.MAIN.SingleFight.Template:Clone()
			btn.Parent      = LocalQueue1v1UI.MAIN.SingleFight
			btn.Name        = player.Name
			btn.PlayerName.Text  = player.Name
			btn.PlayerHead.Image = Players:GetUserThumbnailAsync(
				player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
			btn.Visible = true
		end
	end
end

local function RefreshChooseTeamateUI()
	for _, item in ChooseTeamateUI.MAIN.Choose:GetChildren() do
		if item:IsA("ImageLabel") and item.Name ~= "Template" then
			item:Destroy()
		end
	end

	for _, player in Players:GetPlayers() do
		if player == localPlayer then continue end

		local status = MatchSystemRequests:InvokeServer("FindPlayer", { PlayerName = player.Name })
		if status == "FreePlayer" then
			local btn = ChooseTeamateUI.MAIN.Choose.Template:Clone()
			btn.Parent      = ChooseTeamateUI.MAIN.Choose
			btn.Name        = player.Name
			btn.PlayerName.Text  = player.Name
			btn.PlayerHead.Image = Players:GetUserThumbnailAsync(
				player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
			btn.Visible = true
		end
	end
end

local function RefreshLocalQueue2v2UI()
	for _, item in LocalQueue2v2UI.MAIN.TeamFight:GetChildren() do
		if item:IsA("Frame") and item.Name ~= "Template" then
			item:Destroy()
		end
	end

	for _, team in MatchModule.GetActiveTeams() do
		if team.Player1 == localPlayer or team.Player2 == localPlayer then continue end

		local btn = LocalQueue2v2UI.MAIN.TeamFight.Template:Clone()
		btn.Name   = team.Player1.Name
		btn.Parent = LocalQueue2v2UI.MAIN.TeamFight
		btn.Plr1.PlayerName.Text  = team.Player1.Name
		btn.Plr2.PlayerName.Text  = team.Player2.Name
		btn.Plr1.PlayerHead.Image = Players:GetUserThumbnailAsync(
			team.Player1.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		btn.Plr2.PlayerHead.Image = Players:GetUserThumbnailAsync(
			team.Player2.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		btn.Visible = true
	end
end

---------------------------------------------------------------------
-- WinnerScreen helpers
---------------------------------------------------------------------

-- Exibe o card do personagem correto dentro de PlayerCharacter.Characters,
-- igual ao comportamento do CharacterSelectionUI.
local function ShowCharacterCard(charName: string)
	for _, vp in pairs(CharactersFolder:GetChildren()) do
		if not vp:IsA("ViewportFrame") then continue end
		vp.Visible = (vp.Name == charName)
	end
end

-- Preenche os stats de um frame (WinnerFrame ou LoserFrame) com os dados
-- vindos do servidor.
local function FillStatsFrame(frame: Frame, stats: { damageDealt: number, damageTaken: number, roundsWon: number })
	local scrolling = frame:FindFirstChild("Stats") and frame.Stats:FindFirstChild("ScrollingFrame")
	if not scrolling then return end

	local damageDoneLabel    = scrolling:FindFirstChild("DamageDone")
	local damageReceivedLabel = scrolling:FindFirstChild("DamageReceived")
	local roundsWonLabel     = scrolling:FindFirstChild("RoundsWon")

	if damageDoneLabel    then damageDoneLabel.Amount.Text    = tostring(math.floor(stats.damageDealt)) end
	if damageReceivedLabel then damageReceivedLabel.Amount.Text = tostring(math.floor(stats.damageTaken)) end
	if roundsWonLabel     then roundsWonLabel.Amount.Text     = tostring(stats.roundsWon) end
end

---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------

function LocalQueue.Init()
	warn("LOCAL QUEUE INIT")
	ScreenTransition.Init(Blackout)

	FightingHUD.Init(FightingFrame)
	FightingHUD.SetAbilityFrames({
		Skill1   = AbilitiesFrame:WaitForChild("Ability"),
		Skill2   = AbilitiesFrame:WaitForChild("Ability2"),
		Ultimate = AbilitiesFrame:WaitForChild("Ability3"),
	})

	MapSelectionModule.Init(
		MapSelectionUI,
		LocalQueue1v1UI,
		LocalQueue2v2UI,
		MapSelectionTable,
		MapImageTable
	)

	ZoneController.Init({
		[AchivementsZonePart] = Achievements,
		[PartyZonePart]       = Party,
		[DailyZonePart]       = Daily,
		[ShopZonePart]        = Shop,
		[IndexZonePart]       = Index,
		[AFKChamberZonePart]  = AFKChamber,
	}, localPlayer, CharacterSelectionUI)

	localPlayer.CharacterAdded:Connect(function()
		FightingHUD.ResetAll()
	end)
end

---------------------------------------------------------------------
-- ButtonAction
---------------------------------------------------------------------

function LocalQueue.ButtonAction(button: GuiButton, action)
	if action == "EnableUI" then
		if not SelectModeUI.Visible then
			Effects.ToggleUI(SelectModeUI)
		end

	elseif action == "SelectionReadyButton" then
		MatchSystemEvents:FireServer("SetReadyState")

	elseif action == "CloseMap" then
		if not HUD.Visible then Effects.ToggleUI(HUD) end
		if MapSelectionUI.Visible then Effects.ToggleUI(MapSelectionUI) end
		MapSelectionModule.Cleanup()

	elseif action == "ReturnToLobby" then
		local now = tick()
		if now - BackButtontoLobbyLastUsed < BUTTON_COOLDOWN then
			warn("ReturnToLobby em cooldown, aguarde " ..
				string.format("%.1f", BUTTON_COOLDOWN - (now - BackButtontoLobbyLastUsed)) .. "s")
			return
		end
		BackButtontoLobbyLastUsed = now
		MapSelectionModule.Cleanup()
		ScreenTransition.FadeIn(function()
			ReturnToLobbyRemote:FireServer()
			task.wait(1.5)
			ScreenTransition.FadeOut()
		end)

	elseif action == "SelectMode1v1" then
		Effects.ToggleUI(SelectModeUI)
		Effects.ToggleUI(LocalQueue1v1UI)
		RefreshLocalQueue1v1UI()

	elseif action == "SelectMode2v2" then
		Effects.ToggleUI(SelectModeUI)
		Effects.ToggleUI(ChooseTeamateUI)
		RefreshChooseTeamateUI()

	elseif action == "ToggleLocalQueue2v2" then
		Effects.ToggleUI(LocalQueue2v2UI)

	elseif action == "AskTeam" then
		NotificationModule.SendInviteTeamNotification(button.Parent.Name)

	elseif action == "AskFight" then
		NotificationModule.SendFightInviteNotification(button.Parent.Name)

	elseif action == "AskTeamFight" then
		NotificationModule.SendTeamFightInviteNotification(
			button.Parent.Plr1.PlayerName.Text,
			button.Parent.Plr2.PlayerName.Text)

	elseif action == "OfflinePlay1v1" then
		local now = tick()
		if now - offlinePlay1v1LastUsed < BUTTON_COOLDOWN then
			warn("OfflinePlay1v1 em cooldown, aguarde " ..
				string.format("%.1f", BUTTON_COOLDOWN - (now - offlinePlay1v1LastUsed)) .. "s")
			return
		end
		offlinePlay1v1LastUsed = now
		MapSelectionModule.SetMode("Offline Play 1v1")
		Effects.ToggleUI(HUD)
		Effects.ToggleUI(MapSelectionUI)
		MapSelectionModule.Clone()

	elseif action == "RefreshChooseTeamate" then
		if inRefreshCooldown then return end
		RefreshChooseTeamateUI()
		inRefreshCooldown = true
		task.delay(0.5, function() inRefreshCooldown = false end)

	elseif action == "RefreshLocalQueue1v1" then
		if inRefreshCooldown then return end
		RefreshLocalQueue1v1UI()
		inRefreshCooldown = true
		task.delay(0.5, function() inRefreshCooldown = false end)

	elseif action == "RefreshLocalQueue2v2" then
		if inRefreshCooldown then return end
		RefreshLocalQueue2v2UI()
		inRefreshCooldown = true
		task.delay(0.5, function() inRefreshCooldown = false end)

	elseif action == "LeaveTeam" then
		MatchSystemEvents:FireServer("LeaveTeam")

	elseif action == "SelectMapUI" then
		MapSelectionModule.SelectMap(button.Name)

		-- Rematch (dentro do ButtonAction)
	elseif action == "Rematch" then
		if WinnerScreen.Visible then Effects.ToggleUI(WinnerScreen) end
		
		if lastMatchOpponent then
			NotificationModule.SendFightInviteNotification(lastMatchOpponent.Name)
		end
	elseif action == "LeaveWinnerScreen" then
		if WinnerScreen.Visible then Effects.ToggleUI(WinnerScreen) end
		
	elseif action == "StartMapUI" then
		local now = tick()
		if now - startMapUILastUsed < BUTTON_COOLDOWN then
			warn("StartMapUI em cooldown, aguarde " ..
				string.format("%.1f", BUTTON_COOLDOWN - (now - startMapUILastUsed)) .. "s")
			return
		end
		startMapUILastUsed = now

		local mode = MapSelectionUI.Main.Mode.Text
		local map  = MapSelectionModule.GetSelectedMap()

		if mode == "Offline Play 1v1" then
			game.ReplicatedStorage.UISoundEffects.Confirm:Play()
			MatchModule.StartOffline1v1Match(map)

		elseif mode == "Online 1v1" then
			if not HostAcceptNotificationStorage then return end
			game.ReplicatedStorage.UISoundEffects.Confirm:Play()
			MatchSystemEvents:FireServer("StartOnline1v1", {
				Player = HostAcceptNotificationStorage,
				Map    = map,
			})
			if MapSelectionUI.Visible then Effects.ToggleUI(MapSelectionUI) end

		elseif mode == "Online 2v2" then
			if not HostAcceptNotificationStorage then return end
			game.ReplicatedStorage.UISoundEffects.Confirm:Play()
			MatchSystemEvents:FireServer("StartOnline2v2", {
				TeamThatAccepted = HostAcceptNotificationStorage,
				Map              = map,
			})
			if MapSelectionUI.Visible then Effects.ToggleUI(MapSelectionUI) end
		end
	end
end

-- Placeholders
function LocalQueue.StartQueueTimer() end
function LocalQueue.ExitQueue() end
function LocalQueue.StartQueueUIEffects() end

---------------------------------------------------------------------
-- Eventos do servidor
---------------------------------------------------------------------

MatchSystemEvents.OnClientEvent:Connect(function(action, args)

	-- ShowWinnerScreen (dentro do OnClientEvent)
	if action == "ShowWinnerScreen" then
		-- Determina se o player local é winner ou loser
		local isWinner  = (args.PlayerWinner == localPlayer)
		local myStats   = isWinner and args.WinnerStats or args.LoserStats
		local myFrame   = isWinner and WinnerFrame      or LoserFrame
		local myChar    = isWinner and args.WinnerChar   or args.LoserChar
		local opponent  = isWinner and args.PlayerLoser  or args.PlayerWinner

		-- Guarda o oponente para o botão de rematch
		lastMatchOpponent = opponent

		LoserFrame.Visible = false
		WinnerFrame.Visible = false

		myFrame.Visible = true

		-- Card do personagem do player local
		if myChar then
			ShowCharacterCard(myChar)
		end

		-- Stats do player local no frame correto
		FillStatsFrame(myFrame, myStats)

		if not WinnerScreen.Visible then Effects.ToggleUI(WinnerScreen) end
		
	elseif action == "HideWinnerScreen" then
		if WinnerScreen.Visible then Effects.ToggleUI(WinnerScreen) end

	elseif action == "EnableCharacterSelection" then
		if not CharacterSelectionUI.Visible then Effects.ToggleUI(CharacterSelectionUI) end

	elseif action == "DisableCharacterSelection" then
		if CharacterSelectionUI.Visible then Effects.ToggleUI(CharacterSelectionUI) end

		for _, card in pairs(CharacterSelectionUI.Main.ScrollingFrame:GetChildren()) do
			if not card:IsA("ImageButton") then continue end
			card.Got.Visible = false
			card.Got.Label.P1Gradient.Enabled   = false
			card.Got.Label.P2Gradient.Enabled   = false
			card.Got.Label.BothGradient.Enabled = false
		end

	elseif action == "UpdateCharacterSelectionTimer" then
		CharacterSelectionUI.Main.TimeLeftMatch.Text = args.NewTime

	elseif action == "UpdateCharacterSelectionPlayerState" then
		if args.Player == "Player1" then
			if args.State then
				CharacterSelectionUI.Main.CharacterUI.PlayerName.IsReady.Text = "(READY)"
				CharacterSelectionUI.Main.CharacterUI.PlayerName.IsReady.ReadyGradient.Enabled    = true
				CharacterSelectionUI.Main.CharacterUI.PlayerName.IsReady.NotReadyGradient.Enabled = false
				ReadyButton.Visible    = false
				NotReadyButton.Visible = true
			else
				CharacterSelectionUI.Main.CharacterUI.PlayerName.IsReady.Text = "(NOT READY)"
				CharacterSelectionUI.Main.CharacterUI.PlayerName.IsReady.ReadyGradient.Enabled    = false
				CharacterSelectionUI.Main.CharacterUI.PlayerName.IsReady.NotReadyGradient.Enabled = true
				ReadyButton.Visible    = true
				NotReadyButton.Visible = false
			end

		elseif args.Player == "Player2" then
			if args.State then
				CharacterSelectionUI.Main.EnemyUI.PlayerName.IsReady.Text = "(READY)"
				CharacterSelectionUI.Main.EnemyUI.PlayerName.IsReady.ReadyGradient.Enabled    = true
				CharacterSelectionUI.Main.EnemyUI.PlayerName.IsReady.NotReadyGradient.Enabled = false
			else
				CharacterSelectionUI.Main.EnemyUI.PlayerName.IsReady.Text = "(NOT READY)"
				CharacterSelectionUI.Main.EnemyUI.PlayerName.IsReady.ReadyGradient.Enabled    = false
				CharacterSelectionUI.Main.EnemyUI.PlayerName.IsReady.NotReadyGradient.Enabled = true
			end
		end

	elseif action == "UpdatePlayerDescription" then
		if args.Player == "Player1" then
			for _, card in pairs(CharacterSelectionUI.Main.ScrollingFrame:GetChildren()) do
				if not card:IsA("ImageButton") then continue end
				if card.Name ~= args.Data.name then continue end

				local isAlsoP2 = card.Got.Visible and card.Got.Label.Text == "P2"
				card.Got.Visible = true
				if isAlsoP2 then
					card.Got.Label.Text = "P1/P2"
					card.Got.Label.P1Gradient.Enabled   = false
					card.Got.Label.P2Gradient.Enabled   = false
					card.Got.Label.BothGradient.Enabled = true
				else
					card.Got.Label.Text = "P1"
					card.Got.Label.P1Gradient.Enabled   = true
					card.Got.Label.P2Gradient.Enabled   = false
					card.Got.Label.BothGradient.Enabled = false
				end
			end

			for _, card in pairs(CharacterSelectionUI.Main.CharacterUI.PlayerCharacterSelected.CharactersPlayer1:GetChildren()) do
				card.Visible = false
				if not card:IsA("ViewportFrame") then continue end
				if card.Name ~= args.Data.name then continue end
				card.Visible = true
			end

			CharacterSelectionUI.Main.CharacterUI.PlayerCharacterSelected.CharacterName.Text         = args.Data.name
			CharacterSelectionUI.Main.CharacterUI.PlayerCharacterSelected.CharacterName.RealText.Text = args.Data.name
			CharacterSelectionUI.Main.CharacterUI.PlayerName.UserName.Text    = game.Players.LocalPlayer.Name
			CharacterSelectionUI.Main.CharacterUI.PlayerName.DisplayName.Text = game.Players.LocalPlayer.DisplayName
			CharacterSelectionUI.Main.CharacterUI.PlayerName.Photo.playericon.Image = Players:GetUserThumbnailAsync(
				game.Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
			CharacterSelectionUI.Main.CharacterUI.Description.Text = args.Data.description

			for _, skill in args.Data.Skills do
				if skill.name == "Skill1" then
					CharacterSelectionUI.Main.CharacterUI.Skill1.Description.Text = skill.description
				elseif skill.name == "Skill2" then
					CharacterSelectionUI.Main.CharacterUI.Skill2.Description.Text = skill.description
				elseif skill.name == "Ultimate" then
					CharacterSelectionUI.Main.CharacterUI.Ultimate.Description.Text = skill.description
				end
			end

		elseif args.Player == "Player2" then
			for _, card in pairs(CharacterSelectionUI.Main.ScrollingFrame:GetChildren()) do
				if not card:IsA("ImageButton") then continue end
				if card.Name ~= args.Data.name then continue end

				local isAlsoP1 = card.Got.Visible and card.Got.Label.Text == "P1"
				card.Got.Visible = true
				if isAlsoP1 then
					card.Got.Label.Text = "P1/P2"
					card.Got.Label.P1Gradient.Enabled   = false
					card.Got.Label.P2Gradient.Enabled   = false
					card.Got.Label.BothGradient.Enabled = true
				else
					card.Got.Label.Text = "P2"
					card.Got.Label.P1Gradient.Enabled   = false
					card.Got.Label.P2Gradient.Enabled   = true
					card.Got.Label.BothGradient.Enabled = false
				end
			end

			for _, card in pairs(CharacterSelectionUI.Main.EnemyUI.EnemyCharacterSelected.CharactersPlayer2:GetChildren()) do
				card.Visible = false
				if not card:IsA("ViewportFrame") then continue end
				if card.Name ~= args.Data.name then continue end
				card.Visible = true
			end

			CharacterSelectionUI.Main.EnemyUI.EnemyCharacterSelected.CharacterName.Text         = args.Data.name
			CharacterSelectionUI.Main.EnemyUI.EnemyCharacterSelected.CharacterName.RealText.Text = args.Data.name
			CharacterSelectionUI.Main.EnemyUI.PlayerName.UserName.Text    = args.Enemy.Name
			CharacterSelectionUI.Main.EnemyUI.PlayerName.DisplayName.Text = args.Enemy.DisplayName
			CharacterSelectionUI.Main.EnemyUI.PlayerName.Photo.playericon.Image = Players:GetUserThumbnailAsync(
				args.Enemy.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
			CharacterSelectionUI.Main.EnemyUI.Description.Text = args.Data.description

			for _, skill in args.Data.Skills do
				if skill.name == "Skill1" then
					CharacterSelectionUI.Main.EnemyUI.Skill1.Description.Text = skill.description
				elseif skill.name == "Skill2" then
					CharacterSelectionUI.Main.EnemyUI.Skill2.Description.Text = skill.description
				elseif skill.name == "Ultimate" then
					CharacterSelectionUI.Main.EnemyUI.Ultimate.Description.Text = skill.description
				end
			end
		end

	elseif action == "DisableHUD" then
		if HUD.Visible then Effects.ToggleUI(HUD) end

	elseif action == "EnableHUD" then
		if not HUD.Visible then Effects.ToggleUI(HUD) end

	elseif action == "EnableFightingFrame" then
		if not FightingFrame.Visible then Effects.ToggleUI(FightingFrame) end
		if HUD.Visible then Effects.ToggleUI(HUD) end
		
		MatchUIInteractionsConnection = MatchUIInteractionsRemote.OnClientEvent:Connect(function(a, ar)
			FightingHUD.HandleEvent(a, ar)
		end)

	elseif action == "DisableFightingFrame" then
		if FightingFrame.Visible then Effects.ToggleUI(FightingFrame) end
		FightingHUD.ResetAll()
		MapSelectionModule.Cleanup()
		if MatchUIInteractionsConnection then
			MatchUIInteractionsConnection:Disconnect()
			MatchUIInteractionsConnection = nil
		end

	elseif action == "EnableQueue2v2" then
		LocalQueue2v2UI.MAIN.Team.Plr1.PlayerName.Text = args.Player1.Name
		LocalQueue2v2UI.MAIN.Team.Plr1.PlayerHead.Image = Players:GetUserThumbnailAsync(
			args.Player1.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		LocalQueue2v2UI.MAIN.Team.Plr2.PlayerName.Text = args.Player2.Name
		LocalQueue2v2UI.MAIN.Team.Plr2.PlayerHead.Image = Players:GetUserThumbnailAsync(
			args.Player2.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		Effects.ToggleUI(LocalQueue2v2UI)
		if not TeamToggleFrame.Visible then TeamToggleFrame.Visible = true end
		RefreshLocalQueue2v2UI()

	elseif action == "DisableQueue2v2" then
		if LocalQueue2v2UI.Visible then Effects.ToggleUI(LocalQueue2v2UI) end
		if TeamToggleFrame.Visible then TeamToggleFrame.Visible = false end

	elseif action == "DisableChooseTeamateUI" then
		if ChooseTeamateUI.Visible then Effects.ToggleUI(ChooseTeamateUI) end

	elseif action == "EnableChooseMap" then
		if not MapSelectionUI.Visible then Effects.ToggleUI(MapSelectionUI) end
		MapSelectionModule.SetMode(args.Mode)
		HostAcceptNotificationStorage = args.PlayerThatAccepted or args.TeamThatAccepted
		MapSelectionModule.Clone()

	elseif action == "DisableChooseMap" then
		if MapSelectionUI.Visible then Effects.ToggleUI(MapSelectionUI) end
		MapSelectionModule.Cleanup()

	elseif action == "EnableBackToLobbyButton" then
		if not ReturnToLobby.Visible then ReturnToLobby.Visible = true end

	elseif action == "DisableBackToLobbyButton" then
		if ReturnToLobby.Visible then ReturnToLobby.Visible = false end

	elseif action == "DisableMapUI" then
		if MapSelectionUI.Visible then Effects.ToggleUI(MapSelectionUI) end

	elseif action == "FadeIn" then
		ScreenTransition.FadeIn()

	elseif action == "FadeOut" then
		ScreenTransition.FadeOut()
	end
end)

return LocalQueue