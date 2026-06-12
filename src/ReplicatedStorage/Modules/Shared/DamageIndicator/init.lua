--{{SERVICES}}
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

--{{MODULES}}
local Settings = require(script.Settings)

--{{SETTINGS}} : SET ACCORDING TO MODULE'S ORGANIZATION.
local RandomOffset, FadeOutTime, FadeInTime, IndicatorLength = Settings.RandomOffset, Settings.FadeOutTime, Settings.FadeInTime, Settings.IndicatorLength
local FadeOutInfo, FadeInInfo = Settings.FadeOutInfo, Settings.FadeInInfo
local Colors, Sizes = Settings.Colors, Settings.Sizes

local function round(n)
	return math.floor(n + 0.5)
end

local function DecreaseDamageIndicator(Damage, DamageInd)
	coroutine.resume(coroutine.create(function()
		if Damage and DamageInd then
			local TextLabel = DamageInd.Bill.T1:FindFirstChild("Text")
			local TextLabel2 = DamageInd.Bill:FindFirstChild("T1")

			local initialDamage = Damage
			local duration = .25 -- duration in seconds
			local steps = 10
			local steps2 = 20-- number of updates per second
			local interval = duration / steps
			local interval2 =  duration / steps2

			local function updateDamageText(newDamage)
				TextLabel.Text = string.format("-%.2f", newDamage)
				TextLabel2.Text = string.format("-%.2f", newDamage)
			end

			-- Animate from 0 to Damage
			for i = 0, steps do
				local currentTime = i * interval
				local currentDamage = initialDamage * (currentTime / duration)
				updateDamageText(currentDamage)
				wait(interval)
			end

			-- Hold at Damage for 0.2 seconds
			updateDamageText(initialDamage)
			wait(0.2)

			-- Animate from Damage to 0 and tween transparency to 1
			local Tween = TweenService:Create(DamageInd, TweenInfo.new(.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = DamageInd.CFrame * CFrame.new(0,-.5,0)})
			Tween:Play()
			
			for i = 0, steps2 do
				local currentTime = i * interval
				local currentDamage = initialDamage - (initialDamage * (currentTime / duration))
				updateDamageText(currentDamage)
				local transparency = currentTime / duration
				TextLabel.TextTransparency = transparency
				TextLabel2.TextTransparency = transparency
				wait(interval)
			end

			-- Ensure final state
			updateDamageText(0)
			TextLabel.TextTransparency = 1
			TextLabel2.TextTransparency = 1
		end
	end))
end

return function (Victim : Model, Damage : NumberValue, Color : Color3, Size : UDim2, font : Enum.Font)

	if Victim then
		Color = Color or Color3.new(1)
		Size = Size or Sizes.Small
		Damage = tostring(Damage) or '0'
		font = font or script.Damage.Bill.T1.Font
		
		Damage = round(Damage)
		--Damage = "-"..Damage
		
		local DamageIndicator = script:WaitForChild("Damage"):Clone()
		DamageIndicator.Bill.Size = Size
		DamageIndicator.Parent, DamageIndicator.CFrame, DamageIndicator.Anchored = workspace.FX, Victim:FindFirstChild("Torso").CFrame * CFrame.new(math.random(unpack(RandomOffset)), 0, 0), true
		DamageIndicator.Bill.T1.Text = "-"..Damage; DamageIndicator.Bill.T1:FindFirstChild("Text").Text = "-"..Damage
		
		
		DamageIndicator.Bill.T1.Font = font
		DamageIndicator.Bill.T1:WaitForChild("Text").Font = font
		
		local Tween = TweenService:Create(DamageIndicator.Bill.T1:FindFirstChild("Text"), TweenInfo.new(.5, FadeOutInfo.EasingStyle, FadeOutInfo.EasingDirection), {TextColor3 = Color})
		Tween:Play();
		Tween:Destroy();
		
		DecreaseDamageIndicator(Damage,DamageIndicator)
		
		task.delay(IndicatorLength, function()
			local Tween = TweenService:Create(DamageIndicator.Bill.T1:FindFirstChild("Text"), TweenInfo.new(1, FadeInInfo.EasingStyle, FadeInInfo.EasingDirection), {TextColor3 = Color3.fromRGB(255,255,255)})
			Tween:Play();
			Tween:Destroy();
			task.delay(1, function()
				DamageIndicator:Destroy()
			end)
		end)
		
		--[[
		local BodyVelocity = Instance.new("BodyVelocity")
		BodyVelocity.P = 10000
		BodyVelocity.MaxForce = Vector3.new(0,4e4,0)
		BodyVelocity.Velocity = Vector3.new(0,20,0)
		BodyVelocity.Parent = DamageIndicator
		task.delay(.1, function()
			BodyVelocity:Destroy()
		end)
		--]]
	end
end