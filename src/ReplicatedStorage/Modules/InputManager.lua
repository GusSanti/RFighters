local InputManager = {}

local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")

local PlayerState = require(game.ReplicatedStorage.PlayerState.PlayerStateClient)
local DefaultData = require(game.ReplicatedStorage.PlayerState.DefaultData)
local Player = Players.LocalPlayer
-- Start from defaults so input works instantly at boot; refreshed from PlayerState
-- once data replicates (see refresh task at the bottom). Never blocks the boot thread.
local InputsConfig = DefaultData.Inputs
local DEBUG_INPUTS = false

local function debugWarn(...)
	if DEBUG_INPUTS then
		warn(...)
	end
end

-- Estados internos
local isDown = {}
local justPressed = {}
local justReleased = {}

-- Cache: EnumItem -> { ActionName, ActionName, ... }
local enumToActions = {}

-- Cache: ActionName -> { EnumItem, EnumItem, ... }
local actionToEnums = {}

-- ================= Cache Build =================

local function safeEnum(enumType, keyName)
	local ok, value = pcall(function()
		return enumType[keyName]
	end)
	if ok then
		return value
	end
	return nil
end

local function rebuildCaches(config)
	if typeof(config) ~= "table" then return end

	InputsConfig = config
	table.clear(actionToEnums)
	table.clear(enumToActions)

	debugWarn(config)

	for action, keys in pairs(config) do
		actionToEnums[action] = {}
		debugWarn(action)

		for _, keyName in ipairs(keys) do
			local enumItem = safeEnum(Enum.KeyCode, keyName)
				or safeEnum(Enum.UserInputType, keyName)

			if enumItem then
				table.insert(actionToEnums[action], enumItem)

				enumToActions[enumItem] = enumToActions[enumItem] or {}
				table.insert(enumToActions[enumItem], action)
			else
				warn("[InputManager] Key inválida no config:", keyName)
			end
		end
	end
end

rebuildCaches(InputsConfig)

-- ================= Utils =================

local function getEnumFromInput(input: InputObject)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		return input.KeyCode
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.MouseButton2
		or input.UserInputType == Enum.UserInputType.MouseButton3 then
		return input.UserInputType
	end

	-- Gamepad / Touch / outros
	return input.UserInputType
end

-- ================= Eventos =================

UIS.InputBegan:Connect(function(input, gp)
	if gp then return end

	local enumItem = getEnumFromInput(input)
	local actions = enumToActions[enumItem]
	if not actions then return end

	for _, action in ipairs(actions) do
		if not isDown[action] then
			justPressed[action] = true
		end

		isDown[action] = true
	end
end)

UIS.InputEnded:Connect(function(input, gp)
	if gp then return end

	local enumItem = getEnumFromInput(input)
	local actions = enumToActions[enumItem]
	if not actions then return end

	for _, action in ipairs(actions) do
		isDown[action] = false
		justReleased[action] = true
	end
end)

-- ⚠️ Limpeza no Heartbeat (depois de toda a lógica do frame)
RunService.Heartbeat:Connect(function()
	table.clear(justPressed)
	table.clear(justReleased)
end)

-- ================= API =================

function InputManager.IsDown(action: string): boolean
	return isDown[action] == true
end

function InputManager.JustPressed(action: string): boolean
	return justPressed[action] == true
end

function InputManager.JustReleased(action: string): boolean
	return justReleased[action] == true
end

function InputManager.GetKey(action: string): EnumItem?
	local list = actionToEnums[action]
	if not list or #list == 0 then return nil end
	return list[1]
end

function InputManager.GetKeys(action: string): { EnumItem }?
	return actionToEnums[action]
end

function InputManager.GetActionByInput(input: InputObject): string?
	local enumItem = getEnumFromInput(input)
	local actions = enumToActions[enumItem]
	return actions and actions[1] or nil
end

function InputManager.GetActionsByInput(input: InputObject): { string }?
	local enumItem = getEnumFromInput(input)
	return enumToActions[enumItem]
end

function InputManager.GetInputSnapshot()
	return {
		IsDown = table.clone(isDown),
		JustPressed = table.clone(justPressed),
		JustReleased = table.clone(justReleased)
	}
end

InputManager.Actions = table.clone(InputsConfig)

-- Refresh from replicated player data once it is ready (non-blocking).
-- Boot never waits on this; defaults are used until/if real data arrives.
task.spawn(function()
	local playerInputs = PlayerState.Get("Inputs")
	if typeof(playerInputs) == "table" then
		rebuildCaches(playerInputs)
		InputManager.Actions = table.clone(InputsConfig)
	end
end)

PlayerState.OnChanged("Inputs", function(newValue)
	if typeof(newValue) == "table" then
		rebuildCaches(newValue)
		InputManager.Actions = table.clone(InputsConfig)
	end
end)

return InputManager
