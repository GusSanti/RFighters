local Inventory = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
if not game:IsLoaded() then game.Loaded:Wait() end

---------------- MODULES ----------------
local SkinsData   = require(script.SkinsData).SkinsData
local EmotesData  = require(script.Parent.Emotes.EmotesData)
local Effects     = require(script.Parent.Parent.Effects)
local PlayerState = require(ReplicatedStorage.PlayerState.PlayerStateClient)

---------------- EVENTS ─ Skins ----------------
local SkinsFolder      = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Skins")
local EquipSkinEvent   = SkinsFolder:WaitForChild("EquipSkin")
local UnequipSkinEvent = SkinsFolder:WaitForChild("UnequipSkin")

---------------- EVENTS ─ Emotes ----------------
local EmoteRemotes -- resolvido no Init

---------------- UI ----------------
local playerGui      = localPlayer:WaitForChild("PlayerGui")
local MainUI         = playerGui:WaitForChild("UI")
local HudUI = MainUI:WaitForChild('HUD')
local InventoryUI    = MainUI:WaitForChild("Inventory")
local SkinButton     = InventoryUI:WaitForChild("SkinButton")
local EmoteButton    = InventoryUI:WaitForChild("EmoteButton")
local MainFrame      = InventoryUI:WaitForChild("Main")
local ScrollingFrame = MainFrame:WaitForChild("ScrollingFrame")
local BlueTemplate   = ScrollingFrame:WaitForChild("BlueTemplate")
local GreenTemplate  = ScrollingFrame:WaitForChild("GreenTemplate")
local YellowTemplate = ScrollingFrame:WaitForChild("YellowTemplate")
local SearchBarFrame = MainFrame:WaitForChild("SearchBar")
local SearchBarTextBox = SearchBarFrame:WaitForChild("TextBox")

local TEMPLATES = { BlueTemplate, GreenTemplate, YellowTemplate }

---------------- VIEWPORT CONSTANTS ----------------
local WORLD_MODEL_NAME                    = "WorldModel"
local VIEWPORT_CAMERA_NAME                = "InvViewportCamera"
local VIEWPORT_DUMMY_NAME                 = "InvDummy"
local GENERATED_VISUAL_ATTRIBUTE          = "InvGeneratedVisual"
local VIEWPORT_CAMERA_FIELD_OF_VIEW       = 28
local VIEWPORT_CAMERA_MIN_DISTANCE        = 3
local VIEWPORT_CAMERA_DISTANCE_MULTIPLIER = 1.75
local VIEWPORT_CAMERA_DIRECTION           = Vector3.new(1, 0.35, -2).Unit

---------------- EMOTE CONSTANTS ----------------
local MAX_EMOTE_SLOTS = 8

---------------- STATE ----------------
local CurrentFilter   = "Skins"   -- "Skins" | "Emotes"
local CurrentSearch   = ""

local ViewportTroves  = {}   -- [viewport] = stopTrack fn
local CardConnections = {}   -- connections dos cards gerados
local ActiveCards     = {}   -- lista de frames gerados (para search filter)

-- Emotes state (espelho do servidor)
local CachedEquipped  = {}
local OwnedEmotesList = {}

---------------- HELPERS ─ Viewport ----------------

local function GetDummyTemplate()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local dummy  = assets and assets:FindFirstChild("Dummy")
	return dummy and dummy:IsA("Model") and dummy or nil
end

local function FindItemViewport(root)
	if not root then return nil end
	if root:IsA("ViewportFrame") then return root end
	local named = root:FindFirstChild("ITEM", true)
	if named and named:IsA("ViewportFrame") then return named end
	return root:FindFirstChildWhichIsA("ViewportFrame", true)
end

local function ClearViewport(viewport)
	if not viewport then return nil end

	local trove = ViewportTroves[viewport]
	if trove then
		trove()
		ViewportTroves[viewport] = nil
	end

	for _, child in ipairs(viewport:GetChildren()) do
		if child:GetAttribute(GENERATED_VISUAL_ATTRIBUTE) == true then
			child:Destroy()
		end
	end

	local worldModel = viewport:FindFirstChild(WORLD_MODEL_NAME)
	if not worldModel or not worldModel:IsA("WorldModel") then
		worldModel = Instance.new("WorldModel")
		worldModel.Name   = WORLD_MODEL_NAME
		worldModel.Parent = viewport
	end
	for _, child in ipairs(worldModel:GetChildren()) do
		child:Destroy()
	end

	return worldModel
