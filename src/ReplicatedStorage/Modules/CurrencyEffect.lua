local module = {}

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local CameraShake = require(script.Parent.CameraShake)

local LocalPlayer = Players.LocalPlayer
local Assets = ReplicatedStorage:WaitForChild("Assets")

local MIN_SHARDS = 12
local MAX_SHARDS = 18
local MIN_SCALE = 1.3
local MAX_SCALE = 2.6
local MIN_DISTANCE = 6
local MAX_DISTANCE = 10
local MIN_BOUNCE_HEIGHT = 2
local MAX_BOUNCE_HEIGHT = 5
local MIN_SPIN_SPEED = 2
local MAX_SPIN_SPEED = 6
local LAUNCH_DURATION = 0.5
local SUCK_DELAY = 1.5
local SUCK_DURATION = 0.8
local SHAKE_DURATION = 0.45
local SHAKE_INTENSITY = 0.22

local warnedKeys = {}

local CURRENCY_CONFIG = {
	Diamond = {
		assetName = "Diamonds",
		dropSound = "DiamondsDrop",
		receiveSound = "DiamondsReceived",
	},
	Diamonds = {
		assetName = "Diamonds",
		dropSound = "DiamondsDrop",
		receiveSound = "DiamondsReceived",
	},
	Crystal = {
		assetName = "Crystals",
		dropSound = "CrystalsDrop",
		receiveSound = "CrystalsReceived",
	},
	Crystals = {
		assetName = "Crystals",
		dropSound = "CrystalsDrop",
		receiveSound = "CrystalsReceived",
	},
}

local function warnOnce(key, message)
	if warnedKeys[key] then
		return
	end

	warnedKeys[key] = true
	warn(message)
end

local function getEffectFolder()
	local folder = workspace:FindFirstChild("CurrencyFloatCache")
	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = "CurrencyFloatCache"
	folder.Parent = workspace

	return folder
end

local function getCurrencyTemplate(assetName)
	local currencyFolder = Assets:FindFirstChild("Currency")
	if not currencyFolder then
		warnOnce("MissingCurrencyFolder", "[CurrencyEffect] ReplicatedStorage.Assets.Currency nao foi encontrado.")
		return nil
	end

	local template = currencyFolder:FindFirstChild(assetName)
	if not template then
		warnOnce(`MissingTemplate_{assetName}`, `[CurrencyEffect] Modelo de moeda "{assetName}" nao foi encontrado.`)
		return nil
	end

	if not template:IsA("Model") then
		warnOnce(`InvalidTemplate_{assetName}`, `[CurrencyEffect] "{assetName}" precisa ser um Model para usar ScaleTo/PivotTo.`)
		return nil
	end

	return template
end

local function playSfx(soundName)
	local sfxFolder = SoundService:FindFirstChild("SFX")
	if not sfxFolder then
		warnOnce("MissingSFXFolder", "[CurrencyEffect] SoundService.SFX nao foi encontrado.")
		return
	end

	local sound = sfxFolder:FindFirstChild(soundName)
	if not sound then
		warnOnce(`MissingSound_{soundName}`, `[CurrencyEffect] Som "{soundName}" nao foi encontrado em SoundService.SFX.`)
		return
	end

	if sound:IsA("Sound") then
		sound:Play()
	end
end

local function getSourcePosition(customSourcePosition)
	if typeof(customSourcePosition) == "Vector3" then
		return customSourcePosition
	end

	local character = LocalPlayer and LocalPlayer.Character
	if character then
		return character:GetPivot().Position
	end

	local camera = workspace.CurrentCamera
	if camera then
		return camera.CFrame.Position
	end

	return nil
end

local function getTargetPosition(fallbackPosition)
	local character = LocalPlayer and LocalPlayer.Character
	if character then
		return character:GetPivot().Position + Vector3.new(0, -1, 0)
	end

	local camera = workspace.CurrentCamera
	if camera then
		return camera.CFrame.Position
	end

	return fallbackPosition
end

local function bezierCurve(p0, p1, p2, t)
	return ((1 - t) ^ 2 * p0) + (2 * (1 - t) * t * p1) + ((t ^ 2) * p2)
end

local function tweenModelScale(model, tweenInfo, targetScale)
	local scaleValue = Instance.new("NumberValue")
	scaleValue.Value = model:GetScale()

	local changedConnection = scaleValue.Changed:Connect(function()
		model:ScaleTo(scaleValue.Value)
	end)

	local tween = TweenService:Create(scaleValue, tweenInfo, { Value = targetScale })
	tween:Play()
	tween.Completed:Once(function()
		changedConnection:Disconnect()
		scaleValue:Destroy()
	end)

	return tween
end

