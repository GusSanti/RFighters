local Update = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Imports
local PlayerState = require(ReplicatedStorage.PlayerState.PlayerStateClient)
local Characters = require(ReplicatedStorage.CharacterInfo.CharacterInfoModule)

-- Client
local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = localPlayer:WaitForChild("PlayerGui")
local Main = PlayerGui:WaitForChild("UI")

-- HUD
local CrystalsLabel = Main.HUD.Crystal.TextLabel
local DiamondsLabel = Main.HUD.Diamonds.TextLabel

local CrystalsLabelRoll = Main.Roll.Crystal.TextLabel
local DiamondsLabelRoll = Main.Roll.Diamonds.TextLabel

-- FightingFrame
local FightingFrame = Main:WaitForChild("FightingFrame")
local AbilitiesFrame = FightingFrame:WaitForChild("Abilities")

-- Slots de ability (Ability = Skill1, Ability2 = Skill2, Ability3 = Ultimate)
local AbilitySlots = {
	AbilitiesFrame:WaitForChild("Ability"),
	AbilitiesFrame:WaitForChild("Ability2"),
	AbilitiesFrame:WaitForChild("Ability3"),
}

-- Guarda o tamanho original de cada slot
local OriginalSizes = {}
for i, slot in ipairs(AbilitySlots) do
	OriginalSizes[i] = slot.Size
end

-- Tween info
local TWEEN_FLASH_IN  = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_FLASH_OUT = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Mapa bind -> índice do slot
local BindToSlot = {}

-- Pega o CharacterData pelo id
local function GetCharacterData(id: string)
	for _, data in ipairs(Characters) do
		if data.id == id then
			return data
		end
	end
	return nil
end

-- Reconstrói o mapa de bind -> slot index
local function RebuildBindMap(characterId: string)
	BindToSlot = {}
	local data = GetCharacterData(characterId)
	if not data or not data.Skills then return end
	for i, skill in ipairs(data.Skills) do
		BindToSlot[skill.bind] = i
	end
end

-- Atualiza os slots de ability com os dados do personagem ativo
local function UpdateAbilitySlots(characterId: string)
	local data = GetCharacterData(characterId)
	if not data or not data.Skills then return end

	for i, slot in ipairs(AbilitySlots) do
		local skill = data.Skills[i]
		if not skill then continue end

		-- Nome da skill (Ability > Text)
		local abilityFrame = slot:FindFirstChild("Ability")
		if abilityFrame then
			local text = abilityFrame:FindFirstChild("Text")
			if text then
				text.Text = skill.name
			end
		end

		-- Bind (Bind > Text)
		local bindFrame = slot:FindFirstChild("Bind")
		if bindFrame then
			local text = bindFrame:FindFirstChild("Text")
			if text then
				local displayBind = skill.bind
				if displayBind == "One"   then displayBind = "1"
				elseif displayBind == "Two"   then displayBind = "2"
				elseif displayBind == "Three" then displayBind = "3"
				elseif displayBind == "Four"  then displayBind = "4"
				end
				text.Text = displayBind
			end
		end
	end
end

-- SETUP inicial
CrystalsLabel.Text = tostring(PlayerState.Get("Crystals"))
CrystalsLabelRoll.Text = tostring(PlayerState.Get("Crystals"))
DiamondsLabel.Text = tostring(PlayerState.Get("Diamonds"))
DiamondsLabelRoll.Text = tostring(PlayerState.Get("Diamonds"))

UpdateAbilitySlots(PlayerState.Get("ActiveCharacter"))
RebuildBindMap(PlayerState.Get("ActiveCharacter"))

-- UPDATE de estado
PlayerState.OnChanged("Crystals", function(newVal)
	CrystalsLabel.Text = tostring(newVal)
	CrystalsLabelRoll.Text = tostring(newVal)
end)

PlayerState.OnChanged("Diamonds", function(newVal)
	DiamondsLabel.Text = tostring(newVal)
	DiamondsLabelRoll.Text = tostring(newVal)
end)

PlayerState.OnChanged("ActiveCharacter", function(newId)
	UpdateAbilitySlots(newId)
	RebuildBindMap(newId)
end)

-- Input highlight: tween de size quando a bind for pressionada
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end

	local keyName = input.KeyCode.Name
	local slotIndex = BindToSlot[keyName]
	if not slotIndex then return end

	local slot = AbilitySlots[slotIndex]
	if not slot then return end

	local originalSize = OriginalSizes[slotIndex]
	local bigSize = UDim2.new(
		originalSize.X.Scale * 1.15, originalSize.X.Offset,
		originalSize.Y.Scale * 1.15, originalSize.Y.Offset
	)

	TweenService:Create(slot, TWEEN_FLASH_IN, { Size = bigSize }):Play()
	task.delay(0.1, function()
		TweenService:Create(slot, TWEEN_FLASH_OUT, { Size = originalSize }):Play()
	end)
end)

return Update