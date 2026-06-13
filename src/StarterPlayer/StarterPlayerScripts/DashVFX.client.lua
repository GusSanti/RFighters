local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local VFX = require(ReplicatedStorage.Modules.Utilitary.VFX)

local localPlayer = Players.LocalPlayer
local ServerEvents = ReplicatedStorage.CombatSystem.Events.ServerEvents
local DashVFXTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Effects"):WaitForChild("VFXPart", 10)

local DASH_VFX_LIFETIME = 1
local DASH_VFX_OFFSET = CFrame.new(0, 0.25, 1.6)
local DASH_VFX_ROTATION = CFrame.Angles(math.rad(90), 0, 0)

local function sanitizeEffect(effect: Instance)
	for _, descendant in ipairs(effect:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		elseif descendant:IsA("Weld")
			or descendant:IsA("WeldConstraint")
			or descendant:IsA("Motor6D")
		then
			descendant:Destroy()
		end
	end
end

local function getEffectParent(): Instance
	local world = workspace:FindFirstChild("World")
	local visuals = world and world:FindFirstChild("Visuals")
	return visuals or workspace
end

local function playDashVFX()
	if not DashVFXTemplate then return end

	local character = localPlayer.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then return end

	local effect = DashVFXTemplate:Clone()
	sanitizeEffect(effect)
	effect.Parent = getEffectParent()

	local targetCFrame = rootPart.CFrame * DASH_VFX_OFFSET * DASH_VFX_ROTATION
	if effect:IsA("Model") then
		effect:PivotTo(targetCFrame)
	elseif effect:IsA("BasePart") then
		effect.CFrame = targetCFrame
	end

	VFX.play(effect :: any)
	Debris:AddItem(effect, DASH_VFX_LIFETIME)
end

ServerEvents.OnClientEvent:Connect(function(action)
	if action ~= "ExecuteDash" then return end
	playDashVFX()
end)