end

local function ConfigureViewportCamera(viewport, model)
	local camera = viewport:FindFirstChild(VIEWPORT_CAMERA_NAME)
	if not camera or not camera:IsA("Camera") then
		camera        = Instance.new("Camera")
		camera.Name   = VIEWPORT_CAMERA_NAME
		camera.Parent = viewport
	end
	camera.FieldOfView     = VIEWPORT_CAMERA_FIELD_OF_VIEW
	viewport.CurrentCamera = camera

	local modelCFrame, modelSize = model:GetBoundingBox()
	local maxDim  = math.max(modelSize.X, modelSize.Y, modelSize.Z, VIEWPORT_CAMERA_MIN_DISTANCE)
	local fitDist = (maxDim / 2) / math.tan(math.rad(camera.FieldOfView) / 2)
	local camDist = math.max(fitDist * VIEWPORT_CAMERA_DISTANCE_MULTIPLIER, VIEWPORT_CAMERA_MIN_DISTANCE)
	local camPos  = modelCFrame.Position + VIEWPORT_CAMERA_DIRECTION * camDist
	camera.CFrame = CFrame.new(camPos, modelCFrame.Position)
end

local function PrepareRigForViewport(model)
	model:PivotTo(CFrame.new())
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored   = desc.Name == "HumanoidRootPart"
			desc.CanCollide = false
			desc.CanTouch   = false
			desc.CanQuery   = false
			desc.Massless   = true
		end
	end
end

local function LoadAnimationTrack(humanoid, animator, animation)
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	if ok and track then return track end
	local ok2, track2 = pcall(function() return humanoid:LoadAnimation(animation) end)
	if ok2 and track2 then return track2 end
	return nil
end

---------------- HELPERS ─ Skins Viewport ----------------

local CombatStorage = ReplicatedStorage:WaitForChild("CombatStorage")

local function RenderSkinViewport(viewport, character, modelName)
	local worldModel = ClearViewport(viewport)

	local characterFolder = CombatStorage:FindFirstChild(character)
	if not characterFolder then
		warn("[INVENTORY] CombatStorage: personagem não encontrado:", character)
		viewport.Visible = false
		return
	end

	local skinModel = characterFolder:FindFirstChild(modelName)
	if not skinModel or not skinModel:IsA("Model") then
		warn("[INVENTORY] CombatStorage: modelo não encontrado:", modelName, "em", character)
		viewport.Visible = false
		return
	end

	local clone = skinModel:Clone()
	PrepareRigForViewport(clone)
	clone.Parent = worldModel

	ConfigureViewportCamera(viewport, clone)
	viewport.Visible = true
end

---------------- HELPERS ─ Emotes Viewport ----------------

local function RenderEmoteImage(viewport, imageId)
	local image = Instance.new("ImageLabel")
	image.Name                 = "InvEmoteImage"
	image.BackgroundTransparency = 1
	image.Size                 = UDim2.fromScale(1, 1)
	image.Image                = imageId
	image.ScaleType            = Enum.ScaleType.Fit
	image:SetAttribute(GENERATED_VISUAL_ATTRIBUTE, true)
	image.Parent               = viewport
	viewport.Visible           = true
end

local function RenderEmoteViewport(viewport, emoteName)
	if not viewport then return end

	local emoteData = EmotesData.GetEmote(emoteName)
	if type(emoteData) ~= "table" then
		ClearViewport(viewport)
		return
	end

	local worldModel  = ClearViewport(viewport)
	local animationId = emoteData.AnimationId

	if type(animationId) ~= "string" or animationId == "" then
		if type(emoteData.ImageId) == "string" and emoteData.ImageId ~= "" then
			RenderEmoteImage(viewport, emoteData.ImageId)
		end
		return
	end

	local dummyTemplate = GetDummyTemplate()
	if not worldModel or not dummyTemplate then return end

	local dummy = dummyTemplate:Clone()
	dummy.Name  = VIEWPORT_DUMMY_NAME
	PrepareRigForViewport(dummy)
	dummy.Parent = worldModel
	ConfigureViewportCamera(viewport, dummy)

	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	if not humanoid then ClearViewport(viewport); return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator        = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation           = Instance.new("Animation")
	animation.AnimationId     = animationId
	animation.Name            = "InvEmotePreview"
	animation.Parent          = dummy

	local track = LoadAnimationTrack(humanoid, animator, animation)
	if not track then ClearViewport(viewport); return end

	track.Looped   = true
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0, 1, 1)

	ViewportTroves[viewport] = function()
		pcall(function() track:Stop(); track:Destroy() end)
	end

	viewport.Visible = true
