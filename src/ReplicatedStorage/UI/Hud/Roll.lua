--!strict
-- RollClient.lua
-- Roll + SlotButton integrados.
-- O slot que vai receber o personagem anima junto com o efeito de girar.
-- Remova o script SlotButton separado após usar este arquivo.

local Module = {}

local Players           = game:GetService("Players")
local SoundService      = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst   = game:GetService("ReplicatedFirst")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui   = localPlayer:WaitForChild("PlayerGui")

local Main: PlayerGui      = PlayerGui:WaitForChild("UI", 15) :: PlayerGui
local UIScript             = script.Parent.Parent
local Effects              = require(UIScript:WaitForChild("Effects"))
local CameraModule         = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CameraModule"))
local PlayerState          = require(ReplicatedStorage.PlayerState.PlayerStateClient)
local CharacterRegistry    = require(ReplicatedStorage:WaitForChild("CharacterInfo"):WaitForChild("CharacterInfoModule"))
local VFX                  = require(ReplicatedStorage.Modules.Utilitary.VFX)

-- ── Remotes ──────────────────────────────────────────────────────────────────
local RollRemote: RemoteFunction =
	ReplicatedStorage:WaitForChild("Events"):WaitForChild("RollSystemEvents"):WaitForChild("RollRequest") :: RemoteFunction

local SlotEvents: RemoteEvent =
	ReplicatedStorage:WaitForChild("Events"):WaitForChild("SlotEvents") :: RemoteEvent

-- ── Câmera / Blackout ─────────────────────────────────────────────────────────
local CameraFolder = ReplicatedFirst:WaitForChild("Cameras")
local RollCamera   = CameraFolder:WaitForChild("CameraRoll")
local Blackout: Frame = PlayerGui:WaitForChild("CoverScreen"):WaitForChild("Black") :: Frame

-- ── Frames ────────────────────────────────────────────────────────────────────
local RollFrame = Main:WaitForChild("Roll")
local HudFrame  = Main:WaitForChild("HUD")

local OtherUIFrames = {
	Achievements       = Main:WaitForChild("Achievements"),
	CharacterIndex     = Main:WaitForChild("CharacterIndex"),
	CharacterSelection = Main:WaitForChild("CharacterSelection"),
	Codes              = Main:WaitForChild("Codes"),
	DailyRewards       = Main:WaitForChild("DailyRewards"),
	FightingFrame      = Main:WaitForChild("FightingFrame"),
	HUD                = Main:WaitForChild("HUD"),
	InviteRewards      = Main:WaitForChild("InviteRewards"),
	Party              = Main:WaitForChild("Party"),
	Quests             = Main:WaitForChild("Quests"),
	Start              = Main:WaitForChild("Start"),
	Shop               = Main:WaitForChild("Shop"),
	Tags               = Main:WaitForChild("Tags"),
	SelectModeLocal    = Main:WaitForChild("SelectModeLocal"),
	SelectModeGlobal   = Main:WaitForChild("SelectModeGlobal"),
	LocalQueue1v1      = Main:WaitForChild("LocalQueue1v1"),
	LocalQueue2v2      = Main:WaitForChild("LocalQueue2v2"),
	TeamToggleFrame    = Main:WaitForChild("TeamToggleFrame"),
	ChooseTeamateLocal = Main:WaitForChild("ChooseTeamateLocal"),
	ChooseTeamateGlobal= Main:WaitForChild("ChooseTeamateGlobal"),
	MapSelection       = Main:WaitForChild("MapSelection"),
	ReturnToLobby      = Main:WaitForChild("ReturnToLobby"),
}

-- ── Roll UI ───────────────────────────────────────────────────────────────────
local SpinButton: TextButton    = RollFrame:WaitForChild("SpinButton") :: TextButton
local RollsLabel: TextLabel     = RollFrame:WaitForChild("RollsLabel") :: TextLabel
local StyleNameLabel: TextLabel = RollFrame:WaitForChild("ImageLabel"):WaitForChild("StyleNameLabel") :: TextLabel
local StyleDescLabel: TextLabel = RollFrame:WaitForChild("StyleDescLabel") :: TextLabel
local PityLabel: TextLabel      = RollFrame:WaitForChild("PityLabel") :: TextLabel

