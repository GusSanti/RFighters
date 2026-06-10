local ms = game.Players.LocalPlayer:GetMouse()

local btn = script.Parent.Button
local sample = script:WaitForChild("Sample")


local Players = game:GetService("Players")
local player = Players.LocalPlayer -- Obtém o jogador local

local ReplicatedStorage = game.ReplicatedStorage

local TweenService = game:GetService("TweenService")
local ButtonTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out) -- Animação dos botões

script.Parent.Button.MouseButton1Click:Connect(function()
	
	local c = sample:Clone()
	c.Parent = btn
	local x, y = (ms.X - c.AbsolutePosition.X), (ms.Y - c.AbsolutePosition.Y)
	c.Position = UDim2.new(0, x, 0, y)
	local len, size = 0.35, nil
	if btn.AbsoluteSize.X >= btn.AbsoluteSize.Y then
		size = (btn.AbsoluteSize.X * 1.5)
	else
		size = (btn.AbsoluteSize.Y * 1.5)
	end
	c:TweenSizeAndPosition(UDim2.new(0, size, 0, size), UDim2.new(0.5, (-size / 2), 0.5, (-size / 2)), 'Out', 'Quad', len, true, nil)
	for i = 1, 10 do
		c.ImageTransparency = c.ImageTransparency + 0.05
		wait(len / 12)
	end
	c:Destroy()
end)