end

---------------- HELPERS ─ Template ----------------

local function PickTemplate()
	return TEMPLATES[math.random(1, #TEMPLATES)]
end

---------------- HELPERS ─ Search Filter ----------------

local function ApplySearchFilter()
	local query = CurrentSearch:lower()
	for _, card in ipairs(ActiveCards) do
		if not card or not card.Parent then continue end
		local nameLabel = card:FindFirstChild("Name")
		local cardText  = nameLabel and nameLabel.Text:lower() or card.Name:lower()
		card.Visible    = query == "" or cardText:find(query, 1, true) ~= nil
	end
end

---------------- HELPERS ─ Cards cleanup ----------------

local function ClearCards()
	-- Desconecta conexões antigas
	for _, conn in ipairs(CardConnections) do
		conn:Disconnect()
	end
	table.clear(CardConnections)

	-- Limpa viewports antes de destruir
	for _, card in ipairs(ActiveCards) do
		if card and card.Parent then
			local vp = FindItemViewport(card)
			if vp then ClearViewport(vp) end
			card:Destroy()
		end
	end
	table.clear(ActiveCards)
end

---------------- SKINS ─ State helpers ----------------

local function GetPlayerSkinState(character, skinName)
	local unlockedSkins = PlayerState.Get("UnlockedSkins") or {}
	local charSkins     = unlockedSkins[character]
	if not charSkins then return nil end
	return charSkins[skinName]
end

local function IsSkinEquipped(character, skinName)
	local state = GetPlayerSkinState(character, skinName)
	return state ~= nil and state.IsEquiped == true
end

local function IsSkinUnlocked(character, skinName)
	local state = GetPlayerSkinState(character, skinName)
	return state ~= nil and state.IsUnlocked == true
end

---------------- SKINS ─ Build ----------------

local function BuildSkinCards()
	ClearCards()

	-- Coleta apenas as skins desbloqueadas de todos os personagens
	local flatList = {}
	for character, skins in pairs(SkinsData) do
		for skinName, skinData in pairs(skins) do
			if IsSkinUnlocked(character, skinName) then
				table.insert(flatList, {
					character = character,
					skinName  = skinName,
					skinData  = skinData,
				})
			end
		end
	end

	for _, entry in ipairs(flatList) do
		local character = entry.character
		local skinName  = entry.skinName
		local skinData  = entry.skinData

		local template = PickTemplate()
		local card     = template:Clone()
		card.Name      = skinName
		card.Visible   = true
		card.Parent    = ScrollingFrame

		-- Label: "Personagem - Display Name"
		local nameLabel = card:FindFirstChild("Name")
		if nameLabel then
			local displayName = skinData.DisplayName or skinName
			nameLabel.Text    = character .. " - " .. displayName
		end

		-- Viewport
		local viewport = FindItemViewport(card)
		if viewport then
			RenderSkinViewport(viewport, character, skinData.ModelName or skinName)
		end

		-- Botão (só unlocked chegam aqui)
		local equipBtn = card:FindFirstChild("Equip")
		local btnLabel = equipBtn and equipBtn:FindFirstChildOfClass("TextLabel")

		local isEquipped = IsSkinEquipped(character, skinName)

		if equipBtn and btnLabel then
			btnLabel.Text            = isEquipped and "Equipped" or "Equip"
			equipBtn.Active          = true
			equipBtn.AutoButtonColor = true

			local capturedChar = character
			local capturedSkin = skinName
			local localEquipped = isEquipped
			table.insert(CardConnections, equipBtn.MouseButton1Click:Connect(function()
				if localEquipped then
					UnequipSkinEvent:FireServer(capturedChar)
					btnLabel.Text = "Equip"
					localEquipped = false
				else
					EquipSkinEvent:FireServer(capturedChar, capturedSkin)
					btnLabel.Text = "Equipped"
					localEquipped = true
				end
			end))
		end

		table.insert(ActiveCards, card)

		-- Cada card clona conteúdo pesado no viewport (rig/emote). Cede o frame
		-- a cada item para nunca estourar o watchdog ("exhausted execution time").
		task.wait()
	end

	ApplySearchFilter()
end

---------------- EMOTES ─ State helpers ----------------

local function NormalizeEmoteSlots(equippedEmotes)
	local normalized = {}
	if type(equippedEmotes) ~= "table" then
		for i = 1, MAX_EMOTE_SLOTS do normalized[i] = "" end
		return normalized
	end
	for i = 1, MAX_EMOTE_SLOTS do
		local name    = equippedEmotes[i]
		normalized[i] = type(name) == "string" and name or ""
	end
	return normalized
end

local function GetEquippedEmotes()
	return NormalizeEmoteSlots(PlayerState.Get("EquippedEmotes"))
end

local function FindEquippedSlot(emoteName)
	for i = 1, MAX_EMOTE_SLOTS do
		if CachedEquipped[i] == emoteName then return i end
	end
	return nil
end

local function FindFirstFreeSlot()
	for i = 1, MAX_EMOTE_SLOTS do
		if not CachedEquipped[i] or CachedEquipped[i] == "" then return i end
	end
	return nil
end

---------------- EMOTES ─ Equip requests ----------------

local function RequestEquipEmote(slotIndex, emoteName)
	local equipRemote = EmoteRemotes and EmoteRemotes:FindFirstChild("EquipEmoteSlot")
	if not equipRemote then return end
	equipRemote:FireServer(slotIndex, emoteName)
end

local function RequestUnequipAndShift(slotIndex)
	local equipRemote = EmoteRemotes and EmoteRemotes:FindFirstChild("EquipEmoteSlot")
	if not equipRemote then return end

	local equipped = GetEquippedEmotes()

	for i = slotIndex, MAX_EMOTE_SLOTS - 1 do
		equipped[i] = equipped[i + 1]
	end
	equipped[MAX_EMOTE_SLOTS] = ""

	for i = slotIndex, MAX_EMOTE_SLOTS do
		equipRemote:FireServer(i, equipped[i])
	end
end

---------------- EMOTES ─ Build ----------------

-- Mapa de cards por emoteName para refresh rápido dos botões
local EmoteCardRefs = {}   -- [emoteName] = card

local function RefreshEmoteButtonStates()
	for emoteName, card in pairs(EmoteCardRefs) do
		if not card or not card.Parent then continue end
		local equipBtn = card:FindFirstChild("Equip")
		if not equipBtn then continue end
		local label = equipBtn:FindFirstChildOfClass("TextLabel")
		if not label then continue end
		local slot = FindEquippedSlot(emoteName)
		label.Text = slot and "Unequip" or "Equip"
	end
end

local function BuildEmoteCards()
	ClearCards()
	table.clear(EmoteCardRefs)

	for _, emoteName in ipairs(OwnedEmotesList) do
		local template = PickTemplate()
		local card     = template:Clone()
		card.Name      = "Card_" .. emoteName
		card.Visible   = true
		card.Parent    = ScrollingFrame

		-- Label
		local nameLabel = card:FindFirstChild("Name")
		if nameLabel then
			nameLabel.Text = emoteName
		end

		-- Viewport
		local viewport = FindItemViewport(card)
		if viewport then
			RenderEmoteViewport(viewport, emoteName)
		end

		-- Botão
		local equipBtn = card:FindFirstChild("Equip")
		if equipBtn and equipBtn:IsA("GuiButton") then
			local label = equipBtn:FindFirstChildOfClass("TextLabel")

			local slot = FindEquippedSlot(emoteName)
			if label then
				label.Text = slot and "Unequip" or "Equip"
			end

			local captured = emoteName
			table.insert(CardConnections, equipBtn.MouseButton1Click:Connect(function()
				local currentSlot = FindEquippedSlot(captured)
				if currentSlot then
					RequestUnequipAndShift(currentSlot)
				else
					local freeSlot = FindFirstFreeSlot()
					if freeSlot then
						RequestEquipEmote(freeSlot, captured)
					else
						warn("[INVENTORY] Todos os slots de emote estão cheios!")
					end
				end
			end))
		end

		EmoteCardRefs[emoteName] = card
		table.insert(ActiveCards, card)

		-- Cada card clona conteúdo pesado no viewport (rig/emote). Cede o frame
		-- a cada item para nunca estourar o watchdog ("exhausted execution time").
		task.wait()
	end

	ApplySearchFilter()
end

---------------- EMOTES ─ Server communication ----------------

local function FetchEmoteInventoryFromServer()
	local getRemote = EmoteRemotes and EmoteRemotes:FindFirstChild("GetEmoteInventory")
	if not getRemote then return end

	local ok, result = pcall(function()
		return getRemote:InvokeServer()
	end)
	if not ok or type(result) ~= "table" then return end

	if type(result.Equipped) == "table" then
		for i = 1, MAX_EMOTE_SLOTS do
			CachedEquipped[i] = result.Equipped[i] or ""
		end
	end

	OwnedEmotesList = result.OwnedList or {}

	-- Só reconstrói se o filtro atual for Emotes
	if CurrentFilter == "Emotes" then
		BuildEmoteCards()
	end
end

local function ListenForEmoteInventoryUpdates()
	local updateRemote = EmoteRemotes and EmoteRemotes:FindFirstChild("EmoteInventoryUpdate")
	if not updateRemote then return end

	updateRemote.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then return end

		if type(data.Equipped) == "table" then
			for i = 1, MAX_EMOTE_SLOTS do
				CachedEquipped[i] = data.Equipped[i] or ""
			end
		end

		local prevOwned    = OwnedEmotesList
		local newOwned     = data.OwnedList or OwnedEmotesList
		local ownedChanged = #prevOwned ~= #newOwned

		if not ownedChanged then
			for i, name in ipairs(newOwned) do
				if prevOwned[i] ~= name then ownedChanged = true; break end
			end
		end

		OwnedEmotesList = newOwned

		if CurrentFilter == "Emotes" then
			if ownedChanged then
				BuildEmoteCards()
			else
				RefreshEmoteButtonStates()
				ApplySearchFilter()
			end
		end
	end)
end

---------------- FILTER SWITCHING ----------------

local function SetFilter(filter)
	CurrentFilter = filter
	CurrentSearch = ""
	SearchBarTextBox.Text = ""

	if filter == "Skins" then
		BuildSkinCards()
	else
		BuildEmoteCards()
	end
end

---------------- PUBLIC API ----------------

function Inventory.ButtonAction(button, action)
	if action == "OpenInventoryUI" then
		if HudUI.Visible == true then 
			Effects.ToggleUI(HudUI)
		end
		
		if InventoryUI.Visible == false then
			Effects.ToggleUI(InventoryUI)
		end
	end
	
	if action == "CloseInventoryUI" then
		if HudUI.Visible == false then
			Effects.ToggleUI(HudUI)
		end
		
		if InventoryUI.Visible == true then
			Effects.ToggleUI(InventoryUI)
		end
	end
end

function Inventory.Init()
	-- Esconde os templates
	for _, t in ipairs(TEMPLATES) do
		t.Visible = false
	end

	-- Resolve remotes de emotes
	local remotes = ReplicatedStorage:WaitForChild("Events", 10)
	if remotes then
		EmoteRemotes = remotes:WaitForChild("Emotes", 10)
	end

	-- Carrega inventory de emotes do servidor
	if EmoteRemotes then
		FetchEmoteInventoryFromServer()
		ListenForEmoteInventoryUpdates()
	end

	-- Filtro inicial: Skins. NÃO constrói os cards no boot — renderizar um rig 3D
	-- por skin num viewport custava ~10s e travava o load de um painel que está
	-- escondido. Constrói só na primeira vez que o inventário é aberto.
	CurrentFilter = "Skins"
	local built = false
	local function buildOnce()
		if built then return end
		built = true
		SetFilter(CurrentFilter)
	end

	InventoryUI:GetPropertyChangedSignal("Visible"):Connect(function()
		if InventoryUI.Visible then
			buildOnce()
		end
	end)
	if InventoryUI.Visible then
		buildOnce()
	end

	-- Botões de filtro
	SkinButton.MouseButton1Click:Connect(function()
		if CurrentFilter ~= "Skins" then
			SetFilter("Skins")
		end
	end)

	EmoteButton.MouseButton1Click:Connect(function()
		if CurrentFilter ~= "Emotes" then
			SetFilter("Emotes")
		end
	end)

	-- Search box
	SearchBarTextBox:GetPropertyChangedSignal("Text"):Connect(function()
		CurrentSearch = SearchBarTextBox.Text
		ApplySearchFilter()
	end)
end

return Inventory