-- ── Slot UI ───────────────────────────────────────────────────────────────────
local RollSlots           = RollFrame:WaitForChild("RollSlots")
local ScrollingFrameSlots = RollSlots:WaitForChild("ScrollingFrameSlots")
local SlotButtonTemplate  = ScrollingFrameSlots:WaitForChild("SlotTemplate") :: GuiButton

-- ── Animações ─────────────────────────────────────────────────────────────────
local IdleAnim: Animation    = script:WaitForChild("Idle") :: Animation
local RevealAnim: Animation? = script:FindFirstChild("Reveal") :: Animation?

-- ── Constantes ────────────────────────────────────────────────────────────────
local RARITY_COLORS = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(100, 220, 100),
	Rare      = Color3.fromRGB(80,  140, 255),
	Epic      = Color3.fromRGB(180, 80,  255),
	Legendary = Color3.fromRGB(255, 200, 50),
}

local PITY_THRESHOLDS = {
	Rare      = 50,
	Epic      = 100,
	Legendary = 200,
}

local SPIN_DURATION  = 3.0
local FAST_INTERVAL  = 0.04
local SLOW_INTERVAL  = 0.18
local TARGET_PART_NAME = "CharacterPreviewPart"
local EMPTY_TEXT     = "[ Vazio ]"

-- ── Estado do Roll ────────────────────────────────────────────────────────────
local isSpinning  = false
local cooldownEnd = 0

local currentIdleTrack: AnimationTrack? = nil
local currentClone: Model? = nil

local savedRollCFrame: CFrame? = nil
local savedRollFOV: number?    = nil
local savedRollType: Enum.CameraType? = nil

local namePool: { { name: string, rarity: string } } = {}
for _, char in ipairs(CharacterRegistry) do
	table.insert(namePool, { name = char.name, rarity = char.rarity })
end

-- ── Estado dos Slots ──────────────────────────────────────────────────────────
type SlotData = {
	id          : string,
	name        : string,
	rarity      : string,
	description : string?,
	AnimId      : number?,
}

local slotButtons: { [number]: GuiButton } = {}
local equippedSlotIndex = 0

-- Fills recebidos do servidor enquanto o spin ainda está animando
local pendingSlotFills: { { slotIndex: number, characterData: SlotData } } = {}

-- ═════════════════════════════════════════════════════════════════════════════
-- SLOT – Visuais
-- ═════════════════════════════════════════════════════════════════════════════

local function setEquipped(button: GuiButton)
	button.EquippedOrDisequipped.Text       = "Equipped"
	button.EquippedOrDisequipped.TextColor3 = Color3.fromRGB(34, 255, 0)
end

local function setDesequipped(button: GuiButton)
	button.EquippedOrDisequipped.Text       = "Desequipped"
	button.EquippedOrDisequipped.TextColor3 = Color3.fromRGB(255, 0, 0)
end

local function setEmpty(button: GuiButton)
	button.StyleName.Text                   = EMPTY_TEXT
	button.EquippedOrDisequipped.Text       = ""
	button.EquippedOrDisequipped.TextColor3 = Color3.fromRGB(150, 150, 150)
end

local function updateEquippedVisual(newIndex: number)
	if equippedSlotIndex ~= 0 and slotButtons[equippedSlotIndex] then
		setDesequipped(slotButtons[equippedSlotIndex])
	end
	if slotButtons[newIndex] then
		setEquipped(slotButtons[newIndex])
	end
	equippedSlotIndex = newIndex
end

-- ═════════════════════════════════════════════════════════════════════════════
-- SLOT – Botões
-- ═════════════════════════════════════════════════════════════════════════════

