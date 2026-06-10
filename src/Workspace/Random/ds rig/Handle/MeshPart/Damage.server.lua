s = script.Parent.Parent.Parent.Config.AttackDamage.Value
function onTouched(part)
	local tool = script.Parent.Parent.Parent

	local h = part.Parent:findFirstChild("Humanoid")

	local humanoid = part.Parent:FindFirstChild("Humanoid")

	local animation = script.Parent.Parent.Parent.Animations.Hit

	local animationtrack = humanoid:LoadAnimation(animation)

	local sound = tool.Sounds.Hit

	if h~=nil then
		h.Health = h.Health -(s) 
		sound:Play()
		animationtrack:Play()
		script.Disabled = true
	end
end

script.Parent.Touched:Connect(onTouched)