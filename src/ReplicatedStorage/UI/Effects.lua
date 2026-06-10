local Effects = {}

--Services
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Folders
local Modules = ReplicatedStorage:WaitForChild("Modules")


--Tables/Variables
local originalSize = {}
local activeTweens = {}
local isHovering = {}

--Constants
local TWEEN_INFO = {
	Hover = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
	Click = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, true),
	Toggle = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Toggle_Close = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In),
	Swap = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
}

local SCALES = {
	Hover = 1.1,
	Click = 0.9,
	Icon_Rotation = 10
}

--local openedUI = nil

--Helper functions
local function cancelActiveTweens(button: GuiButton)
	if activeTweens[button] then
		if activeTweens[button].button then
			activeTweens[button].button:Cancel()
		end
		
		if activeTweens[button].icon then
			activeTweens[button].icon:Cancel()
		end
		activeTweens[button] = nil
	end
end


local function tweenIcon(icon: GuiObject, rotation: number, tweenInfo: TweenInfo, button: GuiButton)
	local tween = TweenService:Create(icon, tweenInfo, {Rotation = rotation})

	if not activeTweens[button] then
		activeTweens[button] = {}
	end
	activeTweens[button].icon = tween

	tween:Play()
	tween.Completed:Once(function()
		if activeTweens[button] and activeTweens[button].icon == tween then
			activeTweens[button].icon = nil
		end
	end)
end


local function tweenButton(button: GuiButton, targetSize: UDim2, tweenInfo: TweenInfo): Tween
	local tween = TweenService:Create(button, tweenInfo, {Size = targetSize})

	if not activeTweens[button] then
		activeTweens[button] = {}
	end
	activeTweens[button].button = tween

	tween:Play()
	tween.Completed:Once(function()
		if activeTweens[button] and activeTweens[button].button == tween then
			activeTweens[button].button = nil
		end
	end)

	return tween
end

local function scaleSize(baseSize: UDim2|GuiObject, scale: number): UDim2
	if typeof(baseSize) ~= "UDim2" and baseSize.Size then
		baseSize = baseSize.Size
	end
	
	return UDim2.new(
		baseSize.X.Scale * scale,
		baseSize.X.Offset * scale,
		baseSize.Y.Scale * scale,
		baseSize.Y.Offset * scale
	)
end

local function cleanup(button: GuiButton)
	cancelActiveTweens(button)
	originalSize[button] = nil
	isHovering[button] = nil
end

--Basics Effects
function Effects.MouseEnter(button: GuiButton)
	if not originalSize[button] then
		originalSize[button] = button.Size
	end
	
	isHovering[button] = true
	cancelActiveTweens(button)
	
	local scaleSize = scaleSize(originalSize[button], SCALES.Hover)
	tweenButton(button, scaleSize, TWEEN_INFO.Hover)
	
	local icon = button:FindFirstChild("Icon") 
	if icon then
		tweenIcon(icon, SCALES.Icon_Rotation, TWEEN_INFO.Hover, button)
	end
	
end

function Effects.MouseLeave(button: GuiButton) 
	if not originalSize[button] then
		warn(`[Effects] - {button} original size not found`)
		return
	end

	isHovering[button] = false
	cancelActiveTweens(button)

	tweenButton(button, originalSize[button], TWEEN_INFO.Hover)

	local icon = button:FindFirstChild("Icon") 
	if icon then
		tweenIcon(icon, 0, TWEEN_INFO.Hover, button)
	end
end

function Effects.Click(button: GuiButton)
	if not originalSize[button] then
		warn(`[Effects] - {button} original size not found`)
		return
	end
	
	cancelActiveTweens(button)
	
	local scaleSize = scaleSize(originalSize[button], SCALES.Click)
	local tween = tweenButton(button, scaleSize, TWEEN_INFO.Click)
	game.ReplicatedStorage.UISoundEffects.Click:Play()

	tween.Completed:Once(function()
		if isHovering[button] then
			Effects.MouseEnter(button)
		end
	end)
	
end

function Effects.GrowUp(object: GuiObject)
	if not object.Visible then object.Visible = true end
	
	local oldSize = object.Size
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	
	object.Size = UDim2.fromScale(0, 0)
	local tween = TweenService:Create(object, tweenInfo, {Size = oldSize})
	tween:Play()
end 

