--[[
    @class CratersModule
    @shared
    @description 
        Crater debris system that spawns surface-aligned particles.
        Handles emission patterns, mesh support, and ground matching.
]]

--- @ Section: Services
local TweenService = game:GetService("TweenService")
local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

--- @ Section: State
local api = shared.fx

local defaults = {
	RaycastDistance = 100,
	Count = NumberRange.new(12, 18),
	Lifetime = NumberRange.new(2, 4),
	Size = Vector3.new(6, 2, 3),
	SizeScale = NumberRange.new(0.7, 1.5),
	SizeBias = 0.5,
	ScaleJitterX = NumberRange.new(0, 0),
	ScaleJitterY = NumberRange.new(0, 0),
	ScaleJitterZ = NumberRange.new(0, 0),
	Collision = true,
	MatchGround = true,
	UseMesh = false,
	MeshId = "",
	TextureId = "",
	Shape = {"Ring", "Line", "Cone"},
	Radius = 15,
	Variance = 2,
	ConeAngle = 45,
	Fill = false,
	EmissionStart = {"Progressive", "Random", "Reverse"},
	EmissionEnd = {"Progressive", "Random", "Reverse"},
	Duration = 0.1,
	AlignSurface = true,
	YOffset = 0.5,
	SpawnTime = NumberRange.new(0.1, 0.2),
	DespawnTime = NumberRange.new(1, 1.2),
	AngleX = NumberRange.new(15, 30),
	AngleY = NumberRange.new(-5, 5),
	AngleZ = NumberRange.new(-5, 5),
}

--- @ Section: Helper Functions
local temp, resolve, getCFrame = api.temp, api.num, api.getCFrame

local function getProgressValue(mode, linear)
	if mode == "Reverse" then
		return 1 - linear
	elseif mode == "Random" then
		return math.random()
	end
	return linear
end

--- @ Section: Core Logic

