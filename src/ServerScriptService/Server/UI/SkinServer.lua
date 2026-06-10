local module = {}

local PlayerState = require(game.ReplicatedStorage.PlayerState.PlayerStateServer)
local SkinsDataModule = require(game.ReplicatedStorage.UI.Systems.Inventory.SkinsData)
local SkinsData = SkinsDataModule.SkinsData
local LimitedSkins = SkinsDataModule.LimitedSkins

local SkinsEventsFolder = game.ReplicatedStorage:WaitForChild("Events"):WaitForChild("Skins")
local EquipSkinEvent = SkinsEventsFolder:WaitForChild("EquipSkin")
local UnequipSkinEvent = SkinsEventsFolder:WaitForChild("UnequipSkin")
local GetEquippedSkinFunc = SkinsEventsFolder:WaitForChild("GetEquippedSkin")
local UnlockSkinEvent = SkinsEventsFolder:WaitForChild("UnlockSkin")
local LockSkinEvent = SkinsEventsFolder:WaitForChild("LockSkin")

local CombatStorage = game.ReplicatedStorage:WaitForChild("CombatStorage")
local CharacterAnimationsFolder = game.ReplicatedStorage:WaitForChild("CharacterAnimationsCodes")
local LimitedSkinsFolder = workspace.Stands.Limiteds
local SpawnLeft = LimitedSkinsFolder.SpawnLeft
local SpawnRight = LimitedSkinsFolder.SpawnRight

local BuyPromptTemplate = game.ReplicatedStorage.Assets.Skins:WaitForChild("BuyPrompt")
local HeaderTemplate = game.ReplicatedStorage.Assets.Skins:WaitForChild("HeaderTemplate")

local WEEK_IN_SECONDS = 60 * 60 * 24 * 7
local DISPLAY_MODEL_HEIGHT_OFFSET = -0.35
local DisplayAnimationSources = {
	CharacterAnimationsFolder:WaitForChild("CharacterAnimation1"),
	CharacterAnimationsFolder:WaitForChild("CharacterAnimation2"),
}

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function GetPlayerSkins(player)
	return PlayerState.Get(player, "UnlockedSkins") or {}
end

local function SetPlayerSkins(player, skinsData)
	PlayerState.Set(player, "UnlockedSkins", skinsData)
end

local function SkinExistsInData(character, skinName)
	return SkinsData[character] ~= nil and SkinsData[character][skinName] ~= nil
end

local function UnequipAllForCharacter(skinsData, character)
	if not skinsData[character] then
		return skinsData
	end

	for skinName, _ in pairs(skinsData[character]) do
		skinsData[character][skinName].IsEquiped = false
	end

	return skinsData
end

local function GetDisplayAnimationId(animationSource)
	if animationSource:IsA("Animation") then
		return animationSource.AnimationId
	end

	if animationSource:IsA("ModuleScript") then
		local ok, result = pcall(require, animationSource)
		if not ok then
			warn("[LIMITED] Não foi possível carregar animação:", animationSource.Name, result)
			return nil
		end

		if type(result) == "string" then
			return result
		end

		if type(result) == "table" then
			return result.AnimationId or result.IDLE_ANIM_ID or result.Id
		end
	end

	return nil
end

local function ApplyDisplayAnimation(model, animationSource)
	if not animationSource then
		return
	end

	if animationSource:IsA("Script") then
		local animationScript = animationSource:Clone()
		animationScript.Disabled = false
		animationScript.Parent = model
		return
	end

	local animationId = GetDisplayAnimationId(animationSource)
	if not animationId then
		warn("[LIMITED] Fonte de animação inválida para display:", animationSource.Name)
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("[LIMITED] Humanoid não encontrado no modelo:", model.Name)
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId

	local animTrack = animator:LoadAnimation(animation)
	animTrack.Looped = true
	animTrack:Play()
end

-- ─── Limited Skins Display ────────────────────────────────────────────────────

-- Guarda referência aos modelos atualmente em display pra poder limpar depois
local ActiveDisplayModels = {}

local function ClearDisplayModels()
	for _, model in ipairs(ActiveDisplayModels) do
		if model and model.Parent then
			model:Destroy()
		end
	end

	table.clear(ActiveDisplayModels)
end

