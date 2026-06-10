--|| Services ||--
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ServerStorage = game:GetService("ServerStorage")
local Tween = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

--|| Directories ||--
local Modules = ReplicatedStorage.Modules
local Shared = Modules.Shared
local Remotes = ReplicatedStorage.Events

--|| Remotes ||--
local HandlerServer = Remotes.HandlerFireServer
local HandlerClient = Remotes.HandlerFireClient


--|| Abbreviations ||--
local rand = math.random

local Debris = {}

function Debris.FlyingRocks(Char,MainCFrame,Amount,Size,Velocity,DebrisTime,Destroy)
	if Amount ~= nil and Size ~= nil and MainCFrame ~= nil and Char then
		
		local MinPower = Velocity[1] or 30
		local MaxPower = Velocity[2] or 45
		
		--// Rocks //--
		for i=1,Amount do
			
			local Rock = Instance.new("Part")
			Rock.Parent = workspace.FX
			Rock.Size = Size
			Rock.CFrame = MainCFrame
			Rock.CanCollide = false
			Rock.Massless = true
			Rock.Material = Enum.Material.Rock
			Rock.Color = Color3.fromRGB(52, 52, 52)
			Rock.Orientation = Vector3.new(math.random(-360,360),math.random(-360,360),math.random(-360,360))
			if DebrisTime then
				game.Debris:AddItem(Rock,DebrisTime)
			end
			
			local Trail = nil
			for i,v in pairs(script.TrailPart:GetChildren()) do
				local n = v:Clone()
				n.Parent = Rock
				if v:IsA("Trail") then
					Trail = n
				end
			end
			
			Trail.Attachment0 = Rock.A0
			Trail.Attachment1 = Rock.A1
			
			--// First Raycast //--
			local Param = RaycastParams.new()
			Param.FilterType = Enum.RaycastFilterType.Exclude
			Param.IgnoreWater = true
			Param.FilterDescendantsInstances = {workspace.FX,Char,workspace.NPCS}
			
			local rayOrigin,rayDirection = Rock.Position, Vector3.new(0, -1, 0) * 10
			
			local Hit = workspace:Raycast(rayOrigin,rayDirection,Param)
			if Hit then
				Rock.Material = Hit.Instance.Material
				Rock.Color = Hit.Instance.Color
			end
			
			Rock.Velocity = Vector3.new(math.random(-MaxPower,MaxPower),math.random(MinPower,MaxPower),math.random(-MaxPower,MaxPower))
			
		end
		
	end
end

function Debris.Crater(Char,MainCFrame,Amount,Size,TimeProps)
	if Char and MainCFrame and Amount and Size then
		
		for i=1, Amount do 
			
			
			
		end
		
	end
end

return Debris
