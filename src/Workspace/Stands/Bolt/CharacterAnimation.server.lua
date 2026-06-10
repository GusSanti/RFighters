local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Referências
local viewportFrame = script.Parent -- ajuste o caminho
local character = script.Parent

-- ID da animação idle (troca pelo teu)
local IDLE_ANIM_ID = "rbxassetid://72636252867504" -- idle padrão Roblox

local function setupIdleAnimation()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Precisa de um Animator dentro do Humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Cria e carrega a animação
	local animation = Instance.new("Animation")
	animation.AnimationId = IDLE_ANIM_ID

	local animTrack = animator:LoadAnimation(animation)
	animTrack.Looped = true
	animTrack:Play()
end

setupIdleAnimation()