local function createSlotButton(slotIndex: number, characterData: SlotData?)
	local button = SlotButtonTemplate:Clone() :: GuiButton
	button.Parent  = ScrollingFrameSlots
	button.Visible = true
	button:SetAttribute("SlotIndex", slotIndex)

	if characterData then
		button.StyleName.Text = characterData.name
		setDesequipped(button)
		if button:FindFirstChild("RarityLabel") then
			(button.RarityLabel :: TextLabel).Text = characterData.rarity
		end
	else
		setEmpty(button)
	end

	-- Conexão de clique interna — não depende mais do sistema interativo externo
	button.MouseButton1Click:Connect(function()
		local idx = button:GetAttribute("SlotIndex")
		if type(idx) ~= "number" then return end

		if button.StyleName.Text == EMPTY_TEXT then
			warn(`[RollClient][Slot] Slot {idx} está vazio, nada a equipar.`)
			return
		end

		warn(`[RollClient][Slot] Equipando slot {idx}...`)
		SlotEvents:FireServer("EquipSlot", idx)
	end)

	slotButtons[slotIndex] = button
end

local function fillSlotButton(slotIndex: number, characterData: SlotData)
	local button = slotButtons[slotIndex]
	if not button then
		warn(`[RollClient][Slot] Slot {slotIndex} não existe no cliente, criando...`)
		createSlotButton(slotIndex, characterData)
		return
	end

	button.StyleName.Text = characterData.name
	if button:FindFirstChild("RarityLabel") then
		(button.RarityLabel :: TextLabel).Text = characterData.rarity
	end

	-- ✅ Preserva o visual de equipado se este slot já está equipado
	if slotIndex == equippedSlotIndex then
		setEquipped(button)
	else
		setDesequipped(button)
	end
end

local function rebuildAll(slotCount: number, slots: { [number]: SlotData? }, equippedIndex: number)
	for _, btn in pairs(slotButtons) do btn:Destroy() end
	slotButtons       = {}
	equippedSlotIndex = 0

	for i = 1, slotCount do
		createSlotButton(i, slots[i])
	end

	if equippedIndex ~= 0 then
		updateEquippedVisual(equippedIndex)
	end
end

local function expandSlots(newSlotCount: number)
	local currentCount = 0
	for _ in pairs(slotButtons) do currentCount += 1 end
	for i = currentCount + 1, newSlotCount do
		createSlotButton(i, nil)
	end
end

-- ═════════════════════════════════════════════════════════════════════════════
-- CLONE
-- ═════════════════════════════════════════════════════════════════════════════

local function getPreviewPart(): BasePart?
	return (workspace:FindFirstChild(TARGET_PART_NAME)
		or ReplicatedFirst:FindFirstChild(TARGET_PART_NAME)) :: BasePart?
end

local function destroyCurrentClone()
	if currentIdleTrack then
		pcall(function() currentIdleTrack:Stop() end)
		currentIdleTrack = nil
	end
	if currentClone then
		currentClone:Destroy()
		currentClone = nil
	end
	local old = workspace:FindFirstChild("MyCharacterClone")
	if old then old:Destroy() end
end

