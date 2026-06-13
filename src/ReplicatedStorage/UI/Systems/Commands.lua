local Commands = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerState = require(ReplicatedStorage.PlayerState.PlayerStateClient)

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = localPlayer:WaitForChild("PlayerGui")
local MainUI = PlayerGui:WaitForChild("UI")

local CommandsFrame = MainUI:WaitForChild("Commands", 10)
if not CommandsFrame then
	warn("[CommandsUI] UI.Commands was not found in PlayerGui.UI")
	return Commands
end

local MainFrame = CommandsFrame:WaitForChild("MAIN")
local ChooseFrame = MainFrame:WaitForChild("Choose")
local RuntimeRowTemplate = ChooseFrame:WaitForChild("BindTemplate")
local RowTemplate = RuntimeRowTemplate:Clone()
local TemplateCommandList = RowTemplate:WaitForChild("CommandList")
local KeyTemplate = TemplateCommandList:WaitForChild("BindTemplate"):Clone()
local PlusTemplate = TemplateCommandList:WaitForChild("Plus"):Clone()
local ChooseLayout = ChooseFrame:FindFirstChildOfClass("UIListLayout")
local ChoosePadding = ChooseFrame:FindFirstChildOfClass("UIPadding")
local CommandDataRemote = ReplicatedStorage
	:WaitForChild("Events")
	:WaitForChild("Commands")
	:WaitForChild("GetCommandData")

local UNIVERSAL_COMMANDS = {
	{ label = "Move Right", tokens = { "RIGHT" } },
	{ label = "Move Left", tokens = { "LEFT" } },
	{ label = "Jump", tokens = { "JUMP" } },
	{ label = "Double Jump", tokens = { "JUMP", "JUMP" } },
	{ label = "Crouch", tokens = { "CROUCH" } },
	{ label = "Forward Dash", tokens = { "RIGHT", "RIGHT" } },
	{ label = "Back Dash", tokens = { "LEFT", "LEFT" } },
	{ label = "Light Attack", tokens = { "LIGHTATK" } },
	{ label = "Heavy Attack", tokens = { "HARDATK" } },
	{ label = "Charge Attack", tokens = { "CHARGEATK" } },
	{ label = "Grab", tokens = { "GRAB" } },
	{ label = "Block", tokens = { "BLOCK" } },
	{ label = "Air Light Attack", tokens = { "JUMP", "LIGHTATK" } },
	{ label = "Air Heavy Attack", tokens = { "JUMP", "HARDATK" } },
	{ label = "Crouch Attack", tokens = { "CROUCH", "LIGHTATK" } },
}

local KEY_DISPLAY_PREFERENCES = {
	LIGHTATK = { "MouseButton1", "U" },
	HARDATK = { "MouseButton2", "I" },
	CHARGEATK = { "Q", "O" },
	GRAB = { "E", "P" },
	BLOCK = { "F", "Y" },
}

local KEY_DISPLAY_ALIASES = {
	MouseButton1 = "M1",
	MouseButton2 = "M2",
	MouseButton3 = "M3",
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
	Zero = "0",
	LeftShift = "Shift",
	RightShift = "Shift",
	LeftControl = "Ctrl",
	RightControl = "Ctrl",
	LeftAlt = "Alt",
	RightAlt = "Alt",
	Return = "Enter",
	Backspace = "Back",
	Space = "Space",
}

local CharacterCommandCache = {}
local LastRenderedCharacterId = nil

local function ensureCommandListScale(commandList: Instance): UIScale?
	local existingScale = commandList:FindFirstChild("AutoFitScale")
	if existingScale and existingScale:IsA("UIScale") then
		return existingScale
	end

	if not commandList:IsA("GuiObject") then
		return nil
	end

	local newScale = Instance.new("UIScale")
	newScale.Name = "AutoFitScale"
	newScale.Parent = commandList

	return newScale
end

local function setTextIfPossible(instance: Instance?, value: string)
	if not instance then
		return
	end

	local ok = pcall(function()
		(instance :: any).Text = value
	end)

	if not ok then
		return
	end
end

local function getPreferredBind(actionName: string, bindings: { string }): string?
	local preferredBindings = KEY_DISPLAY_PREFERENCES[actionName]
	if preferredBindings then
		for _, preferredValue in ipairs(preferredBindings) do
			for _, bindingValue in ipairs(bindings) do
				if bindingValue == preferredValue then
					return bindingValue
				end
			end
		end
	end

	return bindings[1]
end

local function formatBindText(rawBind: string?): string
	if not rawBind or rawBind == "" then
		return "?"
	end

	return KEY_DISPLAY_ALIASES[rawBind] or rawBind
end

local function getPrimaryBindDisplay(actionName: string): string
	local inputs = PlayerState.Get("Inputs")
	if typeof(inputs) ~= "table" then
		return formatBindText(actionName)
	end

	local bindings = inputs[actionName]
	if typeof(bindings) ~= "table" or #bindings == 0 then
		return formatBindText(actionName)
	end

	return formatBindText(getPreferredBind(actionName, bindings))
