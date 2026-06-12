local RewardNotificationModule = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local NotificationRemoteEvent = ReplicatedStorage.Events.Notification.NotificationRemoteEvents

local ACTION_NAME = "LockedRewardNotification"
local DEFAULT_MESSAGE = "YOU CANNOT REDEEM THIS REWARD YET!"

local GUI_NAME = "RewardNotificationGui"
local LABEL_NAME = "LockedRewardLabel"

local SHOW_DURATION = 2.2
local showToken = 0

local function sanitizeMessage(message)
	local finalMessage = type(message) == "string" and message or DEFAULT_MESSAGE
	finalMessage = finalMessage:gsub("%s+$", "")

	if finalMessage == "" then
		finalMessage = DEFAULT_MESSAGE
	end

	if finalMessage:sub(-1) ~= "!" then
		finalMessage ..= "!"
	end

	return string.upper(finalMessage)
end

if RunService:IsServer() then
	function RewardNotificationModule.NotifyLockedReward(player, message)
		if not player then
			return
		end

		NotificationRemoteEvent:FireClient(player, ACTION_NAME, sanitizeMessage(message))
	end

	return RewardNotificationModule
end

local function ensureLabel()
	local player = Players.LocalPlayer
	local playerGui = player and player:WaitForChild("PlayerGui")
	if not playerGui then
		return nil
	end

	local screenGui = playerGui:FindFirstChild(GUI_NAME)
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = GUI_NAME
		screenGui.DisplayOrder = 1000
		screenGui.IgnoreGuiInset = true
		screenGui.ResetOnSpawn = false
		screenGui.Parent = playerGui
	end

	local label = screenGui:FindFirstChild(LABEL_NAME)
	if not label then
		label = Instance.new("TextLabel")
		label.Name = LABEL_NAME
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Bangers
		label.Position = UDim2.fromScale(0.5, 0.14)
		label.Size = UDim2.fromScale(0.75, 0.08)
		label.TextColor3 = Color3.fromRGB(255, 48, 48)
		label.TextScaled = true
		label.TextStrokeColor3 = Color3.fromRGB(70, 0, 0)
		label.TextStrokeTransparency = 1
		label.TextTransparency = 1
		label.Visible = false
		label.ZIndex = 20
		label.Parent = screenGui

		local textSizeConstraint = Instance.new("UITextSizeConstraint")
		textSizeConstraint.MinTextSize = 22
		textSizeConstraint.MaxTextSize = 40
		textSizeConstraint.Parent = label
	end

	return label
end

function RewardNotificationModule.ShowLockedReward(message)
	local label = ensureLabel()
	if not label then
		return
	end

	showToken += 1
	local currentToken = showToken

	label.Text = sanitizeMessage(message)
	label.Position = UDim2.fromScale(0.5, 0.14)
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	label.Visible = true

	TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.12),
		TextTransparency = 0,
		TextStrokeTransparency = 0.2,
	}):Play()

	task.delay(SHOW_DURATION, function()
		if currentToken ~= showToken or not label.Parent then
			return
		end

		local fadeOut = TweenService:Create(label, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(0.5, 0.1),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})

		fadeOut:Play()
		fadeOut.Completed:Wait()

		if currentToken == showToken and label.Parent then
			label.Visible = false
		end
	end)
end

NotificationRemoteEvent.OnClientEvent:Connect(function(action, payload)
	if action ~= ACTION_NAME then
		return
	end

	RewardNotificationModule.ShowLockedReward(payload)
end)

return RewardNotificationModule