--[[
	Recebe uma entrada do LimitedSkins e o spawner (SpawnLeft ou SpawnRight),
	clona o modelo do CombatStorage, ancora na posição do spawner,
	e insere o BuyPrompt no HumanoidRootPart.
]]
local function SpawnLimitedSkinDisplay(limitedEntry, spawner, animationSource)
	local character = nil
	local skinName = nil

	for charName, skins in pairs(SkinsData) do
		for sName, sData in pairs(skins) do
			if sData == limitedEntry.Skin then
				character = charName
				skinName = sName
				break
			end
		end

		if character then
			break
		end
	end

	if not character or not skinName then
		warn("[LIMITED] Não foi possível identificar o personagem da skin:", limitedEntry)
		return
	end

	local characterFolder = CombatStorage:FindFirstChild(character)
	if not characterFolder then
		warn("[LIMITED] CombatStorage: personagem não encontrado:", character)
		return
	end

	local modelName = limitedEntry.Skin.ModelName
	local skinModel = characterFolder:FindFirstChild(modelName)
	if not skinModel or not skinModel:IsA("Model") then
		warn("[LIMITED] Modelo não encontrado:", modelName, "em", character)
		return
	end

	local clone = skinModel:Clone()
	local rootPart = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart

	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = desc == rootPart
			desc.CanCollide = false
		end
	end

	local spawnCFrame = spawner.CFrame
	local _, modelSize = clone:GetBoundingBox()
	local offset = CFrame.new(0, (modelSize.Y / 2) + DISPLAY_MODEL_HEIGHT_OFFSET, 0)
	clone:PivotTo(spawnCFrame * offset)

	clone.Parent = LimitedSkinsFolder

	local hrp = clone:FindFirstChild("HumanoidRootPart")
	if hrp then
		local prompt = BuyPromptTemplate:Clone()
		prompt:SetAttribute("ProductID", limitedEntry.ProductID)
		prompt.Parent = hrp

		local header = HeaderTemplate:Clone()
		header.Label.Text = limitedEntry.DisplayTitle
		header.Parent = hrp
	else
		warn("[LIMITED] HumanoidRootPart não encontrado no modelo:", modelName)
	end

	ApplyDisplayAnimation(clone, animationSource)

	table.insert(ActiveDisplayModels, clone)
end

local function GetCurrentWeekSeed()
	-- Quantas semanas completas passaram desde Unix epoch
	-- Todos os servers no mesmo período vão ter o mesmo seed
	return math.floor(os.time() / WEEK_IN_SECONDS)
end

local function GetSecondsUntilNextWeek()
	local now = os.time()
	local weekStart = math.floor(now / WEEK_IN_SECONDS) * WEEK_IN_SECONDS
	return WEEK_IN_SECONDS - (now - weekStart)
end