function Effects.ToggleUI(frame: Frame, forceState: boolean?)
	local isOpening = if forceState ~= nil then forceState else not frame.Visible
	if frame.Visible == isOpening and not activeTweens[frame] then
		return
	end

	if activeTweens[frame] then activeTweens[frame]:Cancel() end

	-- Salva a posição original do frame (só uma vez)
	if not originalSize[frame] then
		originalSize[frame] = frame.Position  -- reutiliza a tabela pra guardar posição também
	end
	local targetPosition = originalSize[frame]  -- posição onde ele deve ficar aberto

	if isOpening then
		frame.Visible = true
		frame.Position = UDim2.new(1.5, 0, 0.5, 0)
	end

	local finalPosition = isOpening and targetPosition or UDim2.new(1.5, 0, 0.5, 0)

	local tween = TweenService:Create(frame, TWEEN_INFO.Toggle, {Position = finalPosition})

	activeTweens[frame] = tween
	tween:Play()

	tween.Completed:Once(function(playerbackState)
		if playerbackState == Enum.PlaybackState.Completed then
			if not isOpening then
				frame.Visible = false
			end
			activeTweens[frame] = nil
		end
	end)
end

function Effects.StoreOriginalPosition(frame: Frame)
	if not originalSize[frame] then
		originalSize[frame] = frame.Position
	end
end

function Effects.Shake(object: GuiObject, duration: number?, intensity: number?, speed: number?)
	local shakeDuration = duration or 1
	local shakeIntensity = intensity or 5
	local shakeSpeed = speed or 0.05

	local parent = object.Parent
	local layoutOrder = object.LayoutOrder
	local originalSize = object.Size
	local originalPosition = object.Position
	local originalAnchorPoint = object.AnchorPoint

	local wrapper = Instance.new("Frame")
	wrapper.Size = originalSize
	wrapper.Position = originalPosition
	wrapper.AnchorPoint = originalAnchorPoint
	wrapper.BackgroundTransparency = 1
	wrapper.Name = "ShakeWrapper"
	wrapper.LayoutOrder = layoutOrder
	wrapper.Parent = parent

	object.Parent = wrapper
	object.Position = UDim2.fromScale(0.5, 0.5)
	object.AnchorPoint = Vector2.new(0.5, 0.5)
	object.Size = UDim2.fromScale(1, 1)
	object.LayoutOrder = 0

	local originalRotation = object.Rotation
	local shaking = true

	task.spawn(function()
		while shaking do
			local randomRotation = math.random(-shakeIntensity, shakeIntensity)
			object.Rotation = randomRotation
			task.wait(shakeSpeed)
		end
		object.Rotation = originalRotation
	end)

	task.wait(shakeDuration)

	shaking = false
	object.Rotation = originalRotation

	object.Parent = parent
	object.Size = originalSize
	object.Position = originalPosition
	object.AnchorPoint = originalAnchorPoint
	object.LayoutOrder = layoutOrder

	wrapper:Destroy()
end

function Effects.ShakeAndDesappear(object: GuiObject)
	local shakeTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, - 1, true)
	
	local icon = object:FindFirstChild("Icon")
	local targetObject = icon or object

	targetObject.Rotation = -30 
	local shakeTween = TweenService:Create(targetObject, shakeTweenInfo, {Rotation = 30})
	shakeTween:Play()

	task.wait(1.2)
	shakeTween:Cancel()

	local dissapearTween = TweenService:Create(targetObject, TweenInfo.new(0.5), {Size = UDim2.fromScale(0,0)})
	dissapearTween:Play()
	dissapearTween.Completed:Wait()

	object.Visible = false
end

function Effects.SwapGuiObject(buttonToSwap: GuiObject, newButton: GuiObject)
	if not originalSize[newButton] then
		originalSize[newButton] = newButton.Size
	end
	
	local swapButtonSize = originalSize[newButton]
	local fadeOut = TweenService:Create(buttonToSwap, TWEEN_INFO.Swap, {Size = UDim2.new(0,0,0,0)})
	fadeOut:Play()

	fadeOut.Completed:Once(function()
		buttonToSwap.Visible = false
		newButton.Visible = true
		newButton.Size = UDim2.new(0,0,0,0)

		local fadeIn = TweenService:Create(newButton, TWEEN_INFO.Swap, {Size = swapButtonSize})
		fadeIn:Play()
	end)
end

function Effects.Cleanup(button: GuiButton)
	cleanup(button)
end

return Effects
