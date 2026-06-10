local ZoneController = {}

local Effects = require(script.Parent.Parent.Parent.Effects)

local currentZone = nil

local ZoneUIMap = {} -- preenchido via ZoneController.Init(map)

local function onEnterZone(zonePart)
	if currentZone == zonePart then return end
	if currentZone then
		local prev = ZoneUIMap[currentZone]
		if prev and prev.Visible then Effects.ToggleUI(prev) end
	end
	currentZone = zonePart
	local target = ZoneUIMap[zonePart]
	if target and not target.Visible then Effects.ToggleUI(target) end
end

local function onExitZone(zonePart)
	if currentZone ~= zonePart then return end
	local target = ZoneUIMap[zonePart]
	if target and target.Visible then Effects.ToggleUI(target) end
	currentZone = nil
end

local function setupZone(zonePart, localPlayer, CharacterSelectionUI)
	zonePart.CanCollide = false
	zonePart.CanQuery = false
	zonePart.Touched:Connect(function(hit)
		local char = localPlayer.Character
		if char and hit == char:FindFirstChild("HumanoidRootPart") and not CharacterSelectionUI.Visible then
			onEnterZone(zonePart)
		end
	end)
	zonePart.TouchEnded:Connect(function(hit)
		local char = localPlayer.Character
		if char and hit == char:FindFirstChild("HumanoidRootPart") then
			onExitZone(zonePart)
		end
	end)
end

function ZoneController.Init(zoneUIMap, localPlayer, CharacterSelectionUI)
	ZoneUIMap = zoneUIMap
	for zonePart in pairs(ZoneUIMap) do
		setupZone(zonePart, localPlayer, CharacterSelectionUI)
	end

	localPlayer.CharacterAdded:Connect(function()
		if currentZone then
			local target = ZoneUIMap[currentZone]
			if target and target.Visible then Effects.ToggleUI(target) end
			currentZone = nil
		end
	end)
end

function ZoneController.GetCurrentZone()
	return currentZone
end

return ZoneController