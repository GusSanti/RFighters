local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local mainUi = playerGui:WaitForChild("UI", 60)

if not mainUi then
	warn("[LobbyTutorial] PlayerGui.UI was not found. Lobby tutorial disabled.")
	return
end

local ServerEvents = ReplicatedStorage.CombatSystem.Events.ServerEvents
local Effects = require(ReplicatedStorage.UI:WaitForChild("Effects"))

local TUTORIAL_FONT = Font.new(
	"rbxasset://fonts/families/Bangers.json",
	Enum.FontWeight.Bold,
	Enum.FontStyle.Italic
)

local GUIDED_FRAME_NAMES = {
	"DailyRewards",
	"FTUEPopup",
	"Shop",
	"Roll",
	"Inventory",
	"CharacterIndex",
	"Quests",
	"Achievements",
	"Battlepass",
	"Codes",
	"GiftSlot",
	"InviteRewards",
	"Party",
	"SelectModeLocal",
	"LocalQueue1v1",
	"LocalQueue2v2",
	"MapSelection",
}

local LOBBY_TUTORIAL_STEPS = {
	{
		title = "ROLL",
		body = "Click Roll to open the character roll screen.",
		targetDynamic = "OpenRollButton",
		requireClick = true,
		passThroughClick = true,
		clickText = "CLICK ROLL",
		targetPadding = 10,
		advanceDelay = 0.55,
	},
	{
		title = "SPIN",
		body = "Press Spin to roll for a fighter.",
		open = "Roll",
		targetRoot = "Roll",
		targetCandidates = { { "SpinButton" } },
		requireClick = true,
		passThroughClick = true,
		clickText = "CLICK SPIN",
		targetPadding = 12,
		skipHudEnsure = true,
	},
}

local backdropGui = nil
local tutorialGui = nil
local tutorialRoot = nil
local overlay = nil
local highlight = nil
local clickBlocker = nil
local panel = nil
local titleLabel = nil
local bodyLabel = nil
local counterLabel = nil
local nextButton = nil
local skipButton = nil
local currentTarget = nil
local renderConnection = nil
local currentStepIndex = 0
local tutorialRunning = false
local originalMainDisplayOrder = nil
local currentStepRequiresClick = false
local waitingForStepClick = false
local currentStep = nil
local disabledCloseButtons = {}
local targetClickConnection = nil
local advanceFromRequiredClick

local function setStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = color or Color3.fromRGB(0, 0, 0)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = thickness or 2
	stroke.Transparency = 0
	stroke.Parent = parent
	return stroke
end

local function makeTextButton(name, text, size, position)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(255, 199, 58)
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.FontFace = TUTORIAL_FONT

	local textSizeLimit = Instance.new("UITextSizeConstraint")
	textSizeLimit.MaxTextSize = 24
	textSizeLimit.MinTextSize = 12
	textSizeLimit.Parent = button

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	local border = Instance.new("UIStroke")
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Color = Color3.fromRGB(0, 0, 0)
	border.LineJoinMode = Enum.LineJoinMode.Round
	border.Thickness = 2
	border.Parent = button

	setStroke(button, Color3.fromRGB(0, 0, 0), 2)
	return button
end

local function findFrame(name)
	local frame = mainUi:FindFirstChild(name)
	if frame and frame:IsA("GuiObject") then
		return frame
	end
	return nil
end

local function findPath(root, path)
	local current = root
	for _, name in ipairs(path) do
		if not current then return nil end
		current = current:FindFirstChild(name)
	end
	if current and current:IsA("GuiObject") then
		return current
	end
	return nil
end

local function findFirstDescendant(root, names)
	for _, name in ipairs(names) do
		local found = root:FindFirstChild(name, true)
		if found and found:IsA("GuiObject") then
			return found
		end
	end
	return nil
end

