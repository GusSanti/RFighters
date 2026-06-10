local PlayerInfo = {}

--[[]]
-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Imports
local PlayerState = require(ReplicatedStorage.PlayerState.PlayerStateServer)

-- Referência à Part com BillboardGui que está dentro do script PlayerInfo
local NametagTemplate = script:WaitForChild("PlayerInfo")

-- Função que aplica o nametag no character
local function onCharacterAdded(character, player)
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	local head = character:WaitForChild("Head", 10)
	if not hrp or not head then return end

	local nametag = NametagTemplate:Clone()
	nametag.Parent = character

	-- Posiciona relativo ao HRP antes de soldar
	nametag.CFrame = hrp.CFrame * CFrame.new(0, 2, 0)
	nametag.Anchored = false
	nametag.Massless = true
	nametag.CanCollide = false

	-- Weld DEPOIS de posicionar
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = nametag  -- era "nametaga" (typo) no seu código
	weld.Parent = nametag

	local billboardGui = nametag:FindFirstChildWhichIsA("BillboardGui")
	if not billboardGui then return end

	local frame = billboardGui:FindFirstChildWhichIsA("Frame")
	if not frame then return end

	local playerNameLabel = frame:FindFirstChild("PlayerName")
	if playerNameLabel and playerNameLabel:IsA("TextLabel") then
		playerNameLabel.Text = player.Name
	end

	local levelImageLabel = frame:FindFirstChild("Level")
	if levelImageLabel and levelImageLabel:IsA("ImageLabel") then
		local levelText = levelImageLabel:FindFirstChild("LevelText")
		if levelText and levelText:IsA("TextLabel") then
			levelText.Text = tostring(PlayerState.Get(player, "Level") or 1)
		end
	end

	if PlayerState.OnChanged then
		PlayerState.OnChanged(player, "Level", function(newVal)
			if not levelImageLabel or not levelImageLabel.Parent then return end
			local lt = levelImageLabel:FindFirstChild("LevelText")
			if lt then lt.Text = tostring(newVal) end
		end)
	end
	
	local tagIndex = PlayerState.Get(player, 'EquippedTag')
	local tagLabel = nil
	if tagIndex then
		local PlayerTags = PlayerState.Get(player, 'Tags')
		tagLabel = PlayerTags and PlayerTags[tagIndex] and PlayerTags[tagIndex].Label
	end

	local tagTextLabel = frame:FindFirstChild("Tag")
	if tagTextLabel then
		local display = "[" .. string.upper(tagLabel or "NEWCOMMER") .. "]"
		tagTextLabel.Text = display
		local text2 = tagTextLabel:FindFirstChild("Text2")
		if text2 then text2.Text = display end
	end
end

-- Conecta para cada jogador que entrar
Players.PlayerAdded:Connect(function(player)
	PlayerState.Init(player)

	-- Caso o character já exista
	if player.Character then
		onCharacterAdded(player.Character, player)
	end

	-- Conecta para respawns futuros
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(character, player)
	end)
end)

-- Cobre jogadores já conectados (útil em Studio)
for _, player in Players:GetPlayers() do
	if player.Character then
		onCharacterAdded(player.Character, player)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(character, player)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	-- cleanup futuro se necessário
end)

return PlayerInfo