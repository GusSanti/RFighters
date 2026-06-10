-- //Services// --
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- //Module// --
local BubbleModule = {}

-- Função que cria uma onda individual
local function CreateSingleWave(CF, StartSize, StartTr, EndSize, Time)
	local Part = script.Mesh:Clone()
	Part.CFrame = CF
	Part.Anchored = true
	Part.CanCollide = false
	Part.Massless = true
	Part.Parent = workspace:FindFirstChild("Ignore") or workspace
	Part.Material = Enum.Material.Glass
	Part.Size = StartSize
	Part.Transparency = StartTr

	local RequiredHighlight = Instance.new("Highlight")
	RequiredHighlight.Enabled = false
	RequiredHighlight.Parent = Part

	-- Tween de expansão + fade
	local ExpandTween = TweenService:Create(Part, TweenInfo.new(
		Time * 0.2,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.Out
		), {
			Transparency = 0.6,
			Size = EndSize
		})

	-- Tween de encolhimento rápido
	local ShrinkTween = TweenService:Create(Part, TweenInfo.new(
		Time * 0.1,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.In
		), {
			Transparency = 1,
			Size = Vector3.new(0.1, 0.1, 0.1)
		})

	ExpandTween:Play()
	ExpandTween.Completed:Connect(function()
		ShrinkTween:Play()
	end)

	Debris:AddItem(Part, Time)
end

-- Função principal que cria múltiplas ondas consecutivas
function BubbleModule.CreateBubble(CF, StartSize, StartTr, EndSize, Time, Waves, WaveDelay)
	Waves = Waves or 3       -- Número de ondas
	WaveDelay = WaveDelay or 0.2 -- Intervalo entre ondas

	for i = 1, Waves do
		task.delay((i-1) * WaveDelay, function()
			CreateSingleWave(CF, StartSize, StartTr, EndSize, Time)
		end)
	end
end

return BubbleModule