local function getTutorialIgnoreGuiInset()
	if mainUi:IsA("ScreenGui") then
		return mainUi.IgnoreGuiInset
	end
	return false
end

local function looksLikeBuyButton(guiObject)
	local name = string.lower(guiObject.Name)
	local text = ""

	if guiObject:IsA("TextButton") or guiObject:IsA("TextLabel") then
		text = string.lower(guiObject.Text)
	end

	return string.find(name, "buy")
		or string.find(name, "purchase")
		or string.find(name, "robux")
		or string.find(text, "buy")
		or string.find(text, "purchase")
		or string.find(text, "robux")
end

local function findBuyButton(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiButton") and descendant.Visible and looksLikeBuyButton(descendant) then
			return descendant
		end
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		local name = string.lower(descendant.Name)
		if descendant:IsA("GuiButton") and descendant.Visible and not string.find(name, "close") then
			return descendant
		end
	end

	return nil
end

local function findFirstGuiButton(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiButton") and descendant.Visible then
			return descendant
		end
	end
	return nil
end

local function isActuallyVisible(guiObject)
	local current = guiObject

	while current and current ~= mainUi do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end

	return true
end

local function getButtonText(button)
	if button:IsA("TextButton") then
		return string.lower(button.Text)
	end

	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			local text = string.lower(descendant.Text)
			if string.find(text, "roll") then
				return text
			end
		end
	end

	return ""
end

local function scoreOpenRollButton(button)
	if not isActuallyVisible(button) then return 0 end

	local rollFrame = findFrame("Roll")
	if rollFrame and button:IsDescendantOf(rollFrame) then
		return 0
	end

	local score = 0
	local name = string.lower(button.Name)
	local text = getButtonText(button)
	local container = button:GetAttribute("Container")
	local functionName = button:GetAttribute("Function")
	local action = button:GetAttribute("Action")

	container = typeof(container) == "string" and string.lower(container) or ""
	functionName = typeof(functionName) == "string" and string.lower(functionName) or ""
	action = typeof(action) == "string" and string.lower(action) or ""

	if name == "roll" then score += 100 end
	if string.find(name, "roll") then score += 40 end
	if functionName == "roll" then score += 100 end
	if string.find(functionName, "roll") then score += 40 end
	if string.find(action, "roll") then score += 40 end
	if string.find(text, "roll") then score += 25 end
	if container == "hud" then score += 10 end

	return score
end

local function findOpenRollButton()
	local bestButton = nil
	local bestScore = 0

	for _, descendant in ipairs(mainUi:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			local score = scoreOpenRollButton(descendant)
			if score > bestScore then
				bestButton = descendant
				bestScore = score
			end
		end
	end

	return bestButton
end

local function findFirstMapCard()
	local mapSelection = findFrame("MapSelection")
	local scrollingFrame = mapSelection and mapSelection:FindFirstChild("ScrollingFrame", true)
	if not scrollingFrame then return nil end

	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("GuiButton") and child.Name ~= "MapTemplate" and child.Visible then
			return child
		end
	end
	return scrollingFrame:IsA("GuiObject") and scrollingFrame or nil
end

local function looksLikeCloseButton(button)
	local name = string.lower(button.Name)
	local text = ""
	local action = button:GetAttribute("Action")

	if button:IsA("TextButton") then
		text = string.lower(button.Text)
	end

	if typeof(action) ~= "string" then
		action = ""
	else
		action = string.lower(action)
	end

	return string.find(name, "close")
		or name == "x"
		or string.find(name, "exit")
		or text == "x"
		or text == "close"
		or string.find(action, "close")
end

local function restoreDisabledCloseButtons()
	for button, state in pairs(disabledCloseButtons) do
		if button and button.Parent then
			button.Active = state.Active
			button.AutoButtonColor = state.AutoButtonColor
			button.Selectable = state.Selectable

			if state.HasInteractable then
				pcall(function()
					button.Interactable = state.Interactable
				end)
			end
		end
	end
	disabledCloseButtons = {}
end

local function disableCloseButtonsForOpenFrames()
	restoreDisabledCloseButtons()

	for _, name in ipairs(GUIDED_FRAME_NAMES) do
		local frame = findFrame(name)
		if frame and frame.Visible then
			for _, descendant in ipairs(frame:GetDescendants()) do
				if descendant:IsA("GuiButton") and descendant.Visible and looksLikeCloseButton(descendant) then
					local hasInteractable, interactable = pcall(function()
						return descendant.Interactable
					end)

					disabledCloseButtons[descendant] = {
						Active = descendant.Active,
						AutoButtonColor = descendant.AutoButtonColor,
						Selectable = descendant.Selectable,
						HasInteractable = hasInteractable,
						Interactable = interactable,
					}
					descendant.Active = false
					descendant.AutoButtonColor = false
					descendant.Selectable = false

					if hasInteractable then
						pcall(function()
							descendant.Interactable = false
						end)
					end
				end
			end
		end
	end
end

local function resolveTarget(step)
	if step.targetDynamic == "FirstMapCard" then
		local dynamicTarget = findFirstMapCard()
		if dynamicTarget then return dynamicTarget end
	elseif step.targetDynamic == "BuyButton" then
		local root = findFrame(step.targetRoot or step.open or "")
		if root then
			return findBuyButton(root)
		end
	elseif step.targetDynamic == "OpenRollButton" then
		return findOpenRollButton()
	end

	local root = findFrame(step.targetRoot or step.open or "")
	if not root then return nil end

	for _, path in ipairs(step.targetCandidates or {}) do
		local target = findPath(root, path)
		if target then return target end
	end

	local descendantNames = {}
	for _, path in ipairs(step.targetCandidates or {}) do
		table.insert(descendantNames, path[#path])
	end

	return findFirstDescendant(root, descendantNames) or findFirstGuiButton(root)
end

local function closeGuidedFrames(exceptName)
	for _, name in ipairs(GUIDED_FRAME_NAMES) do
		if name ~= exceptName then
			local frame = findFrame(name)
			if frame and frame.Visible then
				Effects.ToggleUI(frame, false)
			end
		end
	end
end

local function ensureHudVisible()
	local hud = findFrame("HUD")
	if hud and not hud.Visible then
		Effects.ToggleUI(hud, true)
	end
end

local function openGuidedFrame(name)
	if not name then return nil end

	local frame = findFrame(name)
	if not frame then return nil end

	if not frame.Visible then
		Effects.ToggleUI(frame, true)
	end

	return frame
end

local function setTutorialLayering()
	if mainUi:IsA("ScreenGui") then
		originalMainDisplayOrder = mainUi.DisplayOrder
		mainUi.DisplayOrder = math.max(mainUi.DisplayOrder, 100)
	end
end

local function restoreTutorialLayering()
	if originalMainDisplayOrder ~= nil and mainUi:IsA("ScreenGui") then
		mainUi.DisplayOrder = originalMainDisplayOrder
	end
	originalMainDisplayOrder = nil
end

local function disconnectTargetClick()
	if targetClickConnection then
		targetClickConnection:Disconnect()
		targetClickConnection = nil
	end
end

local function connectTargetClick()
	disconnectTargetClick()

	if not currentStep or not currentStep.passThroughClick then return end
	if not currentTarget or not currentTarget:IsA("GuiButton") then return end

	targetClickConnection = currentTarget.MouseButton1Click:Connect(function()
		if waitingForStepClick then
			advanceFromRequiredClick()
		end
	end)
end

local function releaseRequiredClickFallback()
	if not waitingForStepClick then return end

	waitingForStepClick = false
	disconnectTargetClick()

	if nextButton then
		nextButton.Text = if currentStepIndex == #LOBBY_TUTORIAL_STEPS then "DONE" else "NEXT"
		nextButton.Active = true
		nextButton.AutoButtonColor = true
		nextButton.BackgroundColor3 = Color3.fromRGB(255, 199, 58)
	end
end

local function updateHighlight()
	if not highlight or not clickBlocker or not tutorialRoot then return end

	if not currentTarget or not currentTarget:IsDescendantOf(game) or not currentTarget.Visible then
		highlight.Visible = false
		clickBlocker.Visible = false
		releaseRequiredClickFallback()
		return
	end

	local size = currentTarget.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		highlight.Visible = false
		clickBlocker.Visible = false
		releaseRequiredClickFallback()
		return
	end

	local padding = currentStep and currentStep.targetPadding or 8
	local position = currentTarget.AbsolutePosition
	local rootPosition = tutorialRoot.AbsolutePosition
	local relativePosition = Vector2.new(position.X - rootPosition.X, position.Y - rootPosition.Y)
	local highlightPosition = UDim2.fromOffset(relativePosition.X - padding, relativePosition.Y - padding)
	local highlightSize = UDim2.fromOffset(size.X + padding * 2, size.Y + padding * 2)

	highlight.Visible = true
	highlight.Position = highlightPosition
	highlight.Size = highlightSize

	local shouldBlockClick = waitingForStepClick and not (currentStep and currentStep.passThroughClick)
	clickBlocker.Visible = shouldBlockClick
	clickBlocker.Position = highlightPosition
	clickBlocker.Size = highlightSize

	if panel then
		local viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
		local targetCenterY = position.Y + size.Y / 2

		if targetCenterY > viewportSize.Y * 0.52 then
			panel.AnchorPoint = Vector2.new(0.5, 0)
			panel.Position = UDim2.new(0.5, 0, 0.08, 0)
		else
			panel.AnchorPoint = Vector2.new(0.5, 1)
			panel.Position = UDim2.new(0.5, 0, 0.94, 0)
		end
	end
end

local function destroyTutorialGui()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end

	if tutorialGui then
		tutorialGui:Destroy()
		tutorialGui = nil
	end

	if backdropGui then
		backdropGui:Destroy()
		backdropGui = nil
	end

	overlay = nil
	tutorialRoot = nil
	highlight = nil
	clickBlocker = nil
	panel = nil
	titleLabel = nil
	bodyLabel = nil
	counterLabel = nil
	nextButton = nil
	skipButton = nil
	currentTarget = nil
	disconnectTargetClick()
end

local function finishLobbyTutorial()
	if not tutorialRunning then return end

	tutorialRunning = false
	currentStepIndex = 0
	currentStepRequiresClick = false
	waitingForStepClick = false
	currentStep = nil
	disconnectTargetClick()
	restoreDisabledCloseButtons()
	closeGuidedFrames(nil)
	ensureHudVisible()
	destroyTutorialGui()
	restoreTutorialLayering()
end

local function showStep(index)
	if not tutorialRunning then return end

	local step = LOBBY_TUTORIAL_STEPS[index]
	if not step then
		finishLobbyTutorial()
		return
	end

	currentStepIndex = index
	currentStep = step
	currentStepRequiresClick = step.requireClick == true
	waitingForStepClick = false
	disconnectTargetClick()
	restoreDisabledCloseButtons()

	closeGuidedFrames(step.open)
	if not step.skipHudEnsure then
		ensureHudVisible()
	end

	local openedFrame = openGuidedFrame(step.open)
	task.wait(openedFrame and 0.45 or 0)
	disableCloseButtonsForOpenFrames()

	currentTarget = resolveTarget(step)
	waitingForStepClick = currentStepRequiresClick and currentTarget ~= nil
	connectTargetClick()

	titleLabel.Text = step.title
	bodyLabel.Text = step.body
	counterLabel.Text = string.format("%d/%d", index, #LOBBY_TUTORIAL_STEPS)

	if waitingForStepClick then
		nextButton.Text = step.clickText or "CLICK IT"
		nextButton.Active = false
		nextButton.AutoButtonColor = false
		nextButton.BackgroundColor3 = Color3.fromRGB(84, 92, 122)
	else
		nextButton.Text = if index == #LOBBY_TUTORIAL_STEPS then "DONE" else "NEXT"
		nextButton.Active = true
		nextButton.AutoButtonColor = true
		nextButton.BackgroundColor3 = Color3.fromRGB(255, 199, 58)
	end

	updateHighlight()
end

function advanceFromRequiredClick()
	if not waitingForStepClick then return end

	waitingForStepClick = false
	disconnectTargetClick()
	nextButton.Text = "DONE"
	nextButton.BackgroundColor3 = Color3.fromRGB(92, 202, 116)
	updateHighlight()

	task.delay(currentStep and currentStep.advanceDelay or 0.25, function()
		showStep(currentStepIndex + 1)
	end)
end

local function createBackdropGui()
	backdropGui = Instance.new("ScreenGui")
	backdropGui.Name = "LobbyTutorialBackdropGui"
	backdropGui.ResetOnSpawn = false
	backdropGui.IgnoreGuiInset = getTutorialIgnoreGuiInset()
	backdropGui.DisplayOrder = if mainUi:IsA("ScreenGui") then mainUi.DisplayOrder - 1 else 90
	backdropGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	backdropGui.Parent = playerGui

	overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 1
	overlay.Parent = backdropGui
end

local function createLobbyTutorialGui()
	destroyTutorialGui()
	setTutorialLayering()
	createBackdropGui()

	tutorialGui = Instance.new("ScreenGui")
	tutorialGui.Name = "LobbyTutorialGui"
	tutorialGui.ResetOnSpawn = false
	tutorialGui.IgnoreGuiInset = getTutorialIgnoreGuiInset()
	tutorialGui.DisplayOrder = if mainUi:IsA("ScreenGui") then mainUi.DisplayOrder + 50 else 150
	tutorialGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	tutorialGui.Parent = playerGui

	tutorialRoot = Instance.new("Frame")
	tutorialRoot.Name = "Root"
	tutorialRoot.Size = UDim2.fromScale(1, 1)
	tutorialRoot.BackgroundTransparency = 1
	tutorialRoot.BorderSizePixel = 0
	tutorialRoot.ZIndex = 1
	tutorialRoot.Parent = tutorialGui

	highlight = Instance.new("Frame")
	highlight.Name = "Highlight"
	highlight.BackgroundTransparency = 1
	highlight.Visible = false
	highlight.ZIndex = 3
	highlight.Parent = tutorialRoot

	local highlightCorner = Instance.new("UICorner")
	highlightCorner.CornerRadius = UDim.new(0, 12)
	highlightCorner.Parent = highlight

	local highlightStroke = Instance.new("UIStroke")
	highlightStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	highlightStroke.Color = Color3.fromRGB(255, 218, 74)
	highlightStroke.LineJoinMode = Enum.LineJoinMode.Round
	highlightStroke.Thickness = 3
	highlightStroke.Parent = highlight

	clickBlocker = Instance.new("TextButton")
	clickBlocker.Name = "ClickBlocker"
	clickBlocker.BackgroundTransparency = 1
	clickBlocker.BorderSizePixel = 0
	clickBlocker.Text = ""
	clickBlocker.Visible = false
	clickBlocker.ZIndex = 4
	clickBlocker.Parent = tutorialRoot
	clickBlocker.MouseButton1Click:Connect(advanceFromRequiredClick)

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Size = UDim2.new(0.5, 0, 0, 136)
	panel.Position = UDim2.new(0.5, 0, 0.94, 0)
	panel.BackgroundColor3 = Color3.fromRGB(14, 18, 32)
	panel.BorderSizePixel = 0
	panel.ZIndex = 5
	panel.Parent = tutorialRoot

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = panel

	local panelGradient = Instance.new("UIGradient")
	panelGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(29, 38, 70)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 18, 32)),
	})
	panelGradient.Rotation = 0
	panelGradient.Parent = panel

	local panelBorder = Instance.new("UIStroke")
	panelBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	panelBorder.Color = Color3.fromRGB(255, 207, 74)
	panelBorder.LineJoinMode = Enum.LineJoinMode.Round
	panelBorder.Thickness = 2
	panelBorder.Parent = panel

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -168, 0, 36)
	titleLabel.Position = UDim2.new(0, 20, 0, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 235, 104)
	titleLabel.TextScaled = true
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.FontFace = TUTORIAL_FONT
	titleLabel.ZIndex = 6
	titleLabel.Parent = panel
	setStroke(titleLabel, Color3.fromRGB(0, 0, 0), 2)

	local titleTextLimit = Instance.new("UITextSizeConstraint")
	titleTextLimit.MaxTextSize = 28
	titleTextLimit.MinTextSize = 14
	titleTextLimit.Parent = titleLabel

	counterLabel = Instance.new("TextLabel")
	counterLabel.Name = "Counter"
	counterLabel.Size = UDim2.new(0, 70, 0, 26)
	counterLabel.Position = UDim2.new(1, -90, 0, 14)
	counterLabel.BackgroundTransparency = 1
	counterLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	counterLabel.TextScaled = true
	counterLabel.FontFace = TUTORIAL_FONT
	counterLabel.ZIndex = 6
	counterLabel.Parent = panel
	setStroke(counterLabel, Color3.fromRGB(0, 0, 0), 2)

	local counterTextLimit = Instance.new("UITextSizeConstraint")
	counterTextLimit.MaxTextSize = 24
	counterTextLimit.MinTextSize = 12
	counterTextLimit.Parent = counterLabel

	bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "Body"
	bodyLabel.Size = UDim2.new(1, -40, 0, 42)
	bodyLabel.Position = UDim2.new(0, 20, 0, 48)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	bodyLabel.TextScaled = true
	bodyLabel.TextWrapped = true
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.FontFace = TUTORIAL_FONT
	bodyLabel.ZIndex = 6
	bodyLabel.Parent = panel
	setStroke(bodyLabel, Color3.fromRGB(0, 0, 0), 2)

	local bodyTextLimit = Instance.new("UITextSizeConstraint")
	bodyTextLimit.MaxTextSize = 20
	bodyTextLimit.MinTextSize = 12
	bodyTextLimit.Parent = bodyLabel

	skipButton = makeTextButton("Skip", "SKIP", UDim2.new(0, 104, 0, 34), UDim2.new(0, 20, 1, -44))
	skipButton.BackgroundColor3 = Color3.fromRGB(84, 92, 122)
	skipButton.ZIndex = 6
	skipButton.Parent = panel

	nextButton = makeTextButton("Next", "NEXT", UDim2.new(0, 146, 0, 34), UDim2.new(1, -166, 1, -44))
	nextButton.ZIndex = 6
	nextButton.Parent = panel

	skipButton.MouseButton1Click:Connect(finishLobbyTutorial)
	nextButton.MouseButton1Click:Connect(function()
		if waitingForStepClick then return end
		showStep(currentStepIndex + 1)
	end)

	renderConnection = RunService.RenderStepped:Connect(updateHighlight)
end

local function startLobbyTutorial()
	if tutorialRunning then return end

	tutorialRunning = true
	createLobbyTutorialGui()
	closeGuidedFrames(nil)
	ensureHudVisible()

	TweenService:Create(
		overlay,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.55 }
	):Play()

	showStep(1)
end

ServerEvents.OnClientEvent:Connect(function(action)
	if action == "StartLobbyTutorial" then
		startLobbyTutorial()
	end
end)
