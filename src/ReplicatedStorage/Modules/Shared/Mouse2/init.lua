--- Jiwonz
local m2 = {}
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local screen = script:WaitForChild("MouseFixScreen")
local sys_cursors = require(script:WaitForChild("SystemCursors"))
local thread = require(script:WaitForChild("Thread"))
local gui = player:WaitForChild("PlayerGui")
local services = {
	rs = game:GetService("RunService");
	uis = game:GetService("UserInputService");
	tw = game:GetService("TweenService");
	de = game:GetService("Debris");
	gs = game:GetService("GuiService");
}
local camera = game.Workspace.CurrentCamera

function m2:IsFirstPerson()
	return (camera.Focus.p - camera.CoordinateFrame.p).Magnitude <= 1
end

function m2:CursorUpdate()
	if self:IsFirstPerson() then
		if self.cursor.Position ~= UDim2.fromScale(0.5,0.5) then
			self.cursor.Position = UDim2.fromScale(0.5,0.5)
			if not self.cursor.Parent.IgnoreGuiInset then self.cursor.Parent.IgnoreGuiInset = true end
		end
	else
		if self.cursor.Position ~= UDim2.fromOffset(mouse.X,mouse.Y) then 
			self.cursor.Position = UDim2.fromOffset(mouse.X,mouse.Y) 
			if self.cursor.Parent.IgnoreGuiInset then self.cursor.Parent.IgnoreGuiInset = false end
		end
	end
end

function m2:TrailStart(t,r)
	thread:Spawn(function()
		while self.trail_enabled do
			local trail = self.cursor:Clone()
			trail.Parent = self.cursor.Parent
			services.tw:Create(trail,TweenInfo.new(t),{ImageTransparency=1}):Play()
			services.de:AddItem(trail,t)
			thread:Wait(r)
		end
	end)
end

function m2:SetSize(vec2)
	self.cursor.Size = UDim2.fromOffset(vec2.X,vec2.Y)
end

function m2:GetSize()
	return Vector2.new(self.cursor.Size.X.Offset,self.cursor.Size.Y.Offset)
end

function m2:SetTransparency(n)
	self.cursor.ImageTransparency = n
end

function m2:SetColor(c3)
	self.cursor.ImageColor3 = c3
end

function m2:Hide(bool)
	self.cursor.Visible = not bool
end

function m2:GetSystemCursor(s)
	local cursor = sys_cursors[s]
	if cursor then
		return string.format("rbxasset://textures/Cursors/KeyboardMouse/%s",cursor)
	end
end

function m2:SetIcon(id)
	if not id then id = "" end
	if id == "" then
		self.system_cursor = true
		self.cursor.Image = self:GetSystemCursor("PointingHand")
		self:SetSize(Vector2.new(70,70))
	else
		self.system_cursor = false
		self.cursor.Image = id
	end
end

function m2:GetUnitRay()
	if self:IsFirstPerson() then
		local viewportpoint = camera.ViewportSize / 2
		local unit_ray = camera:ViewportPointToRay(viewportpoint.X, viewportpoint.Y, 0)
		return unit_ray
	else
		return mouse.UnitRay
	end
end

function m2:GetHit()
	local unit_ray = self:GetUnitRay()
	local raycastParams = RaycastParams.new()
	if player.Character then raycastParams.FilterDescendantsInstances = {camera, player.Character, workspace.FX} else raycastParams.FilterDescendantsInstances = {camera, workspace.Debris} end
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local ray = workspace:Raycast(unit_ray.Origin, unit_ray.Direction*1000,raycastParams)
	if ray then return CFrame.new(ray.Position) else return mouse.Hit end
end

return m2
--[[
return function()
	screen.Parent = gui
	services.uis.MouseIconEnabled = false
	
	local cursor = screen:WaitForChild("cursor")
	cursor.AnchorPoint = Vector2.new(0.5,0.5)
	
	local self = m2
	self.cursor = cursor;
	
	services.rs.RenderStepped:Connect(function() self:CursorUpdate() end)
	
	self.system_cursor = true
	mouse.Icon = ""
	cursor.Image = self:GetSystemCursor("PointingHand")
	
	local function handleGuiCursor(b)
		local can = b.Visible
		b:GetPropertyChangedSignal("Visible"):Connect(function()
			can = b.Visible
		end)
		b.MouseEnter:Connect(function()
			if self.system_cursor then
				self.cursor.Image = self:GetSystemCursor("Arrow")
			end
		end)
		b.MouseLeave:Connect(function()
			if self.system_cursor then
				self.cursor.Image = self:GetSystemCursor("PointingHand")
			end
		end)
	end
	
	gui.DescendantAdded:Connect(function(b)
		if b:IsA("ImageButton") or b:IsA("TextButton") then
			handleGuiCursor(b)
		end
	end)
	for i,b in pairs(gui:GetDescendants()) do
		if b:IsA("ImageButton") or b:IsA("TextButton") then
			handleGuiCursor(b)
		end
	end
	
	services.gs.MenuOpened:Connect(function() self:Hide(true) end)
	services.gs.MenuClosed:Connect(function() self:Hide(false) end)
	
	if services.uis.TouchEnabled and not services.uis.KeyboardEnabled and not services.uis.MouseEnabled
		and not services.uis.GamepadEnabled and not services.gs:IsTenFootInterface() then
		self:Hide(true)
	end
	
	return setmetatable(self,{__index = function(_,w) warn(w) return mouse[w] end})
end
--]]