local function spawnPreviewClone(charId: string)
	destroyCurrentClone()

	local combatStorage = ReplicatedStorage:FindFirstChild("CombatStorage")
	if not combatStorage then warn("[RollClient] CombatStorage não encontrado") return end

	local combatChar = combatStorage:FindFirstChild(charId)
	if not combatChar then warn("[RollClient] Personagem não encontrado:", charId) return end

	local starterModel = combatChar:FindFirstChild("StarterCharacter")
	if not starterModel then warn("[RollClient] StarterCharacter não encontrado em:", charId) return end

	local targetPart = getPreviewPart()
	if not targetPart then warn("[RollClient] CharacterPreviewPart não encontrada") return end

	local clone = starterModel:Clone()
	clone.Name = "MyCharacterClone"

	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	local rootPart = clone:FindFirstChild("HumanoidRootPart") :: BasePart?

	local ff = clone:FindFirstChild("ForceField")
	if ff then ff:Destroy() end

	if humanoid and rootPart then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

		local heightOffset = humanoid.HipHeight + (targetPart.Size.Y / 2) + (rootPart.Size.Y / 2)
		clone:PivotTo(targetPart.CFrame * CFrame.new(0, heightOffset, 0))
		rootPart.Anchored = true

		for _, part in ipairs(clone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CastShadow = false
			end
		end

		clone.Parent = workspace
		currentClone = clone

		local animator = humanoid:FindFirstChildOfClass("Animator")
			or Instance.new("Animator", humanoid)

		if RevealAnim then
			local revealTrack = animator:LoadAnimation(RevealAnim)
			revealTrack.Priority = Enum.AnimationPriority.Action
			revealTrack:Play()
			revealTrack.Stopped:Once(function()
				if currentClone == clone then
					local idleTrack = animator:LoadAnimation(IdleAnim)
					idleTrack.Priority = Enum.AnimationPriority.Idle
					idleTrack.Looped   = true
					idleTrack:Play()
					currentIdleTrack = idleTrack
				end
			end)
		else
			local idleTrack = animator:LoadAnimation(IdleAnim)
			idleTrack.Priority = Enum.AnimationPriority.Idle
			idleTrack.Looped   = true
			idleTrack:Play()
			currentIdleTrack = idleTrack
		end
	else
		clone:Destroy()
		warn("[RollClient] Clone sem Humanoid ou HumanoidRootPart:", charId)
	end
end

-- ═════════════════════════════════════════════════════════════════════════════
-- ROLL – UI Helpers
-- ═════════════════════════════════════════════════════════════════════════════

local function setSpinButtonEnabled(enabled: boolean)
	SpinButton.Active          = enabled
	SpinButton.AutoButtonColor = enabled
end

local function updateRollsLabel()
	local rolls = PlayerState.Get("Rolls") or 0
	RollsLabel.Text = `Rolls: {rolls}`
end

local function clearResult()
	StyleDescLabel.Text       = ""
	StyleNameLabel.Text       = ""
	StyleNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
end

local function updateActiveCharacterLabel()
	local activeId = PlayerState.Get("ActiveCharacter")
	if activeId and activeId ~= "" then
		for _, char in ipairs(CharacterRegistry) do
			if char.id == activeId then
				StyleNameLabel.Text       = char.name
				StyleNameLabel.TextColor3 = RARITY_COLORS[char.rarity] or RARITY_COLORS.Common
				StyleDescLabel.Text       = char.description
				return
			end
		end
	end
	clearResult()
end

local function updatePityLabel()
	local pity = PlayerState.Get("PityCounters") or { Rare = 0, Epic = 0, Legendary = 0 }
	PityLabel.Text = `Rare: {pity["Rare"] or 0}/{PITY_THRESHOLDS.Rare} | Epic: {pity["Epic"] or 0}/{PITY_THRESHOLDS.Epic} | Leg: {pity["Legendary"] or 0}/{PITY_THRESHOLDS.Legendary}`
end

local function revealResult(character: { name: string, rarity: string, description: string, id: string })
	local rarityColor = RARITY_COLORS[character.rarity] or RARITY_COLORS.Common

	StyleNameLabel.Text       = character.name
	StyleNameLabel.TextColor3 = rarityColor
	StyleDescLabel.Text       = character.description

	local originalSize = StyleNameLabel.TextSize
	StyleNameLabel.TextSize = originalSize * 1.5
	TweenService:Create(
		StyleNameLabel,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ TextSize = originalSize }
	):Play()

	spawnPreviewClone(character.id)
end

-- ═════════════════════════════════════════════════════════════════════════════
-- ROLL – Spin
-- ═════════════════════════════════════════════════════════════════════════════

