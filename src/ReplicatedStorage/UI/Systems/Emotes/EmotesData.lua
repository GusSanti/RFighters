------------------//CONSTANTS
local EmotesData = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function NormalizeName(value)
	return string.lower((string.gsub(tostring(value), "[%s_%-%./]", "")))
end

local function ResolveEmoteAnimationId(emoteName)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local gameplay = assets and assets:FindFirstChild("Gameplay")
	local animations = gameplay and gameplay:FindFirstChild("Animations")
	local emotes = animations and animations:FindFirstChild("Emotes")
	if not emotes then
		return ""
	end

	local direct = emotes:FindFirstChild(emoteName, true)
	if direct and direct:IsA("Animation") then
		return direct.AnimationId
	end

	local normalizedName = NormalizeName(emoteName)
	for _, descendant in emotes:GetDescendants() do
		if descendant:IsA("Animation") and NormalizeName(descendant.Name) == normalizedName then
			return descendant.AnimationId
		end
	end

	return ""
end

EmotesData.Emotes = {
	TOXIC = {
		["TAKE_THE_L"] = {
			Name = "Take The L",
			Rarity = "Exclusive",
			Weight = 0,
			ImageId = "",
			AnimationId = "rbxassetid://71461200183545",
		}
	},
	
	ANIME = {
		["JOJO_POSE"] = {
			Name = "Jojo Pose",
			Rarity = "Exclusive",
			Weight = 0,
			ImageId = "",
			AnimationId = "rbxassetid://128401107674263"
		}
	}
}

------------------//FUNCTIONS
function EmotesData.GetEmote(emoteName)
	-- Busca direta na raiz
	if EmotesData.Emotes[emoteName] then
		return EmotesData.Emotes[emoteName]
	end
	-- Busca em subcategorias
	for _, category in pairs(EmotesData.Emotes) do
		if type(category) == "table" and not category.AnimationId then
			if category[emoteName] then
				return category[emoteName]
			end
		end
	end
	return nil
end	

function EmotesData.GetItemViewport(itemName)
	local itemData = EmotesData.Emotes[itemName]
	if not itemData then
		warn("EmotesData: Emote not found - " .. tostring(itemName))
		return nil
	end

	if type(itemData.ImageId) ~= "string" or itemData.ImageId == "" then
		return nil
	end

	local image = Instance.new("ImageLabel")
	image.Name = "Viewport_" .. itemName
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = itemData.ImageId
	image.ScaleType = Enum.ScaleType.Fit
	return image
end

------------------//INIT
return EmotesData
