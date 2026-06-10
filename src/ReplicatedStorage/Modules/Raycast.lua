return function(origin, direction, _, filterInstances, blockcastSize)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = filterInstances or {workspace.Map}
	raycastParams.FilterType = Enum.RaycastFilterType.Include

	local result = nil

	if not blockcastSize then
		result = workspace:Raycast(origin, direction, raycastParams)
	else
		result = workspace:Blockcast(CFrame.new(origin), blockcastSize, direction, raycastParams)
	end

	return result
end
