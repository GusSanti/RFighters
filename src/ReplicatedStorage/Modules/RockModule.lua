local Debris = workspace:WaitForChild("Debris")
local TweenService = game:GetService("TweenService")

local rockModule = {}

--// CONFIGURAÇÃO DE SOM (Opcional, caso queira manter no module)
rockModule.RockSound = nil -- Defina isso no seu script principal se necessário

--// FUNÇÃO AUXILIAR: Raycast apenas para o MAPA
local function getMapParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include

	local whitelist = {}
	if workspace:FindFirstChild("Map") then
		table.insert(whitelist, workspace.Map)
	end
	table.insert(whitelist, workspace.Terrain)

	params.FilterDescendantsInstances = whitelist
	params.IgnoreWater = true
	return params
end

--// FUNÇÃO AUXILIAR: Vôo da pedra
local function applyFlight(part, upwardForce, spread)
	local velocity = Vector3.new(
		math.random(-spread, spread),
		upwardForce,
		math.random(-spread, spread)
	)

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = velocity
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.P = 5000
	bodyVelocity.Parent = part

	task.delay(0.25, function()
		if bodyVelocity.Parent then bodyVelocity:Destroy() end
	end)
end

--// FUNÇÃO AUXILIAR: Limpeza com Tween
local function cleanupPart(part, waitTime)
	task.delay(waitTime, function()
		if not part or not part.Parent then return end
		local info = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		local tween = TweenService:Create(part, info, {
			Transparency = 1,
			Size = part.Size * 0.2,
			Position = part.Position - Vector3.new(0, 2, 0)
		})
		tween:Play()
		tween.Completed:Connect(function()
			part:Destroy()
		end)
	end)
end

--// FUNÇÃO PRINCIPAL: Pedras no Chão
function rockModule:OnGround(position, RocksSize, raw, TotalNumberOfRocks, RocksMaterial, ThrowingRockssize)
	local Orientation = 0
	local TimeToWait = 3
	local ExtraOrientation = 25
	local params = getMapParams()

	for i = 1, TotalNumberOfRocks do
		local RoomBetweenRocks = RocksSize
		local cframe = position * CFrame.fromEulerAnglesXYZ(0, math.rad(Orientation), 0) * CFrame.new(RoomBetweenRocks, 0, RoomBetweenRocks)
		local CFramePosition = cframe.Position

		local NewPart = Instance.new("Part")
		NewPart.Anchored = true
		NewPart.Name = "Rock"
		NewPart.CanCollide = true
		NewPart.Transparency = 0 -- Sempre visível no início
		NewPart.CollisionGroup = "Rock"
		NewPart.Parent = workspace.Debris
		NewPart.Material = RocksMaterial

		if math.random(1, 3) == 2 then
			NewPart.Shape = Enum.PartType.Wedge
		end

		NewPart.CFrame = cframe
		NewPart.CFrame = CFrame.lookAt(Vector3.new(CFramePosition.X, 0, CFramePosition.Z), Vector3.new(position.Position.X, 0, position.Position.Z))

		-- Detectar solo do MAPA
		local NewRay = workspace:Raycast(CFramePosition + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0), params)

		if NewRay and NewRay.Instance then
			NewPart.Material = NewRay.Instance.Material
			NewPart.Color = NewRay.Instance.Color
			NewPart.Transparency = 0 -- Força visibilidade 0 mesmo se o alvo for transparente

			if NewRay.Instance.Material == Enum.Material.Grass then
				NewPart.Material = Enum.Material.Mud
				NewPart.Color = Color3.fromRGB(86, 66, 54)
			end
		end

		local TotalNewOrientation = Vector3.new(-math.random(ExtraOrientation - 10, ExtraOrientation + 10), 0, 0)
		if NewPart.Shape == Enum.PartType.Wedge then
			TotalNewOrientation += Vector3.new(0, 180, 0)
		end
		NewPart.Orientation += TotalNewOrientation

		local NewSize = Vector3.new(math.random(math.round(RocksSize * 0.7), math.round(RocksSize * 1.5)), 1, math.random(RocksSize * 0.5, RocksSize * 1.5))
		NewPart.Size = NewSize + Vector3.new(0, RocksSize * 1.5, 0)
		NewPart.CFrame = NewPart.CFrame * CFrame.new(0, (NewSize.Y - NewPart.Size.Y) / 2, 0)

		Orientation += 360 / TotalNumberOfRocks

		-- Tween de sumiço (descendo)
		task.spawn(function()
			task.wait(math.random(TimeToWait, TimeToWait + 3))
			local info = TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			local Tween = TweenService:Create(NewPart, info, {Position = NewPart.Position - Vector3.new(0, NewPart.Size.Y, 0)})
			Tween:Play()
			Tween.Completed:Connect(function() NewPart:Destroy() end)
		end)
	end

	-- Criar cubos que voam (se raw for true)
	if raw then
		local function CreateCube(size, amount)
			for i = 1, amount do
				task.spawn(function()
					local cube = Instance.new("Part")
					cube.Size = size
					cube.Position = position.Position
					cube.Parent = workspace.Debris
					cube.Material = RocksMaterial
					cube.Transparency = 0
					cube.CanCollide = true

					local ray = workspace:Raycast(position.Position + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), params)
					if ray then cube.Color = ray.Instance.Color end

					applyFlight(cube, 22, 32)
					cleanupPart(cube, math.random(4, 7))
				end)
			end
		end
		CreateCube(ThrowingRockssize, math.random(TotalNumberOfRocks/3, TotalNumberOfRocks/3 + 1))
	end
end

--// FUNÇÃO: Levantar pedras em grade
function rockModule:TableFlip(Part, RocksMaterial)
	local params = getMapParams()
	local grid = 12
	local startPos = Part.Position - Vector3.new(Part.Size.X/2, 0, Part.Size.Z/2)

	for X = 0, Part.Size.X, grid do
		for Z = 0, Part.Size.Z, grid do
			task.spawn(function()
				task.wait((X+Z)/100) -- Delay progressivo
				local cube = Instance.new("Part")
				cube.Size = Vector3.new(8, 8, 8)
				cube.Position = startPos + Vector3.new(X, 0, Z)
				cube.Parent = workspace.Debris
				cube.Material = RocksMaterial
				cube.Transparency = 0

				local ray = workspace:Raycast(cube.Position + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0), params)
				if ray then 
					cube.Color = ray.Instance.Color 
					cube.Material = ray.Instance.Material
				end

				applyFlight(cube, 190, 5)
				cleanupPart(cube, 10)
			end)
		end
	end
end

--// FUNÇÃO: Rastro de pedras
function rockModule:Trail(Part, Time)
	local params = getMapParams()
	local active = true

	task.delay(Time, function() active = false end)

	task.spawn(function()
		while active do
			for _, side in pairs({-2, 2}) do
				local cube = Instance.new("Part")
				cube.Size = Vector3.new(1.5, 1.5, 1.5)
				cube.Anchored = true
				cube.Parent = workspace.Debris
				cube.Transparency = 0

				local ray = workspace:Raycast(Part.Position + Vector3.new(side, 10, 0), Vector3.new(0, -20, 0), params)
				if ray then
					cube.Position = ray.Position
					cube.Color = ray.Instance.Color
					cube.Material = ray.Instance.Material
				else
					cube.Position = Part.Position + Vector3.new(side, -3, 0)
				end

				cube.Orientation = Vector3.new(math.random(0,360), math.random(0,360), math.random(0,360))
				cleanupPart(cube, 2)
			end
			task.wait(0.1)
		end
	end)
end

return rockModule