--!strict
-- InviteRewards.lua  (Client)
-- Coloca em: LocalScript.Systems.InviteRewards

local InviteRewards = {}

local Players           = game:GetService("Players")
local StarterGui        = game:GetService("StarterGui")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService     = game:GetService("SocialService")

local InviteEvents: RemoteEvent = ReplicatedStorage.Events:WaitForChild("InviteEvents")

-- ─────────────────────────────────────────
-- Referências de UI
-- ─────────────────────────────────────────

local PlayerGui  = Players.LocalPlayer:WaitForChild("PlayerGui")
local UI         = PlayerGui:WaitForChild("UI")
local InviteUI   = UI:WaitForChild("InviteRewards")
local MAIN       = InviteUI:WaitForChild("MAIN")

local BarBG      = MAIN:WaitForChild("BarBG")
local Bar        = BarBG:WaitForChild("Bar")  -- ocupa 100% do BarBG, nunca muda de tamanho

local InviteBtn  = MAIN:FindFirstChild("Invite")    :: GuiButton?
local InviteText = InviteBtn and InviteBtn:FindFirstChild("TextLabel") :: TextLabel?
local HeaderText = MAIN:FindFirstChild("InfoFriendsToInvit") :: TextLabel?

-- Slots Invited1, Invited2, Invited3
type InvitedSlot = { frame: Frame, completed: ImageLabel }
local invitedSlots: { InvitedSlot } = {}
for i = 1, 3 do
	local frame     = MAIN:FindFirstChild("Invited" .. i) :: Frame
	local completed = frame and frame:FindFirstChild("Completed") :: ImageLabel
	if frame and completed then
		table.insert(invitedSlots, { frame = frame, completed = completed })
	end
end

-- Marcadores circulares dentro de BarBG
local barMarkers: { ImageLabel } = {}
for _, child in ipairs(BarBG:GetChildren()) do
	if child:IsA("ImageLabel") then
		table.insert(barMarkers, child :: ImageLabel)
	end
end
table.sort(barMarkers, function(a, b)
	return a.AbsolutePosition.X < b.AbsolutePosition.X
end)

-- ─────────────────────────────────────────
-- Estado local
-- ─────────────────────────────────────────

local currentCount   = 0
local maxInvites     = 3
local isAnimating    = false
local inviteCooldown = false

-- ─────────────────────────────────────────
-- Gradient
--
-- A barra (Bar) ocupa sempre 100% do BarBG.
-- O UIGradient tem:
--   - Esquerda (0): cor normal da barra, transparência 0 → parte preenchida
--   - Ponto de corte (progress): transição rápida branco → preto
--   - Direita (1): preto opaco → parte não preenchida fica escondida
--
-- Para animar, fazemos tween no Offset.X do gradient de -1 até 0,
-- onde Offset desloca o gradiente dentro do frame.
-- Na prática usamos o ColorSequence com keypoints dinâmicos.
-- ─────────────────────────────────────────


--Notification
local function notify(title: string, text: string, duration: number?)
	StarterGui:SetCore("SendNotification", {
		Title    = title,
		Text     = text,
		Duration = duration or 4,
	})
end

local gradient: UIGradient

local function ensureGradient(): UIGradient
	if gradient and gradient.Parent then return gradient end

	local g = Bar:FindFirstChildOfClass("UIGradient")
	if not g then
		g = Instance.new("UIGradient")
		g.Parent = Bar
	end
	gradient = g
	return g
end

-- Atualiza o gradient direto para um progresso (sem animação)
local function setGradientProgress(progress: number)
	-- progress: 0.0 = vazia, 1.0 = cheia
	local g = ensureGradient()

	-- Clampamos para evitar keypoints inválidos (precisam ser 0..1 sem repetição)
	local fill  = math.clamp(progress, 0, 1)
	-- A "borda" do gradiente tem uma pequena transição suave
	local edge  = math.clamp(fill + 0.04, 0, 1)

	if fill <= 0 then
		-- Barra totalmente vazia: tudo preto
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
		})
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.85),
			NumberSequenceKeypoint.new(1, 0.85),
		})
	elseif fill >= 1 then
		-- Barra totalmente cheia: tudo visível
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		})
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 0),
		})
	else
		-- Parte esquerda (preenchida): branco, transparência 0
		-- Transição na borda: branco → preto
		-- Parte direita (vazia): preto escuro
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(fill, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(edge, Color3.fromRGB(30,  30,  30)),
			ColorSequenceKeypoint.new(1,    Color3.fromRGB(0,   0,   0)),
		})
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0,    0),
			NumberSequenceKeypoint.new(fill, 0),
			NumberSequenceKeypoint.new(edge, 0.7),
			NumberSequenceKeypoint.new(1,    0.85),
		})
	end
