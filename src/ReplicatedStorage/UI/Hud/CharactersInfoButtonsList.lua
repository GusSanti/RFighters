--!strict
local Module = {}

local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local SoundService      = game:GetService("SoundService")
local Players           = game:GetService("Players")

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local SoundFolder = SoundService:WaitForChild("Sounds")

function Module.ButtonAction(button: GuiButton)
	SoundFolder.ClickSound:Play()

	-- Pega o ImageLabel pai para saber qual raridade é
	local rarityLabel = button.Parent
	while rarityLabel and not rarityLabel:IsA("ImageLabel") do
		rarityLabel = rarityLabel.Parent
	end

	if not rarityLabel then
		warn(`[RarityModule] ImageLabel pai não encontrado`)
		return
	end

	local rarity = rarityLabel.Name -- ex: "Common", "Rare", "Legendary"...

	-- Pega todos os objetos com a tag igual ao nome da raridade
	local tagged = CollectionService:GetTagged(rarity)
	if #tagged == 0 then
		warn(`[RarityModule] Nenhum objeto com tag "{rarity}" encontrado`)
		return
	end

	-- Descobre o estado atual pelo primeiro item que NÃO é o botão
	local currentVisible = true
	for _, instance in ipairs(tagged) do
		if instance ~= button and instance:IsA("GuiObject") then
			currentVisible = instance.Visible
			break
		end
	end
	
	local targetRotation = button.Rotation == 0 and 180 or 0

	TweenService:Create(
		button,
		TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Rotation = targetRotation }
	):Play()

	-- Toggle: esconde se estava visível, mostra se estava invisível
	for _, instance in ipairs(tagged) do
		if instance ~= button and instance:IsA("GuiObject") then
			instance.Visible = not currentVisible
		end
	end
end

function Module.Init()
	print("[CharactersInfoButtonsListModule] Initialized")
end

return Module