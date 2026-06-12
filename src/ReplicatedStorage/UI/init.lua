local UI = {}

--Services
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Imports
local PlayerState = require(ReplicatedStorage.PlayerState.PlayerStateClient)
local Effects = require(script:WaitForChild("Effects"))

--Client_Related
local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = localPlayer:WaitForChild("PlayerGui")
local UI_ROOT_WAIT_TIMEOUT = math.huge
local Main = PlayerGui:WaitForChild("UI", UI_ROOT_WAIT_TIMEOUT)
if not Main then
	warn("[UI] ScreenGui 'UI' não replicou - PATHS ficará vazio")
end

-- WaitForChild com timeout: um frame ausente avisa em vez de travar o boot.
local PATH_WAIT_TIMEOUT = 10
local function wfc(name: string): Frame?
	if not Main then return nil end
	local frame = Main:WaitForChild(name, PATH_WAIT_TIMEOUT)
	if not frame then
		warn(`[UI] Frame ausente em PATHS: {name}`)
	end
	return frame :: any
end

--Tables/Variables
local PATHS: {Frame} = {
	WinnerScreen = wfc('WinnerScreen'),
	FTUEPopup = wfc("FTUEPopup"),
	FTUESmallPopup = wfc("FTUESmallPopup"),
	Achievements = wfc("Achievements"),
	CharacterIndex = wfc("CharacterIndex"),
	CharacterSelection = wfc("CharacterSelection"),
	Codes = wfc("Codes"),
	GiftSlot = wfc("GiftSlot"),
	DailyRewards = wfc("DailyRewards"),
	FightingFrame = wfc("FightingFrame"),
	HUD = wfc("HUD"),
	InviteRewards = wfc("InviteRewards"),
	Party = wfc("Party"),
	Quests = wfc("Quests"),
	Start = wfc("Start"),
	Roll = wfc("Roll"),
	Shop = wfc("Shop"),
	Tags = wfc("Tags"),
	SelectModeLocal = wfc("SelectModeLocal"),
	SelectModeGlobal = wfc("SelectModeGlobal"),
	LocalQueue1v1 = wfc("LocalQueue1v1"),
	LocalQueue2v2 = wfc("LocalQueue2v2"),
	TeamToggleFrame = wfc("TeamToggleFrame"),
	ChooseTeamateLocal = wfc("ChooseTeamateLocal"),
	ChooseTeamateGlobal = wfc("ChooseTeamateGlobal"),
	MapSelection = wfc("MapSelection"),
	ReturnToLobby = wfc('ReturnToLobby'),
	Battlepass = wfc("Battlepass"),
	Inventory = wfc("Inventory")
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

-- Sistemas visíveis/centrais que o jogador vê primeiro inicializam antes do resto.
local INIT_PRIORITY = { "Update", "Leaderstats", "CurrencyFloat" }

local function collectModuleScripts(container: Instance): { ModuleScript }
	local list = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("ModuleScript") then
			table.insert(list, child)
		end
	end
	return list
end

function UI.Init()
	if not Main then
		warn("[UI] Init skipped because PlayerGui.UI is missing")
		return
	end

	syncVisibilityListeners()

	-- Posições originais e botões interativos ficam prontos de imediato,
	-- enquanto os Inits pesados (clones de templates) são escalonados abaixo.
	for _, frame in pairs(PATHS) do
		Effects.StoreOriginalPosition(frame)
	end

	setupInteractives()

	-- Junta todos os módulos de UI (Hud + Systems).
	local modules = {}
	for _, m in ipairs(collectModuleScripts(script:WaitForChild("Hud"))) do
		table.insert(modules, m)
	end
	for _, m in ipairs(collectModuleScripts(script:WaitForChild("Systems"))) do
		table.insert(modules, m)
	end

	-- Ordena: prioritários primeiro, o restante mantém a ordem original.
	local ordered = {}
	local seen = {}
	for _, name in ipairs(INIT_PRIORITY) do
		for _, m in ipairs(modules) do
			if m.Name == name and not seen[m] then
				table.insert(ordered, m)
				seen[m] = true
			end
		end
	end
	for _, m in ipairs(modules) do
		if not seen[m] then
			table.insert(ordered, m)
		end
	end

	-- Inicializa de forma escalonada: lança um módulo por frame para espalhar o
	-- custo de clonagem de templates. Cada módulo roda na própria thread (task.spawn)
	-- para que um Init pesado/lento não trave a fila nem derrube os outros.
	-- Diagnóstico: imprime antes (>>>) e depois (<<<) de cada módulo. O módulo que
	-- bloqueia a thread (causa de "exhausted allowed execution time") é aquele cujo
	-- ">>>" é seguido por um intervalo de ~10s no timestamp antes do próximo print.
	local DEBUG_INIT = true
	task.spawn(function()
		for _, moduleScript in ipairs(ordered) do
			task.spawn(function()
				if DEBUG_INIT then
					print(`[UI] >>> {moduleScript.Name}`)
				end
				local ok, module = pcall(require, moduleScript)
				if not ok then
					warn(`[UI] require de {moduleScript.Name} falhou:`, module)
				elseif typeof(module.Init) == "function" then
					local okInit, err = pcall(module.Init)
					if not okInit then
						warn(`[UI] Init de {moduleScript.Name} falhou:`, err)
					end
				end
				if DEBUG_INIT then
					print(`[UI] <<< {moduleScript.Name}`)
				end
			end)
			task.wait()
		end
	end)
end

return UI
