local TweenService = game:GetService("TweenService")
local TweenSpeed = 0.1
local Info = TweenInfo.new(TweenSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0)

local frame = script.Parent.Parent

-- Button --

script.Parent.MouseEnter:Connect(function()
	local Color = Color3.fromRGB(255, 255, 255)
	TweenService:Create(frame, Info, {BackgroundColor3 = Color}):Play()
end)

script.Parent.MouseLeave:Connect(function()
	local ColorColor = Color3.fromRGB(25,25,25)
	TweenService:Create(frame, Info, {BackgroundColor3 = ColorColor}):Play()
end)

-- Text --

script.Parent.MouseEnter:Connect(function()
	local Color = Color3.fromRGB(0,0,0)
	TweenService:Create(script.Parent.Parent.Text, Info, {TextColor3 = Color}):Play()
end)

script.Parent.MouseLeave:Connect(function()
	local ColorColor = Color3.fromRGB(255, 255, 255)
	TweenService:Create(script.Parent.Parent.Text, Info, {TextColor3 = ColorColor}):Play()
end)