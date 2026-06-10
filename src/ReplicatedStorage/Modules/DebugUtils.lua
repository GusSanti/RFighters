local debugUtils = {}

function debugUtils.DebugRaycast(origin, direction, result)
	local rayPart = Instance.new("Part")
	rayPart.Anchored = true
	rayPart.CanCollide = false
	rayPart.Material = Enum.Material.Neon
	rayPart.BrickColor = BrickColor.Red()
	rayPart.Size = Vector3.new(0.1, 0.1, direction.Magnitude)
	rayPart.CFrame = CFrame.new(origin, origin + direction) * CFrame.new(0, 0, -direction.Magnitude/2)
	rayPart.Name = "DebugRay"
	rayPart.Parent = workspace
	rayPart.CanQuery = false

	-- Dura 3 segundos e some
	game:GetService("Debris"):AddItem(rayPart, 0.1)

	if result then
		local hitPart = Instance.new("Part")
		hitPart.Anchored = true
		hitPart.CanCollide = false
		hitPart.Size = Vector3.new(0.3, 0.3, 0.3)
		hitPart.Shape = Enum.PartType.Ball
		hitPart.Material = Enum.Material.Neon
		hitPart.BrickColor = BrickColor.Green()
		hitPart.CFrame = CFrame.new(result.Position)
		hitPart.Parent = workspace
		hitPart.CanQuery = false
		
		if result.Instance then
			print(result.Instance)
		end

		game:GetService("Debris"):AddItem(hitPart, 10)
	end
end

function debugUtils.createPartGhost(part: BasePart)
	local partGhost = Instance.new("Part")
	partGhost.Name = "DebugPart"
	partGhost.CanCollide = false
	partGhost.CanQuery = false
	partGhost.Anchored = true
	partGhost.Material = Enum.Material.Neon
	partGhost.BrickColor = BrickColor.Red()
	partGhost.CFrame = part.CFrame
	partGhost.Transparency = 0.8
	partGhost.Parent = workspace
	
	game:GetService("Debris"):AddItem(partGhost, 3)
end

return debugUtils
