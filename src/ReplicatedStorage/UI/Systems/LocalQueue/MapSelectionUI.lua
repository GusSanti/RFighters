local MapSelectionModule = {}

local Effects = require(script.Parent.Parent.Parent.Effects)

local MapSelectionUI   -- injetado via Init
local LocalQueue1v1UI
local LocalQueue2v2UI
local MapSelectionTable
local MapImageTable

function MapSelectionModule.Init(mapSelUI, q1v1UI, q2v2UI, mapTable, imageTable)
	MapSelectionUI   = mapSelUI
	LocalQueue1v1UI  = q1v1UI
	LocalQueue2v2UI  = q2v2UI
	MapSelectionTable = mapTable
	MapImageTable     = imageTable
end

function MapSelectionModule.Clone()
	for mapName in pairs(MapSelectionTable) do
		local clone = MapSelectionUI.Main.ScrollingFrame.MapTemplate:Clone()
		clone.Parent    = MapSelectionUI.Main.ScrollingFrame
		clone.Name      = mapName
		clone.MapName.Text  = mapName
		clone.MapImage.Image = MapImageTable[mapName]
		clone.Visible   = true
	end
	if LocalQueue1v1UI.Visible then Effects.ToggleUI(LocalQueue1v1UI) end
	if LocalQueue2v2UI.Visible then Effects.ToggleUI(LocalQueue2v2UI) end
end

function MapSelectionModule.Cleanup()
	MapSelectionUI.Main.Mode.Text = 'None'
	for _, mapUI in MapSelectionUI.Main.ScrollingFrame:GetChildren() do
		if mapUI:IsA("ImageButton") and mapUI.Name ~= 'MapTemplate' then
			mapUI:Destroy()
		end
	end
end

function MapSelectionModule.SetMode(mode)
	MapSelectionUI.Main.Mode.Text = mode
end

function MapSelectionModule.GetSelectedMap()
	return MapSelectionTable[MapSelectionUI.Main.SelectedMap.Text]
end

function MapSelectionModule.SelectMap(name)
	MapSelectionUI.Main.SelectedMap.Text = name
end

return MapSelectionModule