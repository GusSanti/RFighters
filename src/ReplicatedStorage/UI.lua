local UI = {}

--Services
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Folders
local Modules = ReplicatedStorage:WaitForChild("Modules")

--Imports
local PlayerState = require(ReplicatedStorage.PlayerState.PlayerStateClient)
local Effects = require(script:WaitForChild("Effects"))

--Client_Related
local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local PlayerGui = localPlayer:WaitForChild("PlayerGui") 
local Main = PlayerGui:WaitForChild("UI")

--Tables/Variables
local PATHS: {Frame} = {
	WinnerScreen = Main:WaitForChild('WinnerScreen'),
	FTUEPopup = Main:WaitForChild("FTUEPopup"),
	FTUESmallPopup = Main:WaitForChild("FTUESmallPopup"),
	Achievements = Main:WaitForChild("Achievements"),
	CharacterIndex = Main:WaitForChild("CharacterIndex"),
	CharacterSelection = Main:WaitForChild("CharacterSelection"),
	Codes = Main:WaitForChild("Codes"),
	GiftSlot = Main:WaitForChild("GiftSlot"),
	DailyRewards = Main:WaitForChild("DailyRewards"),
	FightingFrame = Main:WaitForChild("FightingFrame"),
	HUD = Main:WaitForChild("HUD"),
	InviteRewards = Main:WaitForChild("InviteRewards"),
	Party = Main:WaitForChild("Party"),
	Quests = Main:WaitForChild("Quests"),
	Start = Main:WaitForChild("Start"),
	Roll = Main:WaitForChild("Roll"),
	Shop = Main:WaitForChild("Shop"),
	Tags = Main:WaitForChild("Tags"),
	SelectModeLocal = Main:WaitForChild("SelectModeLocal"),
	SelectModeGlobal = Main:WaitForChild("SelectModeGlobal"),
	LocalQueue1v1 = Main:WaitForChild("LocalQueue1v1"),
	LocalQueue2v2 = Main:WaitForChild("LocalQueue2v2"),
	TeamToggleFrame = Main:WaitForChild("TeamToggleFrame"),
	ChooseTeamateLocal = Main:WaitForChild("ChooseTeamateLocal"),
	ChooseTeamateGlobal = Main:WaitForChild("ChooseTeamateGlobal"),
	MapSelection = Main:WaitForChild("MapSelection"),
	ReturnToLobby = Main:WaitForChild('ReturnToLobby'),
	Battlepass = Main:WaitForChild("Battlepass"),
	Inventory = Main:WaitForChild("Inventory")
}

local OpenedUI = nil
local isAnimating = false
local UIState: {[any]: boolean} = {}
local DEBOUNCE_TIME = 0.3

local EXCEPTIONS: {[string]: boolean} = {
	HUD = true,
	FightingFrame = true,
	TeamToggleFrame = true
}

local function syncVisibilityListeners()
	for name, frame in pairs(PATHS) do
		if EXCEPTIONS[name] then continue end

		frame:GetPropertyChangedSignal("Visible"):Connect(function()
			local isVisible = frame.Visible
			UIState[frame] = isVisible

			if isVisible then
				-- Fecha todas as outras UIs abertas
				for otherName, otherFrame in pairs(PATHS) do
					if EXCEPTIONS[otherName] then continue end
					if otherFrame ~= frame and otherFrame.Visible then
						Effects.ToggleUI(otherFrame)
						UIState[otherFrame] = false
					end
				end
				OpenedUI = frame
			else
				if OpenedUI == frame then
					OpenedUI = nil
				end
			end
		end)
	end
end
local function searchButtonFunction(button: GuiButton)
	local containerAttribute = button:GetAttribute("Container")
	if not containerAttribute then
		warn(`[UI] - Container attribute not found in script`)
		return
	end

	local functionAttribute = button:GetAttribute("Function")	
	if not functionAttribute then
		warn(`[UI] - Function attribute not found in script`)
		return
	end

	local functionContainer = script:FindFirstChild(containerAttribute)
	if not functionContainer then
		warn(`[UI] - {containerAttribute} folder not found in script`)
		return
	end

	local module = functionContainer:FindFirstChild(functionAttribute)
	if not module then
		warn(`[UI] - {functionAttribute} module not found in script`)
		return
	end

	local requiredModule = require(module)
	return requiredModule
end