local function animateShard(currencyModel, shardIndex, shardCount, sourcePosition)
	currencyModel.Parent = getEffectFolder()
	currencyModel:PivotTo(CFrame.new(sourcePosition + Vector3.new(0, -3.5, 0)))
	currencyModel:ScaleTo(math.random(MIN_SCALE * 100, MAX_SCALE * 100) / 100)

	task.spawn(function()
		local baseAngle = (shardIndex - 1) * (2 * math.pi / shardCount)
		local angle = baseAngle + math.rad(math.random(-30, 30))
		local distance = math.random(MIN_DISTANCE * 100, MAX_DISTANCE * 100) / 100
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
		local bounceHeight = math.random(MIN_BOUNCE_HEIGHT * 100, MAX_BOUNCE_HEIGHT * 100) / 100

		local startPosition = currencyModel:GetPivot().Position
		local midPosition = startPosition + offset + Vector3.new(0, bounceHeight, 0)
		local endPosition = startPosition + offset

		local positionValue = Instance.new("CFrameValue")
		local rotationValue = Instance.new("NumberValue")
		positionValue.Value = CFrame.new(startPosition)
		rotationValue.Value = 0

		local function updateModel()
			local rotation = CFrame.Angles(0, math.rad(rotationValue.Value), 0)
			currencyModel:PivotTo(CFrame.new(positionValue.Value.Position) * rotation)
		end

		local positionConnection = positionValue.Changed:Connect(updateModel)
		local rotationConnection = rotationValue.Changed:Connect(updateModel)

		local spinning = true
		local spinSpeed = math.random(MIN_SPIN_SPEED, MAX_SPIN_SPEED)

		local upTween = TweenService:Create(
			positionValue,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = CFrame.new(midPosition) }
		)
		local downTween = TweenService:Create(
			positionValue,
			TweenInfo.new(0.3, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
			{ Value = CFrame.new(endPosition) }
		)

		upTween:Play()
		upTween.Completed:Once(function()
			downTween:Play()
		end)

		task.spawn(function()
			while spinning and currencyModel.Parent do
				local spinTween = TweenService:Create(
					rotationValue,
					TweenInfo.new(1 / spinSpeed, Enum.EasingStyle.Linear),
					{ Value = rotationValue.Value + 360 }
				)
				spinTween:Play()
				spinTween.Completed:Wait()
			end
		end)

		task.wait(LAUNCH_DURATION + SUCK_DELAY)

		tweenModelScale(
			currencyModel,
			TweenInfo.new(SUCK_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
			math.max(currencyModel:GetScale() * 0.1, 0.05)
		)

		local startSuckTime = os.clock()
		local startSuckPosition = positionValue.Value.Position
		local targetBase = getTargetPosition(sourcePosition)
		local direction = startSuckPosition - targetBase

		if direction.Magnitude < 0.01 then
			direction = Vector3.new(math.random() - 0.5, 0.2, math.random() - 0.5)
		end

		direction = direction.Unit

		local flarePoint = startSuckPosition
			+ direction * math.random(8, 15)
			+ Vector3.new(0, math.random(3, 8), 0)

		while os.clock() - startSuckTime < SUCK_DURATION and currencyModel.Parent do
			local targetPosition = getTargetPosition(sourcePosition)
			local alpha = math.clamp((os.clock() - startSuckTime) / SUCK_DURATION, 0, 1)
			alpha = 1 - ((1 - alpha) ^ 4)

			positionValue.Value = CFrame.new(bezierCurve(startSuckPosition, flarePoint, targetPosition, alpha))
			RunService.Heartbeat:Wait()
		end

		spinning = false
		positionConnection:Disconnect()
		rotationConnection:Disconnect()
		positionValue:Destroy()
		rotationValue:Destroy()
		currencyModel:Destroy()
	end)

	Debris:AddItem(currencyModel, LAUNCH_DURATION + SUCK_DELAY + SUCK_DURATION + 2)
end

function module.castEffect(currencyName, amountGained, sourcePosition)
	local config = CURRENCY_CONFIG[currencyName]
	if not config then
		warnOnce(`UnknownCurrency_{tostring(currencyName)}`, `[CurrencyEffect] Tipo de moeda desconhecido: {tostring(currencyName)}`)
		return
	end

	local template = getCurrencyTemplate(config.assetName)
	local startPosition = getSourcePosition(sourcePosition)
	if not template or not startPosition then
		return
	end

	local bonusShards = math.clamp(math.floor(math.max(tonumber(amountGained) or 0, 0) / 500), 0, 6)
	local shardCount = math.random(MIN_SHARDS, MAX_SHARDS) + bonusShards

	CameraShake.shakeCamera(SHAKE_DURATION, SHAKE_INTENSITY)
	playSfx(config.dropSound)

	for shardIndex = 1, shardCount do
		animateShard(template:Clone(), shardIndex, shardCount, startPosition)
	end

	task.delay(LAUNCH_DURATION + SUCK_DELAY + SUCK_DURATION, function()
		playSfx(config.receiveSound)
	end)
end

return module
