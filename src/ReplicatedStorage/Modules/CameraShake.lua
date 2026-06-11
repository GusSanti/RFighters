local module = {}

local RunService = game:GetService("RunService")

local activeShake = nil
local fadeConnection = nil
local currentIntensity = 0
local lastOffset = Vector3.zero
local lastCamera = nil

local function restoreCamera()
	local camera = workspace.CurrentCamera
	if camera and camera == lastCamera and lastOffset.Magnitude > 0 then
		camera.CFrame *= CFrame.new(-lastOffset)
	end

	lastOffset = Vector3.zero
	lastCamera = camera
end

function module.stop()
	if activeShake then
		activeShake:Disconnect()
		activeShake = nil
	end

	if fadeConnection then
		fadeConnection:Disconnect()
		fadeConnection = nil
	end

	restoreCamera()
	currentIntensity = 0
end

local function getShakeOffset()
	return Vector3.new(
		(math.random() - 0.5) * 2 * currentIntensity,
		(math.random() - 0.5) * 2 * currentIntensity,
		(math.random() - 0.5) * currentIntensity
	)
end

function module.shakeCamera(duration, intensity)
	if not workspace.CurrentCamera then
		return
	end

	module.stop()

	currentIntensity = intensity or 0
	local startTime = os.clock()

	activeShake = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		if lastCamera and lastCamera ~= camera then
			lastOffset = Vector3.zero
		elseif lastOffset.Magnitude > 0 then
			camera.CFrame *= CFrame.new(-lastOffset)
			lastOffset = Vector3.zero
		end

		lastCamera = camera

		if duration ~= true and os.clock() - startTime > (duration or 0) then
			if not fadeConnection then
				module.fadeOut(0.35)
			end
			return
		end

		if currentIntensity <= 0 then
			return
		end

		lastOffset = getShakeOffset()
		camera.CFrame *= CFrame.new(lastOffset)
	end)
end

function module.fadeOut(fadeDuration)
	if fadeConnection then
		fadeConnection:Disconnect()
		fadeConnection = nil
	end

	if not activeShake or currentIntensity <= 0 then
		module.stop()
		return
	end

	local startIntensity = currentIntensity
	local startTime = os.clock()
	local duration = math.max(fadeDuration or 0.35, 0.01)

	fadeConnection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		local alpha = math.clamp(elapsed / duration, 0, 1)
		currentIntensity = startIntensity * (1 - alpha)

		if alpha >= 1 then
			module.stop()
		end
	end)
end

return module
