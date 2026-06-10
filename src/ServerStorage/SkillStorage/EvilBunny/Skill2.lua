local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local Assets            = ReplicatedStorage.SkillStorage.Thoosa
local Fx                = Assets.FX
local Sounds            = Assets.Sounds
local Animations        = Assets.Animations

local DeathConnectionEvent = game.ReplicatedStorage.CombatSystem.Events.DeathConnectionEvent
local SendDamageIndicator = game.ReplicatedStorage.Events:WaitForChild("SendDamageIndicator")
local IncreaseUltProgress = game.ReplicatedStorage.Events.IcreaseUltProgress


local CombatReplicator = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local Utilities         = require(ReplicatedStorage.Modules.Utilitary.Utils)

local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local HitboxModule      = require(ServerStorage.FightModules.HitboxHandler)
local DamageIndicator   = require(ReplicatedStorage.Modules.Shared:WaitForChild("DamageIndicator"))
local knockback         = require(ServerStorage.FightModules.Knockback)
local CombatBlock       = require(game.ReplicatedStorage.CombatSystem.CombatBlock)

local BARRAGE_CONFIG = {
	DamagePerHit   = 5,
	HitboxSize     = Vector3.new(8, 8, 11),
	HitboxOffset   = CFrame.new(0, 0, -6),
	NormalKnockback = {
		MaxForce           = Vector3.new(2e4, 0, 2e4),
		VelocityMultiplier = 15,
		Duration           = 0.08
	},
	UltimateGainPerHit = 100,
}

local playerStates = {}

local function setupPlayerState(player)
	local userId = player.UserId
	if not playerStates[userId] then
		playerStates[userId] = {
			barrageActive = false,
			Sfx           = nil,
			Sfx2           = nil,
		}
	end
end

Players.PlayerAdded:Connect(setupPlayerState)
Players.PlayerRemoving:Connect(function(player)
	playerStates[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayerState(player)
end

local function applyNormalKnockback(character, attackerHumRP)
	local config = BARRAGE_CONFIG.NormalKnockback
	local direction = attackerHumRP.CFrame.LookVector
	knockback:Knockback(character, {
		MaxForce = config.MaxForce,
		Velocity  = direction * config.VelocityMultiplier,
		Duration  = config.Duration
	})
end

function module.UseSkill(char: Model)
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end

	local userId = player.UserId
	local state  = playerStates[userId]
	if not state then
		setupPlayerState(player)
		state = playerStates[userId]
	end

	if state.barrageActive then return end

	local humanoid = char:FindFirstChild("Humanoid")
	local humRP    = char:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChild("Animator")

	if not (humanoid and humRP and animator) or humanoid.Health <= 0 then return end

	local getCharacter = StateManager.GET(char)
	if getCharacter and getCharacter[StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED] or getCharacter[StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED] then return end

	local animObj = Animations:FindFirstChild("Ability2")
	if not animObj then
		warn("[Grim ultimate] Animação não encontrada")
		return
	end

	local BarrageTrack  = animator:LoadAnimation(animObj)

	BarrageTrack.Priority = Enum.AnimationPriority.Action2
	BarrageTrack:Play()
	
	task.delay(0.5, function()
		CombatReplicator.Emit(char:FindFirstChild('Left Leg'), Fx["Ability 2"])
		
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.OutlineColor = Color3.fromRGB(255, 193, 37)
		highlight.FillColor = Color3.fromRGB(255, 193, 37)
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = char
		highlight.Enabled = true
		Debris:AddItem(highlight, 4)

		StateManager.POST_REMOVE(player, StateManagerEnums.STATES_ENUM.COMBAT_DEFENSE_EFFECT, 4)
	end)
end

return module