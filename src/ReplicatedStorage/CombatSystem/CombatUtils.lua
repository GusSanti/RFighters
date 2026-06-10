local module = {}

function module.IsCharacterInAir(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root then
		return false
	end

	local rayOrigin = root.Position
	local rayDirection = Vector3.new(0, -4, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { game.Workspace:WaitForChild("Map") }
	params.IgnoreWater = true

	local result = game.Workspace:Raycast(rayOrigin, rayDirection, params)

	return result == nil
end

return module
