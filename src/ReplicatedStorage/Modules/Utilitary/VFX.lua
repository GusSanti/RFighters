-- module to control vfx

local VFX = {}

function VFX.play(Holder : BasePart)
	task.spawn(function()
		for _,v in pairs(Holder:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				local EmitCount = v:GetAttribute('EmitCount') or 0
				local EmitDelay = v:GetAttribute('EmitDelay') or 0
				local EmitDuration = v:GetAttribute('EmitDuration') or 0
				
				task.delay(EmitDelay,function()
					v:Emit(EmitCount)
					v.Enabled = EmitDuration > 0
				end)
				if EmitDuration > 0 then
					task.delay(EmitDuration + EmitDelay,function()
						v.Enabled = false
					end)
				end
			elseif v:IsA("Trail") then
				local EmitDelay = v:GetAttribute('EmitDelay') ~= nil and v:GetAttribute('EmitDelay') or 0
				local EmitDuration = v:GetAttribute('EmitDuration') ~= nil and v:GetAttribute('EmitDuration') or 0
				
				task.delay(EmitDelay,function()
					v.Enabled = EmitDuration > 0
				end)
				if EmitDuration > 0 then
					task.delay(EmitDuration + EmitDelay,function()
						v.Enabled = false
					end)
				end
			end
		end
	end)
end

function VFX.enable(Holder : BasePart, boolean:boolean)
	for _,v in pairs(Holder:GetDescendants()) do
		if v:IsA('ParticleEmitter') or v:IsA("Beam") or v:IsA("Trail") then
			v.Enabled = boolean
		end
	end
end

function VFX.flipbookMesh(Holder:BasePart|Model, Framerate:number)
	local function flip(basePart:BasePart)
		local Flips = basePart.flips
		local decal:Decal = basePart.Decal
		
		for i,v:Decal in pairs(Flips:GetChildren()) do
			decal.Texture = Flips[i].Texture
			task.wait(1/Framerate)
			if i == #Flips:GetChildren() then
				decal.Transparency = 1
			end
		end
	end
	
	if Holder:IsA("BasePart") and Holder:FindFirstChild("flips") then
		task.spawn(function()
			flip(Holder)
		end)
	elseif Holder:IsA("Model") then
		for _,parts in pairs(Holder:GetChildren()) do
			if parts:IsA("BasePart") and parts:FindFirstChild("flips") then
				task.spawn(function()
					flip(parts)
				end)
			end
		end
	end
end

function VFX.Afterimage(Character:Model, Lifetime:number, Animation:Animation, TimePos:number)
	local Animator:Animator = Character.Humanoid.Animator
	local copiedCharacter
	
	if not Character.Archivable then
		Character.Archivable = true
		copiedCharacter = Character:Clone()
		Character.Archivable = false
	else
		copiedCharacter = Character:Clone()
	end
	
	if copiedCharacter:FindFirstChildWhichIsA("Highlight") then
		copiedCharacter:FindFirstChildWhichIsA("Highlight"):Destroy()
	end
	
	for _,v in pairs(copiedCharacter:GetDescendants()) do
		if v:IsA("BasePart") then
			v.CollisionGroup = "NoCollide"
			v.CastShadow = false
			VFX.Tween(v, TweenInfo.new(Lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 1})
		elseif v:IsA("Decal") then
			VFX.Tween(v, TweenInfo.new(Lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 1})
		end
	end
	
	copiedCharacter.Parent = workspace.World.Visuals
	copiedCharacter.HumanoidRootPart.Anchored = true
	task.delay(Lifetime,function()
		copiedCharacter:Destroy()
	end)
	
	local track:AnimationTrack = copiedCharacter.Humanoid.Animator:LoadAnimation(Animation)
	track:Play(0)
	track:AdjustSpeed(0)
	track.TimePosition = TimePos
	
	return copiedCharacter
end

function VFX.Tween(obj,tweenInfo:TweenInfo,goal)
	local tw = game:GetService("TweenService"):Create(obj,tweenInfo,goal)
	tw:Play()
	tw:Destroy()
	return tw
end

function VFX.Highlight(target:BasePart|Model, color:Color3, duration:number)
	if target:FindFirstChildWhichIsA("Highlight") then
		target:FindFirstChildWhichIsA("Highlight"):Destroy()
	end
	
	local Highlight = Instance.new("Highlight")
	Highlight.FillTransparency = 0.5
	Highlight.OutlineTransparency = 0
	Highlight.OutlineColor = color or Color3.fromRGB(255,255,255)
	Highlight.FillColor = color or Color3.fromRGB(255,255,255)
	Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	Highlight.Parent = target
	VFX.Tween(Highlight, TweenInfo.new(duration or 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {OutlineTransparency = 1, FillTransparency = 1})
	task.delay(duration or 0.5,function()
		Highlight:Destroy()
	end)
end

function VFX.vfxTween(referenceModel:Model, twInfo:TweenInfo)
	local Start:BasePart = referenceModel:FindFirstChild("Start")
	local End:BasePart  = referenceModel:FindFirstChild("End")

	VFX.Tween(Start,twInfo, {Size = End.Size, CFrame = End.CFrame, Color = End.Color, Transparency = End.Transparency})
	End.Transparency = 1
	for _,v in pairs(Start:GetChildren()) do
		if v:IsA("SpecialMesh") then
			local endMesh = End.Mesh
			VFX.Tween(v,twInfo, {Scale = endMesh.Scale})
		elseif v:IsA("Decal") and End:FindFirstChildWhichIsA("Decal") then
			local endDecal:Decal = End.Decal
			VFX.Tween(v,twInfo, {Transparency = endDecal.Transparency, Color3 = endDecal.Color3})
		end
	end
	
	if End:FindFirstChild("Decal") then
		End:FindFirstChild("Decal").Transparency = 1
	end
	
	task.delay(twInfo.Time, function()
		End.Transparency = 1
		Start.Transparency = 1
		if Start:FindFirstChild("Decal") then
			Start:FindFirstChild("Decal").Transparency = 1
		end
		if Start:FindFirstChildWhichIsA("Highlight") then
			Start:FindFirstChildWhichIsA("Highlight"):Destroy()
		end
	end)
end

return VFX