end

-- Anima o gradient de fromProgress até toProgress
local function animateGradient(fromProgress: number, toProgress: number, onComplete: (() -> ())?)
	if isAnimating then return end
	isAnimating = true

	setGradientProgress(fromProgress)

	-- Tween manual via heartbeat para interpolar os keypoints
	local DURATION = 0.6
	local elapsed  = 0

	local conn: RBXScriptConnection
	conn = game:GetService("RunService").Heartbeat:Connect(function(dt)
		elapsed += dt
		local t = math.clamp(elapsed / DURATION, 0, 1)
		-- Ease out quad
		local eased = 1 - (1 - t) * (1 - t)
		local progress = fromProgress + (toProgress - fromProgress) * eased

		setGradientProgress(progress)

		if t >= 1 then
			conn:Disconnect()
			setGradientProgress(toProgress)
			isAnimating = false
			if onComplete then onComplete() end
		end
	end)
end

-- ─────────────────────────────────────────
-- Visuais
-- ─────────────────────────────────────────

local function updateHeader(count: number, max: number)
	if HeaderText then
		HeaderText.Text = string.format(
			"INVITE %d FRIENDS AND GET THESE REWARDS (%d/%d)",
			max, count, max
		)
	end
end

local function lightMarker(index: number)
	local marker = barMarkers[index]
	if not marker then return end
	TweenService:Create(marker, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		ImageColor3 = Color3.fromRGB(255, 220, 50),
	}):Play()
end

local function completeSlot(index: number)
	local slot = invitedSlots[index]
	if not slot then return end
	slot.completed.Visible = true
	slot.completed.Size    = UDim2.fromScale(0, 0)
	TweenService:Create(
		slot.completed,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(1, 1) }
	):Play()
end

local function rebuildVisual(count: number, max: number)
	maxInvites   = max
	currentCount = count

	setGradientProgress(count / max)

	for i, slot in ipairs(invitedSlots) do
		slot.completed.Visible = (i <= count)
	end
	for i = 1, count do
		lightMarker(i)
	end
	updateHeader(count, max)
end

local function onInviteAdded(newCount: number, max: number)
	local prev   = currentCount
	currentCount = newCount
	maxInvites   = max
	updateHeader(newCount, max)
	animateGradient(prev / max, newCount / max, function()
		completeSlot(newCount)
		lightMarker(newCount)
	end)
end

local function onAllCompleted()
	-- Pisca a barra em dourado
	TweenService:Create(
		Bar,
		TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 4, true),
		{ BackgroundColor3 = Color3.fromRGB(255, 215, 0) }
	):Play()
	if InviteText then
		InviteText.Text = "REWARD CLAIMED!"
		notify("REWARD CLAIMED!", "You've received a reward! 50 Rolls!", 5)
	end
end

-- ─────────────────────────────────────────
-- Botão Invite
-- ─────────────────────────────────────────

function InviteRewards.ButtonAction(_button: GuiButton)
	if currentCount >= maxInvites then return end
	if inviteCooldown then
		warn("[InviteRewards] Aguarde o cooldown.")
		return
	end

	local ok, err = pcall(function()
		SocialService:PromptGameInvite(Players.LocalPlayer)
	end)

	if not ok then
		warn("[InviteRewards] PromptGameInvite falhou:", err)
		return
	end

	-- FireServer removido: o servidor só conta quando alguém realmente entrar

	inviteCooldown = true
	task.delay(0.6, function()
		inviteCooldown = false
	end)
end
-- ─────────────────────────────────────────
-- Eventos do servidor
-- ─────────────────────────────────────────

InviteEvents.OnClientEvent:Connect(function(action: string, ...)
	local args = { ... }

	if action == "SyncInvites" then
		rebuildVisual(args[1] :: number, args[2] :: number)

	elseif action == "InviteAdded" then
		onInviteAdded(args[1] :: number, args[2] :: number)

	elseif action == "AllInvitesCompleted" then
		onAllCompleted()
	end
end)

-- ─────────────────────────────────────────
-- Init
-- ─────────────────────────────────────────

function InviteRewards.Init()
	print("[InviteRewards] Initialized")

	-- Bar ocupa 100% do BarBG, nunca mexemos no Size dela
	Bar.Size = UDim2.fromScale(1, 1)

	for _, slot in ipairs(invitedSlots) do
		slot.completed.Visible = false
	end

	setGradientProgress(0)
	InviteEvents:FireServer("GetInviteData")
end

return InviteRewards