local function doRoll()
	SoundService:WaitForChild("Sounds").RollButton:Play()

	if isSpinning then return end
	if tick() < cooldownEnd then return end

	local currentRolls = PlayerState.Get("Rolls") or 0
	if currentRolls <= 0 then return end

	isSpinning = true
	setSpinButtonEnabled(false)
	clearResult()
	if currentClone then
		VFX.Highlight(currentClone, Color3.fromRGB(0, 153, 255), 0.6)
	end
	SoundService:WaitForChild("Sounds").SpinSound:Play()

	local serverResult: {
		success: boolean, character: any?,
		errorMsg: string?, remainingCooldown: number?, pityCounts: any?
	}? = nil

	task.spawn(function()
		local ok, result = pcall(function()
			return RollRemote:InvokeServer()
		end)
		if ok then
			serverResult = result :: any
		else
			warn(`[RollClient] Erro ao invocar RollRequest: {result}`)
			serverResult = { success = false, errorMsg = "Connection error." }
		end
	end)

	local startTime = tick()
	local spinEnd   = startTime + SPIN_DURATION
	local lastSwap  = 0
	local lastIndex = 0

	-- Loop de spin: anima apenas o StyleNameLabel central
	repeat
		local elapsed  = tick() - startTime
		local t        = math.clamp(elapsed / SPIN_DURATION, 0, 1)
		local interval = FAST_INTERVAL + (SLOW_INTERVAL - FAST_INTERVAL) * (t ^ 2)

		if elapsed - lastSwap >= interval then
			lastSwap = elapsed
			if #namePool > 0 then
				local idx
				repeat
					idx = math.random(1, #namePool)
				until idx ~= lastIndex or #namePool == 1
				lastIndex = idx

				local entry = namePool[idx]
				StyleNameLabel.Text       = entry.name
				StyleNameLabel.TextColor3 = RARITY_COLORS[entry.rarity] or RARITY_COLORS.Common
			end
		end

		RunService.Heartbeat:Wait()
	until tick() >= spinEnd and serverResult ~= nil

	isSpinning = false
	SoundService:WaitForChild("Sounds").SpinSound:Stop()
	SoundService:WaitForChild("Sounds").SelectedRollCharacter:Play()

	local response = serverResult :: {
		success: boolean, character: any?,
		errorMsg: string?, remainingCooldown: number?, pityCounts: any?
	}

	if response.success and response.character then
		updateRollsLabel()
		revealResult(response.character)
		if currentClone then
			VFX.Highlight(currentClone, Color3.fromRGB(246, 255, 147), 0.6)
		end
		updatePityLabel()

		-- Aplica os SlotFilled que chegaram durante o spin
		for _, fill in ipairs(pendingSlotFills) do
			fillSlotButton(fill.slotIndex, fill.characterData)
		end
		pendingSlotFills = {}

		cooldownEnd = tick() + 1
		task.delay(3, function()
			if not isSpinning then setSpinButtonEnabled(true) end
		end)
	else
		updateActiveCharacterLabel()
		if response.remainingCooldown and response.remainingCooldown > 0 then
			cooldownEnd = tick() + response.remainingCooldown
			task.delay(response.remainingCooldown, function()
				if not isSpinning then setSpinButtonEnabled(true) end
			end)
		else
			setSpinButtonEnabled(true)
		end
	end
end

-- ═════════════════════════════════════════════════════════════════════════════
-- Eventos do servidor (Slots)
-- ═════════════════════════════════════════════════════════════════════════════

SlotEvents.OnClientEvent:Connect(function(action: string, ...)
	local args = { ... }

	if action == "SlotsData" then
		-- Estado completo ao entrar no jogo
		local slotCount: number              = args[1]
		local slots: { [number]: SlotData? } = args[2]
		local equippedIndex: number          = args[3] or 0
		rebuildAll(slotCount, slots, equippedIndex)

	elseif action == "SlotFilled" then
		-- Se o spin ainda está animando, segura o fill para aplicar só depois
		local slotIndex: number       = args[1]
		local characterData: SlotData = args[2]
		if isSpinning then
			table.insert(pendingSlotFills, { slotIndex = slotIndex, characterData = characterData })
		else
			fillSlotButton(slotIndex, characterData)
		end

	elseif action == "SlotsExpanded" then
		-- Outro sistema deu mais slots ao jogador
		local newSlotCount: number = args[1]
		expandSlots(newSlotCount)

	elseif action == "EquipResult" then
		local ok: boolean       = args[1]
		local slotIndex: number = args[2]
		local data              = args[3]

		if ok then
			updateEquippedVisual(slotIndex)
		else
			warn(`[RollClient][Slot] Falha ao equipar slot {slotIndex}: {tostring(data)}`)
		end
	end
end)

-- ═════════════════════════════════════════════════════════════════════════════
-- PUBLIC
-- ═════════════════════════════════════════════════════════════════════════════

-- Chamado pelo sistema interativo quando o botão de abrir o Roll é pressionado
function Module.ButtonAction(_button: GuiButton)
	local Camera = workspace.CurrentCamera
	savedRollCFrame = Camera.CFrame
	savedRollFOV    = Camera.FieldOfView
	savedRollType   = Camera.CameraType

	Blackout.Visible = true
	HudFrame.Visible = false

	for _, ui in OtherUIFrames do
		if ui.Visible then
			Effects.ToggleUI(ui)
		end
	end

	CameraModule.SetCameraInstant(RollCamera)
	Effects.ToggleUI(RollFrame)

	local tween = TweenService:Create(
		Blackout,
		TweenInfo.new(2, Enum.EasingStyle.Circular, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Once(function()
		Blackout.Visible = false
		Blackout.BackgroundTransparency = 0
	end)
end

function Module.Init()
	print("[RollClient] Initialized (Roll + Slots)")

	-- ── Inicializa template do slot ───────────────────────────────────────────
	SlotButtonTemplate.Visible = false

	-- Pede os dados dos slots ao servidor
	SlotEvents:FireServer("GetSlots")

	-- ── Inicializa Roll ───────────────────────────────────────────────────────
	task.spawn(function()
		local attempts = 0
		repeat
			task.wait(0.2)
			attempts += 1
		until PlayerState.Get("Rolls") ~= nil or attempts >= 25

		updateRollsLabel()
		updateActiveCharacterLabel()
		updatePityLabel()
		setSpinButtonEnabled(true)

		local activeId = PlayerState.Get("ActiveCharacter")
		if activeId and activeId ~= "" then
			spawnPreviewClone(activeId)
		end
	end)

	SpinButton.MouseButton1Click:Connect(doRoll)

	-- Mostra/esconde clone conforme o RollFrame abre ou fecha
	RollFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if RollFrame.Visible then
			updateRollsLabel()
			updateActiveCharacterLabel()
			updatePityLabel()
			local activeId = PlayerState.Get("ActiveCharacter")
			if activeId and activeId ~= "" then
				spawnPreviewClone(activeId)
			end
		else
			destroyCurrentClone()
			CameraModule.RestoreCameraInstant()

			local character = localPlayer.Character
			if character then
				local Camera   = workspace.CurrentCamera
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					Camera.CameraSubject = humanoid
				end
			end

			-- Limpa os salvos locais (não são mais necessários)
			savedRollCFrame = nil
			savedRollFOV    = nil
			savedRollType   = nil

			if not HudFrame.Visible then Effects.ToggleUI(HudFrame) end
			Blackout.Visible = false
			Blackout.BackgroundTransparency = 0
		end
	end)

	-- Reactive updates via PlayerState
	PlayerState.OnChanged("Rolls", function(newValue)
		RollsLabel.Text = `Rolls: {newValue}`
	end)

	PlayerState.OnChanged("ActiveCharacter", function(newId)
		if RollFrame.Visible and not isSpinning then
			updateActiveCharacterLabel()
			if newId and newId ~= "" then
				spawnPreviewClone(newId)
			end
		end
	end)

	PlayerState.OnChanged("PityCounters", function()
		if RollFrame.Visible then
			updatePityLabel()
		end
	end)
end

return Module