-- FovModule
local FovModule = {}

-- Serviços
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Variáveis de configuração
local defaultFov = 70
local transitionTime = 0.5

-- Função para configurar o FOV padrão e o tempo de transição
function FovModule:Configure(newDefaultFov, newTransitionTime)
	defaultFov = newDefaultFov or defaultFov
	transitionTime = newTransitionTime or transitionTime
end

-- Função para alterar o FOV com Tween
function FovModule:SetFov(camera, targetFov, duration)
	duration = duration or transitionTime

	local tweenInfo = TweenInfo.new(
		duration,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(camera, tweenInfo, {FieldOfView = targetFov})
	tween:Play()
end

-- Função para resetar o FOV para o valor padrão
function FovModule:ResetFov(camera, duration)
	self:SetFov(camera, defaultFov, duration)
end

return FovModule