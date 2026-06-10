local Tags = {}
local localPlayer = game.Players.LocalPlayer
if not game:IsLoaded() then game.Loaded:Wait() end

local PlayerState    = require(game.ReplicatedStorage.PlayerState.PlayerStateClient)
local playerGui      = localPlayer:WaitForChild("PlayerGui")
local MainUI         = playerGui:WaitForChild("UI")
local TagsUI         = MainUI:WaitForChild("Tags")

local ScrollingFrame = TagsUI.MAIN.ScrollingFrame
local Template       = ScrollingFrame:WaitForChild("Template")

local Events         = game.ReplicatedStorage.QuestAchievementsSystem.Events
local ClaimTag       = Events.ClaimTag
local SelectTag      = Events.SelectTag   -- novo RemoteEvent

local equippedTagIndex = nil

local function GetTagFrame(index)
	return ScrollingFrame:FindFirstChild(tostring(index))
end

local function RefreshTagFrame(frame, tagInfo, index)
	local btnSelect   = frame:FindFirstChild("Select")
	local btnSelected = frame:FindFirstChild("Selected")
	local btnClaim    = frame:FindFirstChild("Claim")
	local btnLocked   = frame:FindFirstChild("Locked")

	for _, btn in ipairs({btnSelect, btnSelected, btnClaim, btnLocked}) do
		if btn then btn.Visible = false end
	end

	local isEquipped = (equippedTagIndex == index)

	if not tagInfo.Completed then
		if btnLocked then btnLocked.Visible = true end
	else
		if isEquipped then
			if btnSelected then btnSelected.Visible = true end
		else
			if btnSelect then btnSelect.Visible = true end
		end
	end
end

local function RefreshAll()
	local PlayerTags = PlayerState.Get('Tags')
	if not PlayerTags then return end
	for index, tagInfo in ipairs(PlayerTags) do
		local frame = GetTagFrame(index)
		if frame then
			RefreshTagFrame(frame, tagInfo, index)
		end
	end
end

function Tags.Init()
	local PlayerTags = PlayerState.Get('Tags')
	if not PlayerTags then
		warn('[TAGS CLIENT] Sem dados de tags')
		return
	end

	for _, child in ipairs(ScrollingFrame:GetChildren()) do
		if child.Name ~= "Template" and child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, tagInfo in ipairs(PlayerTags) do
		local newFrame = Template:Clone()
		newFrame.Name    = tostring(index)
		newFrame.Parent  = ScrollingFrame
		newFrame.Visible = true

		newFrame.TagName.Text        = tagInfo.Label
		newFrame.TagDescription.Text = tagInfo.Description

		local btnSelect   = newFrame:FindFirstChild("Select")
		local btnSelected = newFrame:FindFirstChild("Selected")
		local btnClaim    = newFrame:FindFirstChild("Claim")
		local btnLocked   = newFrame:FindFirstChild("Locked")

		if btnSelect then
			btnSelect.MouseButton1Click:Connect(function()
				Tags.ButtonAction(btnSelect, 'SelectTag', index)
			end)
		end

		if btnSelected then
			btnSelected.MouseButton1Click:Connect(function()
				Tags.ButtonAction(btnSelected, 'DeselectTag', index)
			end)
		end

		if btnClaim then
			btnClaim.MouseButton1Click:Connect(function()
				Tags.ButtonAction(btnClaim, 'ClaimTag', index)
			end)
		end

		if btnLocked then
			btnLocked.MouseButton1Click:Connect(function()
				Tags.ButtonAction(btnLocked, 'LockedTag', index)
			end)
		end

		RefreshTagFrame(newFrame, tagInfo, index)
	end
end

function Tags.ButtonAction(button, action, tagIndex)

	if action == 'SelectTag' then
		equippedTagIndex = tagIndex
		SelectTag:FireServer('Select', tagIndex)  -- servidor salva
		RefreshAll()

	elseif action == 'DeselectTag' then
		equippedTagIndex = nil
		SelectTag:FireServer('Deselect', nil)     -- servidor salva
		RefreshAll()

	elseif action == 'ClaimTag' then
		ClaimTag:FireServer(tagIndex)
		-- feedback visual imediato (servidor vai confirmar)
		local PlayerTags = PlayerState.Get('Tags')
		if PlayerTags and PlayerTags[tagIndex] then
			PlayerTags[tagIndex].Completed = true
		end
		RefreshAll()

	elseif action == 'LockedTag' then
		print('[TAGS] Tag bloqueada, index:', tagIndex)
	end
end

return Tags