local Streak = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local MainUI = PlayerGui:WaitForChild("UI")
local CombatHUD = MainUI:WaitForChild("CombatHUD")
local StreakText = CombatHUD:WaitForChild("StreakText")
local SendDamageIndicator = ReplicatedStorage.Events:WaitForChild("SendDamageIndicator")
local ImageLabelContainer = StreakText:WaitForChild("ImageLabel")
local TimerBar = ImageLabelContainer:WaitForChild("TimerBar")
local TimerFill = TimerBar:WaitForChild("Fill")
local TimerGradient = TimerFill:WaitForChild("UIGradient")
local MultiplierLabel = ImageLabelContainer:WaitForChild("Multiplier") -- ADICIONADO

local NumberLabels = {}
for i = 0, 9 do
	local label = ImageLabelContainer:FindFirstChild(tostring(i))
	if label then
		NumberLabels[i] = label
	end
end

local TweenCache = {}

local currentStreak = 0
local resetThread = nil
local timerThread = nil
local isResetting = false

local STREAK_RESET_TIME = 1.5
local FADE_OUT_TIME = 0.35

local PUNCH_TWEEN_INFO = TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADEOUT_TWEEN_INFO = TweenInfo.new(FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local GRADIENT_TWEEN_INFO = TweenInfo.new(STREAK_RESET_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.In)

local gradientTween = nil

local function tweenProperty(obj, info, props)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

local function destroyAllClones()
	for _, child in ipairs(ImageLabelContainer:GetChildren()) do
		if child:GetAttribute("IsClone") then
			child:Destroy()
		end
	end
end

local function hideAll()
	for i = 0, 9 do
		if NumberLabels[i] then
			NumberLabels[i].Visible = false
			NumberLabels[i].Size = UDim2.new(1, 0, 1, 0)
			NumberLabels[i].ImageTransparency = 0
		end
	end
	destroyAllClones()
	ImageLabelContainer.Size = UDim2.new(1, 0, 1, 0)
	ImageLabelContainer.ImageTransparency = 0
	StreakText.Visible = false
	TimerBar.Visible = false
	TimerGradient.Offset = Vector2.new(0, 0)
	MultiplierLabel.Text = "" -- ADICIONADO: limpa o texto ao esconder
end

local function warmupTween(digit, totalDigits, index)
	local slotWidth = 1 / totalDigits

	local targetPos  = UDim2.new(slotWidth * (index - 1), 0, 0, 0)
	local targetSize = UDim2.new(slotWidth, 0, 1, 0)
	local punchSize  = UDim2.new(slotWidth * 1.25, 0, 1.25, 0)
	local punchPos   = UDim2.new(slotWidth * (index - 1) - (slotWidth * 0.125), 0, -0.125, 0)

	local originalLabel = NumberLabels[digit]
	if not originalLabel then return end

	local clone = originalLabel:Clone()
	clone:SetAttribute("IsWarmup", true)
	clone.Visible = false
	clone.Size = punchSize
	clone.Position = punchPos
	clone.Parent = ImageLabelContainer

	local tweenIn = TweenService:Create(clone, PUNCH_TWEEN_INFO, {
		Size = targetSize,
		Position = targetPos,
	})

	local tweenOut = TweenService:Create(clone, FADEOUT_TWEEN_INFO, {
		ImageTransparency = 1,
		Size = UDim2.new(slotWidth, 0, 0.5, 0),
		Position = UDim2.new(slotWidth * (index - 1), 0, 0.25, 0),
	})

	clone:Destroy()

	local key = string.format("%d_%d_%d", digit, totalDigits, index)
	TweenCache[key] = true
end

local function preloadAllTweens()
	for digit = 0, 9 do
		warmupTween(digit, 1, 1)
	end

	for digit = 0, 9 do
		warmupTween(digit, 2, 1)
		warmupTween(digit, 2, 2)
	end

	for digit = 0, 9 do
		warmupTween(digit, 3, 1)
		warmupTween(digit, 3, 2)
		warmupTween(digit, 3, 3)
	end
end

local function getDigits(number)
	local digits = {}
	for d in tostring(number):gmatch("%d") do
		table.insert(digits, tonumber(d))
	end
	return digits
end

local function startTimerBar()
	if gradientTween then
		gradientTween:Cancel()
		gradientTween = nil
	end

	TimerGradient.Offset = Vector2.new(0, 0)
	TimerBar.Visible = true

	gradientTween = TweenService:Create(TimerGradient, GRADIENT_TWEEN_INFO, {
		Offset = Vector2.new(1, 0)
	})
	gradientTween:Play()
end

local function showStreak(streakCount)
	isResetting = false
	destroyAllClones()	

	StreakText.Visible = true
	ImageLabelContainer.ImageTransparency = 0
	ImageLabelContainer.Visible = true

	local digits = getDigits(streakCount)
	local totalDigits = #digits
	local slotWidth = 1 / totalDigits

	for index, digit in ipairs(digits) do
		local originalLabel = NumberLabels[digit]
		if not originalLabel then
			warn("NumberLabel não encontrado para dígito:", digit)
			continue
		end

		local targetPos = UDim2.new(slotWidth * (index - 1), 0, 0, 0)
		local targetSize = UDim2.new(slotWidth, 0, 1, 0)
		local punchSize  = UDim2.new(slotWidth * 1.25, 0, 1.25, 0)
		local punchPos   = UDim2.new(slotWidth * (index - 1) - (slotWidth * 0.125), 0, -0.125, 0)

		local clone = originalLabel:Clone()
		clone:SetAttribute("IsClone", true)
		clone.Visible = true
		clone.ImageTransparency = 0
		clone.Size = punchSize
		clone.Position = punchPos
		clone.Parent = ImageLabelContainer

		tweenProperty(clone, PUNCH_TWEEN_INFO, {
			Size = targetSize,
			Position = targetPos,
		})
	end
end

local function resetStreak()
	isResetting = true

	if gradientTween then
		gradientTween:Cancel()
		gradientTween = nil
	end

	for _, child in ipairs(ImageLabelContainer:GetChildren()) do
		if child:GetAttribute("IsClone") then
			tweenProperty(child, FADEOUT_TWEEN_INFO, {
				ImageTransparency = 1,
				Size = UDim2.new(child.Size.X.Scale, 0, 0.5, 0),
				Position = UDim2.new(child.Position.X.Scale, 0, 0.25, 0),
			})
		end
	end

	task.delay(FADE_OUT_TIME + 0.05, function()
		if isResetting then
			currentStreak = 0
			hideAll()
		end
	end)
end

local function onHit(multiplier) -- ADICIONADO: recebe multiplier
	currentStreak = currentStreak + 1

	if resetThread then
		task.cancel(resetThread)
		resetThread = nil
	end

	showStreak(currentStreak)
	startTimerBar()

	-- ADICIONADO: atualiza o texto do multiplier
	if multiplier then
		MultiplierLabel.Text = string.format("%.2f", multiplier) .. "x"
	end

	resetThread = task.delay(STREAK_RESET_TIME, function()
		resetStreak()
	end)
end

function Streak.Init()
	hideAll()

	task.defer(function()
		preloadAllTweens()
	end)

	SendDamageIndicator.OnClientEvent:Connect(function(multiplier) -- ADICIONADO: recebe multiplier
		warn('CLIENT ON HIT DAMAGE INDICATOR')
		onHit(multiplier)
	end)
end

return Streak