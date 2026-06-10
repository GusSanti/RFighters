local cs = game:GetService("CollectionService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")

local SOURCE_LOCALE = "en"
local translator = nil


local Misc = {}

Misc.StrongKnockback = function(target, strength1, strength2, duration, Origin)
	local EffectVelocity = Instance.new("BodyVelocity", target)
	EffectVelocity.MaxForce = Vector3.new(1.2, 2.5, 1.2) * 1000000;
	EffectVelocity.Velocity = Vector3.new(1.2, 2.5, 1.2) * Origin.CFrame.LookVector * math.random(strength1, strength2)

	game.Debris:AddItem(EffectVelocity, duration)
end

Misc.TweenNumber = function(TextInstance, NumberVal, Duration, DesiredValue, BeforeText, AfterText)
	local part = NumberVal

	local tweenInfo = TweenInfo.new(
		1,
		Enum.EasingStyle.Linear, 
		Enum.EasingDirection.Out, 
		1, 
		false, 
		0 
	)

	local tween = game.TweenService:Create(part, tweenInfo, {Value = DesiredValue})

	tween:Play()

	part.Changed:Connect(function(val)
		if not BeforeText and not AfterText then
			TextInstance.Text = tonumber(math.round(val))
		elseif BeforeText and not AfterText then
			TextInstance.Text = BeforeText..tonumber(math.round(val))
		elseif not BeforeText and AfterText then
			TextInstance.Text = tonumber(math.round(val))..AfterText
		elseif BeforeText and AfterText then
			TextInstance.Text = BeforeText..tonumber(math.round(val))..AfterText
		end
	end)
end

Misc.InsertDisabled = function(Target, Duration)
	local disabled = Instance.new("BoolValue")
	disabled.Name = "Disabled"
	
	disabled.Parent = Target
	
	game.Debris:AddItem(disabled, Duration)
end

Misc.UpKnockback = function(target, strength1, strength2, duration, Origin)
	local EffectVelocity = Instance.new("BodyVelocity", target)
	EffectVelocity.MaxForce = Vector3.new(1, 1, 1) * 1000000;
	EffectVelocity.Velocity = Vector3.new(1, 1, 1) * Origin.CFrame.UpVector * math.random(strength1, strength2)

	game.Debris:AddItem(EffectVelocity, duration)
end

Misc.Ragdoll = function(Target, Duration)

	local ragVal = Instance.new("BoolValue")
	ragVal.Name = "Ragdoll"
	
	Misc.InsertDisabled(Target, Duration)
	
	ragVal.Parent = Target

	game.Debris:AddItem(ragVal, Duration)
end




return Misc
