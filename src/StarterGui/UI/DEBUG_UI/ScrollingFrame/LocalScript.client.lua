local template = script.Parent.Template
local UpdateEvent = game.ReplicatedStorage.StateManager.Remotes.UPDATE_EVENT

local Enabled = false

if not Enabled then
	script.Parent.Parent:Destroy()
else
	script.Parent.Parent.Visible = true
end

UpdateEvent.OnClientEvent:Connect(function(newstats)
	if not Enabled then return end
	
	for _, statframe in script.Parent:GetChildren() do
		if statframe:IsA("TextLabel") then
			statframe:Destroy()
		end
	end
	
	for stat in newstats do
		print(stat)
		local statframe = template:Clone()
		statframe.Parent = script.Parent
		statframe.Visible = true
		statframe.Text = stat
		statframe.TextColor3 = Color3.fromRGB(255, 255, 255)
		statframe.TextStrokeTransparency = 0
		statframe.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		statframe.TextSize = 14
	end
end)