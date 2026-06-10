local Debris = game:GetService("Debris")
local module = {}
module.particleType = {
	electricSparks = 0
}
function module:emit(particleType, cframe, velocity, rate, size, lifetime, collideable, timeToVanish)
	if particleType == 0 then
		for i = rate, 0, -1 do
			local part = Instance.new("Part")
			local trail = Instance.new("Trail")
			local trace0 = Instance.new("Attachment", workspace.Terrain)
			local trace1 = Instance.new("Attachment", workspace.Terrain)
			part.Anchored = false
			part.CanCollide = collideable
			part.CastShadow = false
			part.Locked = true
			part.Massless = true
			part.Transparency = 1
			part.Size = Vector3.new(0.1, 0.1, 0.1)
			part.CFrame = cframe + Vector3.new(math.random(0, 1) * size, part.Size.Y / 2, math.random(0, 1) * size)
			part.Parent = workspace.Ignore
			trace0.Parent = part
			trace1.Parent = part
			trace0.Position -= Vector3.new(1, 1, 1) * size
			trace1.Position += Vector3.new(1, 1, 1) * size
			trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255))
			trail.Transparency = NumberSequence.new(0)
			trail.WidthScale = NumberSequence.new(size)
			trail.FaceCamera = true
			trail.Lifetime = lifetime
 			trail.LightEmission = 1
			trail.LightInfluence = 1 
			trail.Attachment0 = trace0
			trail.Attachment1 = trace1
			trail.Parent = part
			part.Velocity = Vector3.new(math.random(-velocity, velocity), math.random(-velocity, velocity), math.random(-velocity, velocity)) -- TODO: Replace .Velocity with the new method because this is going to be deprecated!
			Debris:AddItem(part, timeToVanish)
		end
	end
end
return module