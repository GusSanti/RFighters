-- Animate (Server Script)
-- Coloca esse Script dentro de OfflineBot > Animate
-- Tipo: Script (não LocalScript)

local bot = script.Parent
local humanoid = bot:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")

task.wait(4.5)

-- =============================================
-- CONFIGURAÇÃO DAS ANIMAÇÕES
-- Troca os IDs pelas animações que você quiser
-- =============================================
local ANIMS = {
	idle  = "rbxassetid://107967072317239",  -- Idle padrão do Roblox
	walk  = "rbxassetid://507777826",  -- Walk padrão
	run   = "rbxassetid://507767714",  -- Run padrão
	jump  = "rbxassetid://507765000",  -- Jump padrão
	fall  = "rbxassetid://507767968",  -- Fall padrão
}

-- =============================================
-- CARREGA AS ANIMAÇÕES
-- =============================================
local tracks = {}

local function loadAnim(name, id)
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local track = animator:LoadAnimation(anim)
	track.Name = name
	-- Idle tem prioridade Idle, o resto Action
	if name == "idle" then
		track.Priority = Enum.AnimationPriority.Idle
	else
		track.Priority = Enum.AnimationPriority.Action
	end
	return track
end

for name, id in pairs(ANIMS) do
	tracks[name] = loadAnim(name, id)
end

-- =============================================
-- LÓGICA DO IDLE PERSISTENTE
-- O idle toca em loop e nunca é parado diretamente.
-- Outras anims tocam por cima (prioridade Action).
-- Quando param, o idle já está rodando embaixo.
-- =============================================

local function playIdle()
	if not tracks.idle.IsPlaying then
		tracks.idle:Play()
	end
end

-- Inicia o idle imediatamente
tracks.idle.Looped = true
playIdle()

-- Garante que o idle volta caso seja parado acidentalmente
tracks.idle.Stopped:Connect(function()
	task.wait() -- espera 1 frame
	playIdle()
end)

-- =============================================
-- CONTROLE DE ESTADO DE MOVIMENTO
-- =============================================
local currentState = "idle"

local function stopActionAnims()
	for name, track in pairs(tracks) do
		if name ~= "idle" and track.IsPlaying then
			track:Stop()
		end
	end
end

local function setState(state)
	if currentState == state then return end
	currentState = state

	stopActionAnims()

	if state == "walk" and tracks.walk then
		tracks.walk.Looped = true
		tracks.walk:Play()
	elseif state == "run" and tracks.run then
		tracks.run.Looped = true
		tracks.run:Play()
	elseif state == "jump" and tracks.jump then
		tracks.jump.Looped = false
		tracks.jump:Play()
	elseif state == "fall" and tracks.fall then
		tracks.fall.Looped = true
		tracks.fall:Play()
	end
	-- state == "idle": só para as outras, o idle já está rodando
end

-- =============================================
-- DETECTA ESTADO PELO HumanoidStateType
-- =============================================
humanoid.StateChanged:Connect(function(_, newState)
	if newState == Enum.HumanoidStateType.Running then
		local speed = humanoid.WalkSpeed
		if humanoid.MoveDirection.Magnitude > 0.1 then
			if speed >= 16 then
				setState("run")
			else
				setState("walk")
			end
		else
			setState("idle")
		end

	elseif newState == Enum.HumanoidStateType.Jumping
		or newState == Enum.HumanoidStateType.Freefall then
		setState("jump")

	elseif newState == Enum.HumanoidStateType.Landed
		or newState == Enum.HumanoidStateType.GettingUp then
		setState("idle")

	elseif newState == Enum.HumanoidStateType.Dead then
		stopActionAnims()
		if tracks.idle.IsPlaying then
			tracks.idle:Stop()
		end
	end
end)

-- Fallback: verifica velocidade a cada 0.1s para casos onde
-- StateChanged não dispara (ex: mover sem pular)
task.spawn(function()
	while humanoid and humanoid.Health > 0 do
		task.wait(0.1)
		local moving = humanoid.MoveDirection.Magnitude > 0.1

		if currentState == "idle" and moving then
			if humanoid.WalkSpeed >= 16 then
				setState("run")
			else
				setState("walk")
			end
		elseif (currentState == "walk" or currentState == "run") and not moving then
			setState("idle")
		end

		-- Garante que idle está sempre tocando em background
		playIdle()
	end
end)

print("[Animate] Bot animado com idle persistente.")