--!strict
local DailyRewards = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local player        = Players.LocalPlayer
local PlayerGui     = player:WaitForChild("PlayerGui")
local MainUI        = PlayerGui:WaitForChild("UI")
local DailyFrame    = MainUI:WaitForChild("DailyRewards") :: Frame
local MainContainer = DailyFrame:WaitForChild("MAIN")
local DailyRemote   = ReplicatedStorage:WaitForChild("Events"):WaitForChild("DailyRewardRemote") :: RemoteFunction
local Effects       = require(script.Parent.Parent.Effects)
local RewardNotificationModule = require(ReplicatedStorage.Modules.RewardNotificationModule)

-- ══════════════════════════════════════════════════════
--   IMAGENS — só mexa aqui para trocar os ícones
-- ══════════════════════════════════════════════════════

local IMAGES = {
	Roll          = "rbxassetid://101438475717728",
	Crystals      = "rbxassetid://76561241485272",
	SkinShiro     = "rbxassetid://108138163455074",
	SkinLegendary = "rbxassetid://100500998222099",
	SkinRare      = "rbxassetid://100500998222099",
	SkinEpic      = "rbxassetid://100500998222099",
	SkinUncommon  = "rbxassetid://100500998222099",
}

-- Week 1 usa Shiro (silhueta); semanas seguintes usam os outros rarities
local MILESTONE_IMAGE: { [number]: string } = {
	[1] = IMAGES.SkinShiro,     -- D7  — Shiro (silhueta)
	[2] = IMAGES.SkinRare,      -- D14 — Rare
	[3] = IMAGES.SkinEpic,      -- D21 — Epic
	[4] = IMAGES.SkinUncommon,  -- D28 — Legendary
}

-- Semanas cujo D7 deve ser exibido como SILHUETA (teaser)
-- Adicione o número da semana aqui para ativar o efeito.
local SILHOUETTE_WEEKS: { [number]: true } = {
	[1] = true,  -- Week 1 → Shiro ainda não lançada
}

local SLOT_IMAGE: { [number]: string } = {
	[1] = IMAGES.Roll,
	[2] = IMAGES.Crystals,
	[3] = IMAGES.Roll,
	[4] = IMAGES.Crystals,
	[5] = IMAGES.Roll,
	[6] = IMAGES.Crystals,
}

-- ══════════════════════════════════════════════════════
--   QUANTIDADES — texto exibido no Quantity de cada slot
-- ══════════════════════════════════════════════════════

local SLOT_QUANTITY: { [number]: string } = {
	[1] = "1X",
	[2] = "25X",
	[3] = "3X",
	[4] = "50X",
	[5] = "5X",
	[6] = "100X",
	[7] = "",   -- Skin não exibe quantidade
}

-- ══════════════════════════════════════════════════════

local isClaiming = false

local function ShowLockedDailyRewardNotification()
	RewardNotificationModule.ShowLockedReward("THIS DAILY REWARD IS NOT YET AVAILABLE")
end

local function getSlotImage(slot: number, week: number): string
	if slot == 7 then
		return MILESTONE_IMAGE[week] or IMAGES.SkinLegendary
	end
	return SLOT_IMAGE[slot] or ""
end

-- Aplica ou remove o efeito de silhueta num ImageLabel.
-- Silhueta = imagem completamente preta + leve transparência extra.
local function applySilhouette(imageLabel: ImageLabel, enable: boolean)
	if enable then
		imageLabel.ImageColor3        = Color3.new(0, 0, 0)   -- tinta preta
		imageLabel.ImageTransparency  = 0                      -- sem transparência extra; a cor já faz o trabalho
	else
		imageLabel.ImageColor3        = Color3.new(1, 1, 1)   -- cor original
		-- transparência é controlada pelo fluxo normal do UpdateUI
	end
end