local function PickLimitedSkinsForWeek()
	local seed = GetCurrentWeekSeed()
	local rng = Random.new(seed)

	-- Copia e embaralha com o seed da semana (Fisher-Yates)
	local pool = table.clone(LimitedSkins)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	-- Retorna as 2 primeiras
	local count = math.min(#pool, 2)
	local result = {}
	for i = 1, count do
		result[i] = pool[i]
	end

	return result
end

local function RotateLimitedSkins()
	ClearDisplayModels()

	local picks = PickLimitedSkinsForWeek()
	local spawners = { SpawnLeft, SpawnRight }

	for i, entry in ipairs(picks) do
		local animationSource = DisplayAnimationSources[((i - 1) % #DisplayAnimationSources) + 1]
		SpawnLimitedSkinDisplay(entry, spawners[i], animationSource)
	end

	print("[LIMITED] Skins rotacionadas para a semana:", GetCurrentWeekSeed())
end

local function StartWeeklyRotationLoop()
	task.spawn(function()
		while true do
			RotateLimitedSkins()
			-- Espera exatamente até o início da próxima semana
			task.wait(GetSecondsUntilNextWeek())
		end
	end)
end

-- ─── Loop semanal ─────────────────────────────────────────────────────────────

StartWeeklyRotationLoop()

-- ─── EquipSkin ────────────────────────────────────────────────────────────────

EquipSkinEvent.OnServerEvent:Connect(function(player, character, skinName)
	if type(character) ~= "string" or type(skinName) ~= "string" then
		warn("[SKINS] Argumentos inválidos no EquipSkin | Player:", player.Name)
		return
	end

	if not SkinExistsInData(character, skinName) then
		warn("[SKINS] Skin não existe no SkinsData:", character, skinName)
		return
	end

	local skinsData = GetPlayerSkins(player)

	local playerSkin = skinsData[character] and skinsData[character][skinName]
	if not playerSkin or not playerSkin.IsUnlocked then
		warn("[SKINS] Skin bloqueada ou não registrada:", skinName, "| Player:", player.Name)
		return
	end

	if playerSkin.IsEquiped then
		warn("[SKINS] Skin já equipada:", skinName, "| Player:", player.Name)
		return
	end

	skinsData = UnequipAllForCharacter(skinsData, character)
	skinsData[character][skinName].IsEquiped = true

	SetPlayerSkins(player, skinsData)
	print("[SKINS] Skin equipada:", skinName, "|", character, "|", player.Name)
end)

-- ─── UnequipSkin ──────────────────────────────────────────────────────────────

UnequipSkinEvent.OnServerEvent:Connect(function(player, character)
	if type(character) ~= "string" then
		warn("[SKINS] character inválido no UnequipSkin | Player:", player.Name)
		return
	end

	local skinsData = GetPlayerSkins(player)
	skinsData = UnequipAllForCharacter(skinsData, character)
	SetPlayerSkins(player, skinsData)
	print("[SKINS] Skin desequipada:", character, "|", player.Name)
end)

-- ─── UnlockSkin ───────────────────────────────────────────────────────────────

UnlockSkinEvent.Event:Connect(function(player, character, skinName)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		warn("[SKINS] player inválido no UnlockSkin")
		return
	end

	if type(character) ~= "string" or type(skinName) ~= "string" then
		warn("[SKINS] Argumentos inválidos no UnlockSkin")
		return
	end

	if not SkinExistsInData(character, skinName) then
		warn("[SKINS] Skin não existe no SkinsData:", character, skinName)
		return
	end

	local skinsData = GetPlayerSkins(player)

	if not skinsData[character] then
		skinsData[character] = {}
	end

	if skinsData[character][skinName] and skinsData[character][skinName].IsUnlocked then
		warn("[SKINS] Skin já desbloqueada:", skinName, "| Player:", player.Name)
		return
	end

	local baseData = SkinsData[character][skinName]
	skinsData[character][skinName] = {
		ModelName = baseData.ModelName,
		DisplayName = baseData.DisplayName,
		IsUnlocked = true,
		IsEquiped = false,
	}

	SetPlayerSkins(player, skinsData)
	print("[SKINS] Skin desbloqueada:", skinName, "|", character, "|", player.Name)
end)

-- ─── LockSkin ─────────────────────────────────────────────────────────────────

LockSkinEvent.Event:Connect(function(player, character, skinName)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		warn("[SKINS] player inválido no LockSkin")
		return
	end

	if type(character) ~= "string" or type(skinName) ~= "string" then
		warn("[SKINS] Argumentos inválidos no LockSkin")
		return
	end

	local skinsData = GetPlayerSkins(player)

	if not skinsData[character] or not skinsData[character][skinName] then
		warn("[SKINS] Skin já está bloqueada/não registrada:", skinName, "| Player:", player.Name)
		return
	end

	local wasEquipped = skinsData[character][skinName].IsEquiped
	skinsData[character][skinName] = nil

	if next(skinsData[character]) == nil then
		skinsData[character] = nil
	end

	SetPlayerSkins(player, skinsData)

	if wasEquipped then
		print("[SKINS] Skin desequipada por bloqueio:", skinName, "|", player.Name)
	end

	print("[SKINS] Skin bloqueada:", skinName, "|", character, "|", player.Name)
end)

-- ─── GetEquippedSkin ──────────────────────────────────────────────────────────

GetEquippedSkinFunc.OnInvoke = function(player, character)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return "default"
	end

	if type(character) ~= "string" then
		return "default"
	end

	local skinsData = GetPlayerSkins(player)
	if not skinsData[character] then
		return "default"
	end

	for skinName, skinData in pairs(skinsData[character]) do
		if skinData.IsEquiped and skinData.IsUnlocked then
			return skinData.ModelName or skinName
		end
	end

	return "default"
end

return module
