local TweenService = game:GetService("TweenService")
local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.In)

while true do
	script.Parent.Rotation = 0
	TweenService:Create(script.Parent, tweenInfo, {Rotation = 360}):Play()
	wait(1)
end