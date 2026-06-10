local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local GradientTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local HUD = player.PlayerGui:WaitForChild("UI", 10):WaitForChild("HUD", 10)

script.Parent.MouseButton1Click:Connect(function()
	script.Enabled = false
	script.Parent.Parent.Parent.Parent.MainLoadingSequenceConfig.Enabled = false
	TweenService:Create(script.Parent.Parent.Parent.Parent.Parent.UIGradient, GradientTweenInfo, {Offset = Vector2.new(-1,0)}):Play()
	print("Asset loading skipped.")
	wait(1)

	if HUD then HUD.Interactable = true end
	script.Parent.Parent.Parent.Parent.Parent.Visible = false
	script.Parent.Parent.Parent.Parent.Parent.UIGradient:Destroy()
	script.Parent.Parent.Parent.Parent.Parent.Parent:Destroy()
end)