end

local function getDisplayTokens(tokens: { string }): { string }
	local displayTokens = {}

	for _, token in ipairs(tokens) do
		table.insert(displayTokens, getPrimaryBindDisplay(token))
	end

	return displayTokens
end

local function getTokenBaseWidth(widget: GuiObject): number
	local widthFromSize = widget.Size.X.Offset
	if widthFromSize > 0 then
		return widthFromSize
	end

	local absoluteWidth = widget.AbsoluteSize.X
	if absoluteWidth > 0 then
		return absoluteWidth
	end

	return 0
end

local function getPaddingOffset(paddingValue: UDim, useHeight: boolean?): number
	local frameAxisSize = 0
	if ChooseFrame:IsA("GuiObject") then
		frameAxisSize = if useHeight then ChooseFrame.AbsoluteSize.Y else ChooseFrame.AbsoluteSize.X
	end

	return paddingValue.Offset + (frameAxisSize * paddingValue.Scale)
end

local function refreshChooseCanvas(shouldResetScroll: boolean?)
	if not ChooseFrame:IsA("ScrollingFrame") then
		return
	end

	shouldResetScroll = shouldResetScroll == true

	if not ChooseLayout then
		if shouldResetScroll then
			ChooseFrame.CanvasPosition = Vector2.zero
		end
		return
	end

	local topPadding = 0
	local bottomPadding = 0
	if ChoosePadding then
		topPadding = getPaddingOffset(ChoosePadding.PaddingTop, true)
		bottomPadding = getPaddingOffset(ChoosePadding.PaddingBottom, true)
	end

	local contentHeight = math.max(0, ChooseLayout.AbsoluteContentSize.Y + topPadding + bottomPadding)
	local minimumHeight = ChooseFrame.AbsoluteSize.Y

	ChooseFrame.CanvasSize = UDim2.fromOffset(0, math.max(contentHeight, minimumHeight))

	if shouldResetScroll then
		ChooseFrame.CanvasPosition = Vector2.zero
	end
end

local function fitCommandListToWidth(commandList: GuiObject, attempt: number?)
	local tries = attempt or 0
	if commandList.Parent == nil then
		return
	end

	local listLayout = commandList:FindFirstChildOfClass("UIListLayout")
	local listScale = ensureCommandListScale(commandList)
	if not listScale then
		return
	end

	local availableWidth = commandList.AbsoluteSize.X
	if availableWidth <= 0 then
		if tries >= 8 then
			return
		end

		task.delay(0.05, function()
			fitCommandListToWidth(commandList, tries + 1)
		end)
		return
	end

	local orderedChildren = {}
	for _, child in ipairs(commandList:GetChildren()) do
		if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIScale") then
			table.insert(orderedChildren, child)
		end
	end

	table.sort(orderedChildren, function(leftItem, rightItem)
		return leftItem.LayoutOrder < rightItem.LayoutOrder
	end)

	local totalWidth = 0
	local spacing = 0
	if listLayout then
		spacing = listLayout.Padding.Offset + (listLayout.Padding.Scale * availableWidth)
	end

	for index, child in ipairs(orderedChildren) do
		totalWidth += getTokenBaseWidth(child)
		if index < #orderedChildren then
			totalWidth += spacing
		end
	end

	if totalWidth <= 0 then
		listScale.Scale = 1
		if commandList:GetAttribute("BasePosXScale") ~= nil then
			commandList.Position = UDim2.new(
				commandList:GetAttribute("BasePosXScale"),
				commandList:GetAttribute("BasePosXOffset"),
				commandList:GetAttribute("BasePosYScale"),
				commandList:GetAttribute("BasePosYOffset")
			)
		end
		return
	end

	if commandList:GetAttribute("BasePosXScale") == nil then
		commandList:SetAttribute("BasePosXScale", commandList.Position.X.Scale)
		commandList:SetAttribute("BasePosXOffset", commandList.Position.X.Offset)
		commandList:SetAttribute("BasePosYScale", commandList.Position.Y.Scale)
		commandList:SetAttribute("BasePosYOffset", commandList.Position.Y.Offset)
	end

	local fitScale = math.clamp(availableWidth / totalWidth, 0.35, 1)
	local shiftLeft = math.floor((availableWidth * (1 - fitScale) * 0.5) + 0.5)

	listScale.Scale = fitScale
	commandList.Position = UDim2.new(
		commandList:GetAttribute("BasePosXScale"),
		commandList:GetAttribute("BasePosXOffset") - shiftLeft,
		commandList:GetAttribute("BasePosYScale"),
		commandList:GetAttribute("BasePosYOffset")
	)
end