function DailyRewards.UpdateUI(): boolean
	if not MainContainer then return false end

	local status = DailyRemote:InvokeServer("GetStatus")
	if not status then return false end

	local currentDay  = status.CurrentDay
	local currentWeek = math.ceil(currentDay / 7)
	local weekStart   = (currentWeek - 1) * 7 + 1

	for slot = 1, 7 do
		local absoluteDay = weekStart + (slot - 1)

		local btn = MainContainer:FindFirstChild(tostring(slot)) :: ImageButton
		if not btn then continue end

		local collected  = btn:FindFirstChild("Collected")  :: GuiObject
		local locked     = btn:FindFirstChild("Locked")     :: GuiObject
		local imageLabel = btn:FindFirstChild("ImageLabel") :: ImageLabel
		local quantity   = btn:FindFirstChild("Quantity")   :: TextLabel

		-- ── Reset visual ──────────────────────────────────────────
		if collected  then collected.Visible  = false end
		if locked     then locked.Visible     = false end
		if imageLabel then
			imageLabel.Visible           = true
			imageLabel.ImageTransparency = 0
			applySilhouette(imageLabel, false)   -- garante reset da cor
		end
		if quantity then quantity.Visible = false end

		btn.AutoButtonColor = false
		btn.Active          = false

		-- ── Imagem do slot ────────────────────────────────────────
		if imageLabel then
			imageLabel.Image = getSlotImage(slot, currentWeek)
		end

		-- ── Texto de quantidade ───────────────────────────────────
		if quantity then
			quantity.Text = SLOT_QUANTITY[slot] or ""
		end

		-- ── Verifica se este slot deve ser exibido como silhueta ──
		-- Condição: slot 7, semana dentro de SILHOUETTE_WEEKS,
		-- e o personagem ainda não foi desbloqueado (dia futuro ou atual sem claim)
		local isMilestoneSlot  = (slot == 7)
		local isTeaser         = isMilestoneSlot and SILHOUETTE_WEEKS[currentWeek] ~= nil

		-- ── Estado visual ─────────────────────────────────────────
		if absoluteDay < currentDay then
			-- Dia já coletado (silhueta nunca aparece em dias coletados)
			if collected  then collected.Visible = true  end
			if imageLabel then imageLabel.Visible = false end

		elseif absoluteDay == currentDay then
			if status.CanClaim then
				-- Disponível para coletar
				btn.AutoButtonColor = true
				btn.Active          = true
				if quantity and quantity.Text ~= "" then
					quantity.Visible = true
				end
				-- Silhueta mesmo quando disponível para coletar (teaser)
				if isTeaser and imageLabel then
					applySilhouette(imageLabel, true)
				end
			else
				-- Em cooldown: cadeado + ícone fantasma
				btn.Active = true
				if quantity and quantity.Text ~= "" then
					quantity.Visible = true
				end
				if locked     then locked.Visible            = true  end
				if imageLabel then
					imageLabel.ImageTransparency = 0.2
					if isTeaser then applySilhouette(imageLabel, true) end
				end
			end
		else
			-- Dias futuros: cadeado + ícone bem apagado
			btn.Active = true
			if quantity and quantity.Text ~= "" then
				quantity.Visible = true
			end
			if locked     then locked.Visible            = true  end
			if imageLabel then
				imageLabel.ImageTransparency = 0.2
				if isTeaser then
					-- Silhueta já é preta; só mantém a transparência para
					-- indicar que o dia ainda está bloqueado
					applySilhouette(imageLabel, true)
				end
			end
		end
	end

	return true
end

function DailyRewards.ButtonAction(button: GuiButton)
	if isClaiming then return end

	local slot    = tonumber(button.Name)
	local status  = DailyRemote:InvokeServer("GetStatus")
	if not status or not slot then return end

	local currentWeek = math.ceil(status.CurrentDay / 7)
	local weekStart   = (currentWeek - 1) * 7 + 1
	local absoluteDay = weekStart + (slot - 1)

	if absoluteDay ~= status.CurrentDay or not status.CanClaim then
		ShowLockedDailyRewardNotification()
		return
	end

	isClaiming = true

	local ok, _ = DailyRemote:InvokeServer("Claim")
	if ok then
		DailyRewards.UpdateUI()
	else
		ShowLockedDailyRewardNotification()
	end

	task.wait(1)
	isClaiming = false
end

function DailyRewards.Init()
	DailyRemote.OnClientInvoke = function(action)
		if action == "UpdateUI" then
			DailyRewards.UpdateUI()
		end
	end

	task.spawn(function()
		local success  = false
		local attempts = 0
		repeat
			success = DailyRewards.UpdateUI()
			if not success then
				task.wait(2)
				attempts += 1
			end
		until success or attempts > 10
	end)

	--Effects.ToggleUI(DailyFrame)
end

return DailyRewards
