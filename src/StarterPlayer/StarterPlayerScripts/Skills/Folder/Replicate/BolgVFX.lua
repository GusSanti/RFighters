script.Parent = nil

local FirstChild = game.StarterPlayer:FindFirstChild(script.Name, true)
if FirstChild then
	FirstChild:Destroy()
end

--// Services \\--
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")
local ReplicatedStorage = RS
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

--Variaveis Principais para vfx ou sfx
local Assets = ReplicatedStorage.SkillStorage.Bolg
local Fx = Assets.FX
local Sounds = Assets.Sounds

--// Modules \\--

local VFX = require(ReplicatedStorage.Modules.Utilitary.VFX)
local vfx = require(ReplicatedStorage.Modules.Utilitary.vfx)
local Utilities = require(ReplicatedStorage.Modules.Utilitary.Utils)
local Raycast = require(ReplicatedStorage.Modules.Raycast)
local sparkModule  = require(ReplicatedStorage.Modules.SparksModule)
local ImpactModule = require(ReplicatedStorage.Modules:WaitForChild("ImpactFrames"))
local Trove = require(ReplicatedStorage.Modules:WaitForChild("Trove"))
local AfterImage = require(ReplicatedStorage.Modules.AfterImage)

--// Utility Functions \\--
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

function Emit(target, effectTemplate, duration, options)
	if not target or not target:IsDescendantOf(game) then return end
	duration = duration or 1
	options = options or {}

	local offsetCFrame = options.offsetCFrame or CFrame.new()
	local offsetX = options.X or 0
	local offsetY = options.Y or 0
	local offsetZ = options.Z or 0
	local keepRotation = options.KeepRotation or false

	local positionOffset = CFrame.new(offsetX, offsetY, offsetZ)

	-- Suporte a Model
	if effectTemplate:IsA("Model") then
		local modelClone = effectTemplate:Clone()
		modelClone.Parent = workspace:WaitForChild("Effects")

		local function getTargetCFrame()
			if target:IsA("CFrameValue") then return target.Value
			elseif target:IsA("BasePart") then return target.CFrame end
		end

		local targetCF = getTargetCFrame()
		local finalCF

		if keepRotation then
			local firstPart = modelClone:FindFirstChildWhichIsA("BasePart")
			if firstPart then
				local templateRotation = firstPart.CFrame - firstPart.CFrame.Position
				finalCF = CFrame.new(targetCF.Position) * templateRotation * positionOffset
			end
		else
			finalCF = targetCF * offsetCFrame * positionOffset
		end

		if finalCF then
			modelClone:PivotTo(finalCF)
		end

		Debris:AddItem(modelClone, duration)

		for _, descendant in ipairs(modelClone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			end
		end
		
		vfx.emit(modelClone)

		return
	end

	-- Lógica original pra BasePart
	if not target:IsA("BasePart") and not target:IsA("CFrameValue") then return end

	local templateRotation = effectTemplate.CFrame - effectTemplate.CFrame.Position

	local effectClone = effectTemplate:Clone()
	effectClone.Transparency = 1
	effectClone.Anchored = true
	effectClone.CanCollide = false
	effectClone.CanQuery = false
	effectClone.CanTouch = false
	effectClone.Parent = workspace:WaitForChild("Effects")

	local function getTargetCFrame()
		if target:IsA("CFrameValue") then return target.Value
		elseif target:IsA("BasePart") then return target.CFrame end
	end

	local targetCF = getTargetCFrame()

	if keepRotation then
		effectClone.CFrame = CFrame.new(targetCF.Position) * templateRotation * positionOffset
	else
		effectClone.CFrame = targetCF * offsetCFrame * positionOffset
	end

	Debris:AddItem(effectClone, duration)
	vfx.emit(effectClone)
	
end

--// Utility Functions \\--
local function weld(part0, part1, c0, parent)
	if not (part0 and part1 and c0 and parent) then return end

	local weld = Instance.new("Weld")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.C0 = c0
	weld.Parent = parent
	return weld
end

local function destroyWeld(weld)
	if weld and weld.Parent then
		weld:Destroy()
	end
end


--[[
-- Uso normal (sem offsets) - MANTÉM COMPATIBILIDADE
Emit(Torso, Effect, 2)

-- Apenas com offset Y de 5 studs para cima
Emit(Torso, Effect, 2, {Y = 5})

-- Com offset X de 3 e Z de -2
Emit(Torso, Effect, 2, {X = 3, Z = -2})

-- Todos os offsets
Emit(Torso, Effect, 2, {X = 2, Y = 3, Z = -1})

-- Com offsetCFrame e offsets de posição
Emit(Torso, Effect, 2, {
	offsetCFrame = CFrame.Angles(0, math.rad(45), 0),
	Y = 10
})

-- Com rotação original do template
Emit(Torso, Fx.groot, 2, {KeepRotation = true})

-- Combinado com outros offsets
Emit(Torso, Fx.groot, 2, {KeepRotation = true, Y = 2})

]]


function onlyYCF(arg1)
	return CFrame.fromOrientation(0, Vector3.new(arg1:ToOrientation()).Y, 0)
end

function destroyVelocity(object)
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("LinearVelocity") or descendant:IsA("BodyPosition") then
			descendant:Destroy()
		end
	end
end

function BodyPosition(target, offset, duration, tweenInfo, positionTween, maxForce, pValue, dValue)
	destroyVelocity(target)

	local bodyPosition = Instance.new("BodyPosition")
	bodyPosition.P = pValue or 12500
	bodyPosition.D = dValue or 300
	bodyPosition.MaxForce = maxForce or Vector3.new(1, 0, 1) * 30000
	bodyPosition.Parent = target

	Debris:AddItem(bodyPosition, duration)

	TweenService:Create(bodyPosition, TweenInfo.new(table.unpack(tweenInfo)), {
		P = 5000,
		D = 600,
	}):Play()

	local trove = Trove.new()
	trove:AttachToInstance(bodyPosition)
	trove:Add(bodyPosition)
	trove:Add(task.delay(duration, trove.Destroy, trove))
	trove:Add(RunService.PreRender:Connect(function()
		bodyPosition.Position = onlyYCF(target.CFrame).Rotation.LookVector * offset + target.Position
	end))

	return bodyPosition
end

local Extra = {}
Extra.Raycast = function(Origin, Direction, Ignore)
	local Params = RaycastParams.new()
	Params.FilterDescendantsInstances = Ignore or {workspace.Debris}
	Params.FilterType = Enum.RaycastFilterType.Exclude

	local ray = workspace:Raycast(Origin, Direction, Params)
	if ray then
		return ray
	end
end

local function AnimateBillboardGui(billboardGui, animDuration, holdDuration, animOutDuration)
	animDuration = animDuration or 0.5
	holdDuration = holdDuration or 1.5
	animOutDuration = animOutDuration or 0.4

	for _, frame in pairs(billboardGui:GetDescendants()) do
		if frame:IsA("Frame") or frame:IsA("ImageLabel") or frame:IsA("TextLabel") then
			-- Configuração inicial
			local originalSize = frame.Size
			local originalPosition = frame.Position
			frame.Size = UDim2.new(0, 0, 0, 0)
			frame.Position = UDim2.new(originalPosition.X.Scale + originalSize.X.Scale/2, 0, originalPosition.Y.Scale + originalSize.Y.Scale/2, 0)
			
			if frame:IsA("ImageLabel") then
				frame.ImageTransparency = 1
				frame.BackgroundTransparency = 1
			elseif frame:IsA("TextLabel") then
				frame.TextTransparency = 1
				frame.BackgroundTransparency = 1
			else
				frame.BackgroundTransparency = 1
			end

			-- Tween de entrada
			local tweenInfo = TweenInfo.new(animDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			local tweenGoals = {
				Size = originalSize,
				Position = originalPosition
			}

			if frame:IsA("ImageLabel") then
				tweenGoals.ImageTransparency = 0
				tweenGoals.BackgroundTransparency = 1
			elseif frame:IsA("TextLabel") then
				tweenGoals.TextTransparency = 0
				tweenGoals.BackgroundTransparency = 1
			else
				tweenGoals.BackgroundTransparency = 0
			end

			local tweenIn = TweenService:Create(frame, tweenInfo, tweenGoals)
			tweenIn:Play()

			task.delay(animDuration + holdDuration, function()
				local tweenOutInfo = TweenInfo.new(animOutDuration, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				local tweenOutGoals = {
					Size = UDim2.new(0, 0, 0, 0),
					Position = UDim2.new(originalPosition.X.Scale + originalSize.X.Scale/2, 0, originalPosition.Y.Scale + originalSize.Y.Scale/2, 0)
				}

				-- Define metas de transparência de saída baseado no tipo
				if frame:IsA("ImageLabel") then
					tweenOutGoals.ImageTransparency = 1
					tweenOutGoals.BackgroundTransparency = 1
				elseif frame:IsA("TextLabel") then
					tweenOutGoals.TextTransparency = 1
					tweenOutGoals.BackgroundTransparency = 1
				else
					tweenOutGoals.BackgroundTransparency = 1
				end

				local tweenOut = TweenService:Create(frame, tweenOutInfo, tweenOutGoals)
				tweenOut:Play()
			end)
		end
	end

	-- Destroi o BillboardGui após todas as animações
	task.delay(animDuration + holdDuration + animOutDuration + 0.1, function()
		Debris:AddItem(billboardGui)
	end)
end

local function Loop(vezes, intervalo, callback)
	task.spawn(function()
		for i = 1, vezes do
			callback(i) -- Executa sua função passando o número atual da repetição
			if i < vezes then
				task.wait(intervalo) -- Espera o tempo definido entre as execuções
			end
		end
	end)
end


local Effects = {
	--[[TP = function(Params)
		local HumanoidRootPart = Params.Char.HumanoidRootPart
		local Children = workspace.Lives:GetChildren()
		table.remove(Children, table.find(Children, Params.Char))

		local Origin = HumanoidRootPart.Position
		local Direction = HumanoidRootPart.CFrame.LookVector * 40

		local result = Raycast(Origin, Direction, nil, {workspace.Map, Children})

		local targetCFrame

		if result then
			-- Recua da superfície usando o Normal do hit
			-- 3 = metade do tamanho típico do HRP (ajuste se precisar)
			local safePosition = result.Position + result.Normal * 3

			targetCFrame = CFrame.new(safePosition, safePosition + HumanoidRootPart.CFrame.LookVector)
		else
			-- Sem hit: vai até o ponto máximo normalmente
			targetCFrame = HumanoidRootPart.CFrame + HumanoidRootPart.CFrame.LookVector * (Params.P or 40)
		end

		HumanoidRootPart.CFrame = targetCFrame
	end,]]
	
	--Utilities.Particle_Setup({Holder = Main, Type = "Emit"})
	--Utilities.Particle_Setup({Holder = BlueAndRed, Type = "Enable", Bool = true})
	--local jointWeld = weld(LeftArm, Main, CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(180), 0), Main)
	--AfterImage.CreateClone(Character,1, Color3.fromRGB(255, 0, 0),0.25,1,0.6)
	--VFX.Highlight(Character, Color3.fromRGB(0, 136, 255), .6)
	--Emit(Torso, Effect, 2)
	
	BolgUltimate = function(Params)
		local Character = Params.Char
		local Humrp = Character.HumanoidRootPart
		local Torso = Character.Torso
		local Enemy = Params.Enemy
		local EnemyHumrp = Enemy.HumanoidRootPart
		local enemyTorso = Enemy.Torso

		local PlayerInfo = Character:FindFirstChild("PlayerInfo", true)
		local PlayerInfoEnememy = Enemy:FindFirstChild("PlayerInfo", true)

		if PlayerInfo then
			PlayerInfo.BillboardGui.Enabled = false
		end

		if PlayerInfoEnememy then
			PlayerInfoEnememy.BillboardGui.Enabled = false
		end

		local receiveTime = tick()

		local function delayCompensated(t, fn)
			local elapsed = tick() - receiveTime
			local remaining = t - elapsed
			if remaining <= 0 then
				task.spawn(fn)
			else
				task.delay(remaining, fn)
			end
		end
		
		local function GetEnemyCamera2(char)
			if Players:GetPlayerFromCharacter(char) then return nil end
			return char:FindFirstChild("camera2", true)
		end
		
		local Camera2 = Character:FindFirstChild("camera2", true)
		local EnemyCamera2 = GetEnemyCamera2(Enemy)

		delayCompensated(0.52 ,function()
			Emit(Torso, Fx["black aura"], 3.8, {KeepRotation = true, Y = -2.4})
			Emit(Torso, Fx.fire1, 3.8, {KeepRotation = true, Y = -2.4})
		end)
		
		delayCompensated(3.52 ,function()
			Emit(Torso, Fx.FloorFire, 7, {KeepRotation = true, {KeepRotation = true, Y = -2.4}})
			Emit(Torso, Fx.RainMeshesGround, 7, {KeepRotation = true, {KeepRotation = true, Y = -2.4}})
		end)
		
		delayCompensated(6.48 ,function()
			Emit(Torso, Fx.heartfire, 3.8, {KeepRotation = true})
			for _, cam in ipairs({Camera2, EnemyCamera2}) do
				if cam then
					local Rachuras = Fx.rachuras2:Clone()
					Rachuras.Parent = workspace.FX

					local Weld = Instance.new("Weld")
					Weld.Parent = Rachuras
					Weld.Part0 = cam
					Weld.Part1 = Rachuras
					Weld.C0 = CFrame.new(1, 1, 30) * CFrame.Angles(0, math.rad(0), 0)
					Debris:AddItem(Rachuras, 1.5)
				end
			end
		end)
		
		delayCompensated(11.25 ,function()
			Emit(Torso, Fx.Dive4, 3.8, {KeepRotation = true})
			Emit(Torso, Fx.dash, 3.8, {KeepRotation = true})
		end)
		
	end,
}

return Effects