local function clearChooseFrame()
	for _, child in ipairs(ChooseFrame:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") then
			continue
		end

		child:Destroy()
	end
end

local function createKeyWidget(displayText: string, layoutOrder: number): GuiObject
	local keyClone = KeyTemplate:Clone()
	keyClone.Name = string.format("Key_%d", layoutOrder)
	keyClone.LayoutOrder = layoutOrder
	keyClone.Visible = true
	setTextIfPossible(keyClone:FindFirstChild("Text"), displayText)

	return keyClone
end

local function createPlusWidget(layoutOrder: number): GuiObject
	local plusClone = PlusTemplate:Clone()
	plusClone.Name = string.format("Plus_%d", layoutOrder)
	plusClone.LayoutOrder = layoutOrder
	plusClone.Visible = true

	return plusClone
end

local function createCommandRow(entry: { label: string, tokens: { string } }, rowOrder: number)
	local rowClone = RowTemplate:Clone()
	rowClone.Name = string.format("Command_%d", rowOrder)
	rowClone.LayoutOrder = rowOrder
	rowClone.Visible = true
	rowClone.Position = UDim2.fromScale(0, 0)

	setTextIfPossible(rowClone:FindFirstChild("TextLabel"), entry.label)

	local commandList = rowClone:FindFirstChild("CommandList")
	if commandList and commandList:IsA("GuiObject") then
		for _, child in ipairs(commandList:GetChildren()) do
			if child:IsA("UIListLayout") or child:IsA("UIPadding") then
				continue
			end

			child:Destroy()
		end

		local displayTokens = getDisplayTokens(entry.tokens)
		local layoutOrder = 1

		for index, displayText in ipairs(displayTokens) do
			local keyWidget = createKeyWidget(displayText, layoutOrder)
			keyWidget.Parent = commandList
			layoutOrder += 1

			if index < #displayTokens then
				local plusWidget = createPlusWidget(layoutOrder)
				plusWidget.Parent = commandList
				layoutOrder += 1
			end
		end
	end

	rowClone.Parent = ChooseFrame
	task.defer(function()
		if commandList and commandList:IsA("GuiObject") then
			fitCommandListToWidth(commandList)
		end
		refreshChooseCanvas(false)
	end)
end

local function updateHeaderText(characterName: string)
	local header = CommandsFrame:FindFirstChild("Header")
	local headerText = header and header:FindFirstChild("HeaderText")
	if headerText then
		setTextIfPossible(headerText, string.format("Commands - %s", characterName))
	end
end

local function renderCommands(characterPayload)
	clearChooseFrame()

	if ChooseFrame:IsA("ScrollingFrame") then
		ChooseFrame.CanvasPosition = Vector2.zero
	end

	local allEntries = {}
	for _, entry in ipairs(UNIVERSAL_COMMANDS) do
		table.insert(allEntries, entry)
	end

	if characterPayload and typeof(characterPayload.entries) == "table" then
		for _, entry in ipairs(characterPayload.entries) do
			table.insert(allEntries, entry)
		end
	end

	for index, entry in ipairs(allEntries) do
		createCommandRow(entry, index)
	end

	local characterName = characterPayload and characterPayload.characterName or "Commands"
	updateHeaderText(characterName)
	refreshChooseCanvas(true)
	task.defer(function()
		refreshChooseCanvas(true)
	end)
end

local function getCharacterPayload(characterId: string)
	if CharacterCommandCache[characterId] then
		return CharacterCommandCache[characterId]
	end

	local ok, result = pcall(function()
		return CommandDataRemote:InvokeServer(characterId)
	end)

	if not ok then
		warn(string.format("[CommandsUI] Failed to fetch commands for %s: %s", characterId, result))
		return nil
	end

	if typeof(result) == "table" then
		CharacterCommandCache[characterId] = result
	end

	return result
end

local function refreshCommands()
	local activeCharacterId = PlayerState.Get("ActiveCharacter")
	if typeof(activeCharacterId) ~= "string" or activeCharacterId == "" then
		return
	end

	LastRenderedCharacterId = activeCharacterId
	renderCommands(getCharacterPayload(activeCharacterId))
end

function Commands.Init()
	if RuntimeRowTemplate.Parent then
		RuntimeRowTemplate:Destroy()
	end

	if ChooseLayout then
		ChooseLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			refreshChooseCanvas(false)
		end)
	end

	if ChooseFrame:IsA("ScrollingFrame") then
		ChooseFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			refreshChooseCanvas(false)
		end)
	end

	refreshCommands()

	PlayerState.OnChanged("ActiveCharacter", function(newCharacterId)
		if typeof(newCharacterId) ~= "string" or newCharacterId == "" then
			return
		end

		LastRenderedCharacterId = newCharacterId
		renderCommands(getCharacterPayload(newCharacterId))
	end)

	PlayerState.OnChanged("Inputs", function()
		if not LastRenderedCharacterId then
			refreshCommands()
			return
		end

		renderCommands(getCharacterPayload(LastRenderedCharacterId))
	end)
end

return Commands
