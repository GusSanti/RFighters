local cp = game:GetService("ContentProvider")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local replicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local BATCH_SIZE = 50
local Debug = false

local LOADING_GUI_NAME = "LoadingGui"
local FADE_DURATION = 0.4
local READY_TIMEOUT = 25 -- teto: nunca prende o jogador na tela de loading

-- PlayerState é resolvido após game.Loaded (em ReplicatedFirst o ReplicatedStorage
-- ainda não está garantidamente replicado).
local PlayerState

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

-- ───────── Preload de animações (segundo plano) ─────────
local function startPreload()
	local animationsToLoad = {}
	for _, obj in ipairs(replicatedStorage:GetDescendants()) do
		if obj:IsA("Animation") then
			table.insert(animationsToLoad, obj)
		end
	end

	local totalAnims = #animationsToLoad
	if totalAnims == 0 then
		return
	end

	for i = 1, totalAnims, BATCH_SIZE do
		local batch = {}
		for j = i, math.min(i + BATCH_SIZE - 1, totalAnims) do
			table.insert(batch, animationsToLoad[j])
		end

		local success, err = pcall(function()
			cp:PreloadAsync(batch)
		end)
		if not success then
			warn("[Preloader] Erro no lote:", err)
		end
		task.wait()
	end

	if Debug then
		warn("========== ✅ PRELOAD CONCLUÍDO ==========")
	end
end

-- ───────── Espera o cliente ficar pronto ─────────
local function waitForClientReady(playerGui: Instance?)
	local deadline = os.clock() + READY_TIMEOUT

	-- Dados do jogador replicados
	while PlayerState and not PlayerState.IsReady() and os.clock() < deadline do
		task.wait(0.1)
	end

	-- HUD central construído
	if playerGui then
		local mainUI = playerGui:FindFirstChild("UI")
		while (not mainUI or not mainUI:FindFirstChild("HUD")) and os.clock() < deadline do
			task.wait(0.1)
			mainUI = playerGui:FindFirstChild("UI")
		end
	end
end

-- ───────── Fade + destroy da tela de loading ─────────
local function fadeAndDestroy(gui: Instance)
	local info = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("GuiObject") then
			TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
		end

		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
			TweenService:Create(d, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
			TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
		elseif d:IsA("CanvasGroup") then
			TweenService:Create(d, info, { GroupTransparency = 1 }):Play()
		end
	end

	task.delay(FADE_DURATION, function()
		gui:Destroy()
	end)
end

-- ───────── Boot ─────────
local function fadeLoadingGuis(playerGui: Instance?, primaryGui: Instance?): number
	local faded = {}
	local count = 0

	local function fade(gui: Instance?)
		if not gui or faded[gui] or not gui.Parent then
			return
		end
		if not gui:IsA("ScreenGui") then
			return
		end

		faded[gui] = true
		count += 1
		fadeAndDestroy(gui)
	end

	fade(primaryGui)

	if playerGui then
		for _, child in ipairs(playerGui:GetChildren()) do
			if child.Name == LOADING_GUI_NAME then
				fade(child)
			end
		end
	end

	return count
end

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", READY_TIMEOUT)

if not game:IsLoaded() then
	game.Loaded:Wait()
end

do
	local folder = replicatedStorage:WaitForChild("PlayerState", READY_TIMEOUT)
	local moduleScript = folder and folder:WaitForChild("PlayerStateClient", READY_TIMEOUT)
	if moduleScript then
		local ok, result = pcall(require, moduleScript)
		if ok then
			PlayerState = result
		else
			warn("[Preloader] Falha ao requerer PlayerStateClient:", result)
		end
	end
end

waitForClientReady(playerGui)

-- Preload roda em segundo plano depois que a UI central já está pronta,
-- para não disputar o frame no pior momento do boot.
task.spawn(startPreload)
