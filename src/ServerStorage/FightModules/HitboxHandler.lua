local RunService = game:GetService("RunService")

local HitboxHandler = {}
HitboxHandler.__index = HitboxHandler

function HitboxHandler.new()
	local self = setmetatable({}, HitboxHandler)

	self.Size = Vector3.new(5, 5, 5)
	self.HitType = "Multiple" 
	self.Ignore = {} 
	self.OnTouch = nil
	self.Active = false
	self.VisualPart = nil
	self.ShowVisual = false

	self.OverlapParams = OverlapParams.new()
	self.OverlapParams.FilterType = Enum.RaycastFilterType.Exclude
	self.OverlapParams.FilterDescendantsInstances = {}

	self.WeldConstraint = nil
	self.TargetPart = nil 

	self.WeldConfig = {
		Enabled = true,
		Offset = CFrame.new(),
	}

	self._heartbeatConnection = nil
	self._destroyed = false

	return self
end

function HitboxHandler:AttachToCharacter(character)
	if self._destroyed or not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	self.TargetPart = hrp
	self:AddToIgnore(character)
end

function HitboxHandler:AttachToPart(part, character)
	if self._destroyed or not part then return end
	self.TargetPart = part

	self:AddToIgnore(part)
	if character then self:AddToIgnore(character) end
end

function HitboxHandler:SetOffset(offsetCFrame)
	if self._destroyed or typeof(offsetCFrame) ~= "CFrame" then return end
	self.WeldConfig.Offset = offsetCFrame

	if self.TargetPart and self.VisualPart then
		self:ConnectToTarget()
	end
end

function HitboxHandler:SetSize(newSize)
	if self._destroyed or typeof(newSize) ~= "Vector3" then return end
	self.Size = newSize
	if self.VisualPart then
		self.VisualPart.Size = newSize
	end
end

function HitboxHandler:AddToIgnore(instance)
	if self._destroyed or not instance then return end
	if not table.find(self.Ignore, instance) then
		table.insert(self.Ignore, instance)
		self.OverlapParams.FilterDescendantsInstances = self.Ignore
	end
end

function HitboxHandler:EnableVisual(enabled)
	self.ShowVisual = enabled

	if enabled and not self.VisualPart then
		self:CreateVisualPart()
		self:ConnectToTarget()
	elseif not enabled and self.VisualPart then
		self.VisualPart:Destroy()
		self.VisualPart = nil
		if self.WeldConstraint then
			self.WeldConstraint:Destroy()
			self.WeldConstraint = nil
		end
	end
end

function HitboxHandler:CreateVisualPart(visible)
	if self._destroyed then return end
	if self.VisualPart then self.VisualPart:Destroy() end

	local part = Instance.new("Part")
	part.Name = "HitboxVisual"
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = (visible == false) and 1 or 0.6 
	part.Material = Enum.Material.Neon
	part.CastShadow = false
	part.Color = Color3.fromRGB(255, 0, 0)
	part.Size = self.Size
	part.Massless = true
	part.Parent = workspace

	self.VisualPart = part
	return part
end

function HitboxHandler:ConnectToTarget()
	if self._destroyed or not self.TargetPart then return end
	if not self.VisualPart then return end

	if self.WeldConstraint then self.WeldConstraint:Destroy() end

	self.VisualPart.CFrame = self.TargetPart.CFrame * self.WeldConfig.Offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = self.TargetPart
	weld.Part1 = self.VisualPart
	weld.Parent = self.VisualPart
	self.WeldConstraint = weld
end

function HitboxHandler:GetHitboxCFrame()
	if self._destroyed or not self.TargetPart then return CFrame.new() end
	return self.TargetPart.CFrame * self.WeldConfig.Offset
end

function HitboxHandler:CheckHits(sessionHits)
	if self._destroyed or not self.TargetPart then return end

	local hitboxCFrame = self:GetHitboxCFrame()
	local parts = workspace:GetPartBoundsInBox(hitboxCFrame, self.Size, self.OverlapParams)
	local frameHits = {} 

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorWhichIsA("Model")
		local humanoid = model and model:FindFirstChild("Humanoid")

		if model and humanoid and humanoid.Health > 0 then
			if sessionHits and sessionHits[model] then continue end

			if not frameHits[model] then
				frameHits[model] = true
				if sessionHits then sessionHits[model] = true end

				if self.OnTouch then
					self.OnTouch(model, humanoid)
				end

				if self.HitType == "Single" then return true end
			end
		end
	end
	return false
end

function HitboxHandler:CheckForDuration(duration)
	if self._destroyed or self.Active then return end
	self.Active = true
	local startTime = tick()
	local sessionHits = {} 

	self._heartbeatConnection = RunService.Heartbeat:Connect(function()
		if self._destroyed then 
			self:Stop()
			return 
		end

		if tick() - startTime >= duration then
			self:Cleanup()
			return
		end

		local hit = self:CheckHits(sessionHits)
		if hit and self.HitType == "Single" then
			self:Cleanup()
		end
	end)
end

function HitboxHandler:Stop()
	self.Active = false
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end
end

function HitboxHandler:Once()
	if self._destroyed then return end
	self:CheckHits({})
end

function HitboxHandler:Cleanup()
	if self._destroyed then return end
	self._destroyed = true

	self:Stop() 

	if self.VisualPart then 
		self.VisualPart:Destroy() 
		self.VisualPart = nil
	end

	if self.WeldConstraint then
		self.WeldConstraint:Destroy()
		self.WeldConstraint = nil
	end

	self.TargetPart = nil
	self.Ignore = {}
	self.OnTouch = nil
end

function HitboxHandler:Destroy()
	self:Cleanup()
end

return HitboxHandler