local workspace = workspace
local random = Random.new()

local IgnoreList = {workspace.FX, workspace.Map.NPCS} -- CHANGE THIS TO IGNORE SPECIFIC INSTANCES

Params = RaycastParams.new()
Params.FilterType = Enum.RaycastFilterType.Exclude
Params.FilterDescendantsInstances = IgnoreList
Params.IgnoreWater = true

local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local fullCircle = 2 * math.pi

local Rocks = script.Parent:WaitForChild('Rocks')
local Parent = workspace.FX -- SET THE PARENT USING THIS

local rayPart = function(CFrameValue, Range, Properties, ownPart)
	
	local Results = workspace:Raycast(CFrameValue.Position, -CFrameValue.UpVector * Range, Params)
	
	if Results then
		local Part = ownPart or Instance.new('Part')
		Part.Parent = workspace.FX
		Part.Anchored = true
		Part.CanCollide = false
		Part.Material = Results.Material
		Part.Color = Results.Instance.Color
		Part.CFrame = CFrame.new(Results.Position)
		Part.Reflectance = Results.Instance.Reflectance
		Part.Transparency = Results.Instance.Transparency
		if Properties then
			for property, value in ipairs( Properties ) do
				if Part[property] then
					Part[property] = value
				end
			end
		end

		return Part, Results
	else
		return false
	end
end
local Wait = task.wait()

local randInt = function(min, max)
	return random:NextNumber(min, max)
end

local function lerp(a, b, x)
	return a + (b - a) * x
end

local function getXAndZPositions(angle, radius,spi)
	local x = math.cos(angle) * radius + spi
	local z = math.sin(angle) * radius + spi
	return x, z
end


return {
	Crater = function(AnchorPoint, settings)
		local partCount = settings.PartCount or 5
		local radius = settings.Radius or 5
		local range = settings.Range or 5
		local Angle = settings.Angle or 45
		
		local BlockSize = settings.BlockSize or {5, 8}
		for i = 1, partCount do
			local angle = i * (fullCircle / partCount)
			local x, z = getXAndZPositions(angle, radius, 0)
			local Offset = (AnchorPoint) * Vector3.new(x, 0, z)

			local angle2 = (i + 1) * (fullCircle / partCount)
			local x2, z2 = getXAndZPositions(angle2, radius,0)
			local Offset2 = (AnchorPoint) * Vector3.new(x2,0,z2)
			local getRandom = randInt(BlockSize[1], BlockSize[2])
			local newSize = Vector3.new(getRandom * 2, getRandom, getRandom * 1.25)
			local Part = rayPart(CFrame.new(Offset),  range, {Size = newSize})
			
			if Part then
				Part.Name = 'CraterPart-'..i
				local cframeTo = CFrame.lookAt(Part.Position, Vector3.new(AnchorPoint.X, 0, AnchorPoint.Z)) * CFrame.fromEulerAnglesXYZ(math.rad(Angle),0,0)
				Part.CFrame = CFrame.lookAt(Part.Position, Vector3.new(AnchorPoint.X, 0, AnchorPoint.Z))

				Part.CFrame = Part.CFrame * CFrame.new(0,-2.5,0)

				TweenService:Create(Part, TweenInfo.new(settings.AnimationSpeed or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = cframeTo}):Play()
				task.spawn(function()
					task.wait(settings.HoldTime)
					local Tween = TweenService:Create(Part, TweenInfo.new(randInt(1, 2), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(0,0,0)})
					Tween:Play()
					Tween.Completed:Wait()
					Part:Destroy()
				end)
			end
		end
	end,
}