local function handleButtonClick(button: GuiButton)
	if isAnimating then return end

	Effects.Click(button)

	if PATHS[button.Name] and not button:GetAttribute("Function") then
		local targetFrame = PATHS[button.Name]
		local isException = EXCEPTIONS[button.Name]

		isAnimating = true

		if not isException then
			if OpenedUI and OpenedUI ~= targetFrame then
				Effects.ToggleUI(OpenedUI)
				UIState[OpenedUI] = false
				OpenedUI = nil
				task.wait(DEBOUNCE_TIME)
			end
		end

		-- ✅ Lê .Visible diretamente ao invés de UIState
		local currentlyOpen = targetFrame.Visible

		if currentlyOpen then
			Effects.ToggleUI(targetFrame)
			UIState[targetFrame] = false
			OpenedUI = nil
		else
			Effects.ToggleUI(targetFrame)
			UIState[targetFrame] = true
			if not isException then
				OpenedUI = targetFrame
			end
		end

		task.wait(DEBOUNCE_TIME)
		isAnimating = false
		return
	end

	local functionModule = searchButtonFunction(button)
	if functionModule and typeof(functionModule.ButtonAction) == "function" then
		local buttonAction = button:GetAttribute('Action')
		if buttonAction then
			functionModule.ButtonAction(button, buttonAction)
		else
			functionModule.ButtonAction(button)
		end
		return
	end

	if button.Name == "Close" then
		if isAnimating then return end

		local current = button.Parent
		while current and current ~= Main do
			if PATHS[current.Name] then
				isAnimating = true
				game.ReplicatedStorage.UISoundEffects.Close:Play()
				Effects.ToggleUI(PATHS[current.Name])
				UIState[PATHS[current.Name]] = false

				if OpenedUI == PATHS[current.Name] then
					OpenedUI = nil
				end

				task.wait(DEBOUNCE_TIME)
				isAnimating = false
				return
			end
			current = current.Parent
		end
	end
end

local function setupInteractives()
	local function connectButton(button: GuiButton)
		button.MouseEnter:Connect(function()
			game.ReplicatedStorage.UISoundEffects.HoverIn:Play()
			Effects.MouseEnter(button)
		end)
		button.MouseLeave:Connect(function()
			game.ReplicatedStorage.UISoundEffects.HoverOut:Play()
			Effects.MouseLeave(button)
		end)
		button.MouseButton1Click:Connect(function()
			handleButtonClick(button)
		end)
	end
	
	local function connectNoHoverButton(button: GuiButton)
		button.MouseButton1Click:Connect(function()
			handleButtonClick(button)
		end)
	end
	
	-- HOVER

	for _, button in ipairs(CollectionService:GetTagged("Interactive")) do
		if button:IsA("GuiButton") and button:IsDescendantOf(localPlayer) then
			connectButton(button)
		end
	end

	CollectionService:GetInstanceAddedSignal("Interactive"):Connect(function(instance)
		if instance:IsA("GuiButton") and instance:IsDescendantOf(localPlayer) then
			connectButton(instance)
		end
	end)
	
	-- NO HOVER
	
	for _, button in ipairs(CollectionService:GetTagged("InteractiveNoHover")) do
		if button:IsA("GuiButton") and button:IsDescendantOf(localPlayer) then
			connectNoHoverButton(button)
		end
	end

	CollectionService:GetInstanceAddedSignal("InteractiveNoHover"):Connect(function(instance)
		if instance:IsA("GuiButton") and instance:IsDescendantOf(localPlayer) then
			connectNoHoverButton(instance)
		end
	end)
end

function UI.Init()
	syncVisibilityListeners()

	for _, moduleScript in ipairs(script:WaitForChild("Hud"):GetChildren()) do
		if not moduleScript:IsA("ModuleScript") then continue end

		local module = require(moduleScript)
		if typeof(module.Init) == "function" then
			task.spawn(module.Init)
		end
	end

	for _, moduleScript in ipairs(script:WaitForChild("Systems"):GetChildren()) do
		if not moduleScript:IsA("ModuleScript") then continue end

		local module = require(moduleScript)
		if typeof(module.Init) == "function" then
			task.spawn(module.Init)
		end
	end
	
	-- No início de UI.Init(), antes de qualquer coisa:
	for name, frame in pairs(PATHS) do
		Effects.StoreOriginalPosition(frame)  -- ou acessa a tabela diretamente
	end

	setupInteractives()
end

return UI