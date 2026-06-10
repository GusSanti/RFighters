local ScreenTransition = {}

local TweenService = game:GetService("TweenService")
local Blackout  -- injetado via Init

function ScreenTransition.Init(blackoutFrame)
	Blackout = blackoutFrame
end

function ScreenTransition.FadeIn(callback)
	Blackout.BackgroundTransparency = 1
	Blackout.Visible = true
	local tween = TweenService:Create(Blackout,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0 })
	tween:Play()
	tween.Completed:Once(function()
		if callback then callback() end
	end)
end

function ScreenTransition.FadeOut()
	local tween = TweenService:Create(Blackout,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Once(function()
		Blackout.Visible = false
		Blackout.BackgroundTransparency = 0
	end)
end

return ScreenTransition