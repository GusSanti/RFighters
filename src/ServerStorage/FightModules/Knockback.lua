local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Knockback = {}

function Knockback:Knockback(character, params)
	if not character then return end

	local knockbackParams = {
		KnockbackType = params.KnockbackType or "Velocity",
		MaxForce = params.MaxForce or Vector3.new(1, 1, 1) * math.huge,
		Velocity = params.Velocity or Vector3.new(0, 10, 0),
		Duration = params.Duration or 0.1
	}

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	for _, instance in pairs(humanoidRootPart:GetChildren()) do
		if instance:IsA("BodyVelocity") then
			instance:Destroy()
		end
	end

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = knockbackParams.MaxForce
	bodyVelocity.Velocity = knockbackParams.Velocity
	bodyVelocity.Parent = humanoidRootPart

	task.delay(knockbackParams.Duration, function()
		if bodyVelocity and bodyVelocity.Parent then
			bodyVelocity:Destroy()
		end
	end)
end

function Knockback:KnockbackTween(character, params)
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.AutoRotate = false
	end

	local knockbackParams = {
		KnockbackType = params.KnockbackType or "Velocity",
		MaxForce = params.MaxForce or Vector3.new(1, 1, 1) * math.huge,
		Velocity = params.Velocity or Vector3.new(0, 10, 0),
		Duration = params.Duration or 0.3,
		EasingStyle = params.EasingStyle or Enum.EasingStyle.Quad,
		EasingDirection = params.EasingDirection or Enum.EasingDirection.Out
	}

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	for _, instance in pairs(humanoidRootPart:GetChildren()) do
		if instance:IsA("BodyVelocity") then
			instance:Destroy()
		end
	end

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = knockbackParams.MaxForce
	bodyVelocity.Velocity = knockbackParams.Velocity
	bodyVelocity.P = 1250
	bodyVelocity.Parent = humanoidRootPart

	local startVelocity = knockbackParams.Velocity
	local duration = knockbackParams.Duration
	local easingStyle = knockbackParams.EasingStyle
	local easingDirection = knockbackParams.EasingDirection

	local startTime = tick()

	local connection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		local alpha = math.clamp(elapsed / duration, 0, 1)
		local easedAlpha = TweenService:GetValue(alpha, easingStyle, easingDirection)
		local currentVelocity = startVelocity:Lerp(Vector3.zero, easedAlpha)

		bodyVelocity.Velocity = currentVelocity

		if alpha >= 1 then
			connection:Disconnect()
			bodyVelocity:Destroy()
			if humanoid then
				humanoid.AutoRotate = true
			end
		end
	end)
end

return Knockback