api.add {
	selector = ".CraterVFX",

	emit = function(vfx, attributes)
		if not vfx:HasTag("CraterVFX") then return end

		attributes = api.defaultTo(attributes, defaults)
		--- @ Section: Core Logic > Configuration
		local count = resolve(attributes.Count)
		local duration = attributes.Duration

		local baseSize = attributes.Size
		local lifetimeRange = attributes.Lifetime
		local sizeScaleRange = attributes.SizeScale
		local sizeBias = attributes.SizeBias
		local scaleJitterXRange = attributes.ScaleJitterX
		local scaleJitterYRange = attributes.ScaleJitterY
		local scaleJitterZRange = attributes.ScaleJitterZ
		local angleXRange = attributes.AngleX
		local angleYRange = attributes.AngleY
		local angleZRange = attributes.AngleZ

		local canCollide = attributes.Collision

		local shape = attributes.Shape
		local radius = attributes.Radius
		local variance = attributes.Variance
		local coneAngle = attributes.ConeAngle
		local fill = attributes.Fill

		local startMode = attributes.EmissionStart
		local endMode = attributes.EmissionEnd

		local useMesh = attributes.UseMesh
		local meshIdRaw = attributes.MeshId
		local texIdRaw = attributes.TextureId

		local matchGround = attributes.MatchGround
		local alignSurface = attributes.AlignSurface
		local yOffset = attributes.YOffset

		local tSpawn = resolve(attributes.SpawnTime)
		local tDespawn = resolve(attributes.DespawnTime)

		local tweenInfoIn = TweenInfo.new(tSpawn, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
		local tweenInfoOut = TweenInfo.new(tDespawn, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)

		--- @ Section: Core Logic > Setup
		local originCFrame = getCFrame(vfx)
		local originPos = originCFrame.Position
		local originLook = originCFrame.LookVector
		local originRight = originCFrame.RightVector

		local ignoreList = {temp}
		if vfx:IsA("Attachment") and vfx.Parent:IsA("BasePart") then
			table.insert(ignoreList, vfx.Parent)
		elseif vfx:IsA("BasePart") then
			table.insert(ignoreList, vfx)
		end

		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				table.insert(ignoreList, player.Character)
			end
		end

		for _, obj in ipairs(CollectionService:GetTagged("CraterIgnore")) do
			table.insert(ignoreList, obj)
		end

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = ignoreList

		--- @ Section: Core Logic > Template Creation
		local templatePart = nil
		if useMesh and meshIdRaw ~= "" then
			local success, result = pcall(function()
				return InsertService:CreateMeshPartAsync(meshIdRaw, Enum.CollisionFidelity.Default, Enum.RenderFidelity.Automatic)
			end)
			if success and result then
				templatePart = result
				if texIdRaw ~= "" then 
					templatePart.TextureID = texIdRaw
				end
			end
		end

		if not templatePart then
			templatePart = Instance.new("Part")
			templatePart.Name = "CraterBlock"
		else
			templatePart.Name = "CraterMesh"
		end

		templatePart.Anchored = true
		templatePart.Locked = true
		templatePart.CanCollide = canCollide
		templatePart.CanQuery = false
		templatePart.Size = Vector3.new(0.01, 0.01, 0.01)

		--- @ Section: Core Logic > Spawn Scheduling
		local spawnList = {}
		for i = 1, count do
			local linearAlpha = (i - 1) / math.max(1, count - 1)
			local spawnTime = 0

			if duration > 0 then
				if startMode == "Random" then
					spawnTime = math.random() * duration
				else
					spawnTime = linearAlpha * duration
				end
			end

			table.insert(spawnList, {
				linearAlpha = linearAlpha,
				spawnTime = spawnTime
			})
		end

		if duration > 0 then
			table.sort(spawnList, function(a, b) return a.spawnTime < b.spawnTime end)
		end
		
		local dist = attributes.RaycastDistance
		dist = dist == 0 and radius or dist
			
		--- @ Section: Core Logic > Emission Loop
		for _, data in spawnList do
			task.delay(data.spawnTime, function()
				if not vfx or not vfx.Parent then return end

				local linearAlpha = data.linearAlpha
				local distAlpha = getProgressValue(startMode, linearAlpha)
				local lifeAlpha = getProgressValue(endMode, linearAlpha)

				local actualLifetime
				if typeof(lifetimeRange) == "NumberRange" then
					actualLifetime = lifetimeRange.Min + (lifeAlpha * (lifetimeRange.Max - lifetimeRange.Min))
				else
					actualLifetime = lifetimeRange
				end

				local scaleMult = resolve(sizeScaleRange)
				local biasMultiplier = 1 + (sizeBias - 0.5) * (linearAlpha - 0.5) * 2

				local jitterX = 1 + resolve(scaleJitterXRange)
				local jitterY = 1 + resolve(scaleJitterYRange)
				local jitterZ = 1 + resolve(scaleJitterZRange)

				local finalSize = Vector3.new(
					baseSize.X * scaleMult * biasMultiplier * jitterX,
					baseSize.Y * scaleMult * biasMultiplier * jitterY,
					baseSize.Z * scaleMult * biasMultiplier * jitterZ
				)

				local startPos
				local lookDir
				if shape == "Cone" then
					local currentRadius = distAlpha * radius

					local halfAngle = math.rad(coneAngle / 2)
					local spreadY

					if fill then
						spreadY = (math.random() - 0.5) * 2 * halfAngle
					else
						local side = math.random() < 0.5 and -1 or 1
						spreadY = side * halfAngle + (math.random() * 2 - 1) * math.rad(variance)
					end

					local dirCFrame = originCFrame * CFrame.Angles(0, spreadY, 0)
					lookDir = dirCFrame.LookVector
					startPos = lookDir * currentRadius

				elseif shape == "Line" then
					local dist = distAlpha * radius
					local widthNoise = (math.random() * 2 - 1) * variance

					startPos = (originLook * dist) + (originRight * widthNoise)
					lookDir = originLook

				else
					local angle = math.random() * 2 * math.pi
					local currentRadius

					if fill then
						currentRadius = distAlpha * radius
					else
						currentRadius = radius
					end

					local radialVariance = (math.random() * 2 - 1) * variance

					local offsetX = math.cos(angle) * (currentRadius + radialVariance)
					local offsetZ = math.sin(angle) * (currentRadius + radialVariance)

					startPos = Vector3.new(offsetX, 0, offsetZ)
					lookDir = Vector3.new(offsetX, 0, offsetZ).Unit
				end
				
				if dist >= 0 then lookDir = originCFrame:VectorToWorldSpace(lookDir) end
				local obstacleRay = workspace:Raycast(originPos, lookDir * (radius + variance), rayParams)
				
				local yAxis = dist >= 0 and originCFrame:VectorToWorldSpace(Vector3.yAxis) or Vector3.yAxis
				
				if obstacleRay then
					startPos = obstacleRay.Position + yAxis * (yOffset + 2)
				else
					if shape ~= "Cone" and shape ~= "Line" then
						local sideRay = workspace:Raycast(startPos + yAxis * 10, yAxis * -20, rayParams)
						startPos = startPos - (lookDir * 1.5)
					end
				end
				
				local rayDir = vector.create(0, -math.abs(dist), 0)
				
				if dist >= 0 then
					rayDir = originCFrame:VectorToWorldSpace(rayDir)
					startPos = originPos + originCFrame:VectorToWorldSpace(startPos)
				else
					startPos += originPos
				end
				
				local ray = workspace:Raycast(startPos - rayDir/9, rayDir, rayParams)
				
				if ray then
					local target = ray.Instance
					local hitColor = target.Color
					local hitMaterial = ray.Material

					if target:IsA("Terrain") then
						hitColor = workspace.Terrain:GetMaterialColor(ray.Material)
					end

					local part = templatePart:Clone()
					part.Parent = temp

					if matchGround then
						part.Color = hitColor
						part.Material = hitMaterial
						if target:IsA("BasePart") then
							part.Reflectance = target.Reflectance
							part.Transparency = target.Transparency
						end

						for _, v in target:QueryDescendants(">Texture,>Decal") do
							v:Clone().Parent = part
						end
					else
						part.Color = Color3.new(1, 1, 1)
						part.Material = Enum.Material.Plastic
					end

					local baseRotation = CFrame.lookAt(Vector3.zero, lookDir, alignSurface and ray.Normal or yAxis)

					local rotX = math.rad(resolve(angleXRange))
					local rotY = math.rad(resolve(angleYRange))
					local rotZ = math.rad(resolve(angleZRange))

					local finalRotation = baseRotation * CFrame.Angles(rotX, rotY, rotZ)

					local upDir = baseRotation.UpVector
					local targetPos = ray.Position + (upDir * yOffset)
					local targetCFrame = CFrame.new(targetPos) * finalRotation

					part.CFrame = finalRotation + ray.Position

					local tIn = TweenService:Create(part, tweenInfoIn, {
						Size = finalSize,
						CFrame = targetCFrame
					})
					tIn:Play()

					task.delay(actualLifetime - tDespawn, function()
						if not part or not part.Parent then return end

						local tOut = TweenService:Create(part, tweenInfoOut, {
							Size = Vector3.new(0.01, 0.01, 0.01),
							CFrame = CFrame.new(ray.Position) * finalRotation
						})
						tOut:Play()

						tOut.Completed:Connect(function()
							part:Destroy()
						end)
					end)
				end
			end)
		end

		task.delay(duration + 0.1, function()
			if templatePart then templatePart:Destroy() end
		end)
	end
}

return {
	defaults = defaults
}