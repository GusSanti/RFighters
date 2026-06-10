local module = {}
local TweenService = game:GetService("TweenService")

local r6Parts = {
	"Head", "Torso", 
	"Left Arm", "Right Arm", 
	"Left Leg", "Right Leg", "Lower Torso", "Helmet", 
}

local function cloneclones(Part:Part, LifeTime, Color, FadeInTime, Transparency, ParentFolder)
	local New = Part:Clone() -- Clona a parte
	New.Anchored = true
	New.CanCollide = false
	New.Color = Color
	New.Material = Enum.Material.SmoothPlastic
	New.Transparency = 1

	if New:IsA("MeshPart") then -- Remove texturas dos meshes
		New.TextureID = ""
	end

	for i, Obj in pairs(New:GetDescendants()) do -- Remove attachments para prevenir o personagem ficar preso
		if Obj:IsA("SpecialMesh") then
		else
			Obj:Destroy()
		end
	end

	New.Parent = ParentFolder

	task.spawn(function()
		-- Fade in do clone
		local goal = {}
		goal.Transparency = Transparency
		local tweenInfo = TweenInfo.new(FadeInTime, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
		local tween = TweenService:Create(New, tweenInfo, goal)
		tween:Play()
		task.wait(FadeInTime)

		-- Fade out
		local goal = {}
		goal.Transparency = 1
		local tweenInfo = TweenInfo.new(LifeTime, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
		local tween = TweenService:Create(New, tweenInfo, goal)
		tween:Play()
		task.wait(LifeTime)
		New:Destroy()
	end)
end

function module.CreateClone(character, LifeTime, Color, FadeInTime, fadeOutTime, Transparency)
	local FXFolder = workspace.FX


	-- Cria uma pasta específica para este conjunto de clones
	local CloneFolder = Instance.new("Folder")
	CloneFolder.Name = character.Name .. "_Clone_" .. tick()
	CloneFolder.Parent = FXFolder

	-- Clona os acessórios
	for _, accessory in pairs(character:GetChildren()) do
		if accessory:IsA("Accessory") then
			local handle = accessory:FindFirstChild("Handle")
			if handle then
				cloneclones(handle, LifeTime, Color, FadeInTime, Transparency, CloneFolder)
			end
		elseif accessory:IsA("Shirt") or accessory:IsA("Pants") then
			-- Roupas não têm partes visíveis para clonar
			continue
		end
	end

	-- Clona as partes do corpo R6
	for _, partName in pairs(r6Parts) do
		local Part = character:FindFirstChild(partName)
		if Part then
			if Part:IsA("BasePart") then
				cloneclones(Part, LifeTime, Color, FadeInTime, Transparency, CloneFolder)
			end
		end
	end

	-- Remove a pasta do clone após o tempo de vida total
	task.delay(LifeTime + FadeInTime, function()
		if CloneFolder and CloneFolder.Parent then
			CloneFolder:Destroy()
		end
	end)
end

return module