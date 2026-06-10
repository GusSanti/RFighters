local module = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local Assets            = ReplicatedStorage.SkillStorage.Sparrow
local Fx                = Assets.FX
local Sounds            = Assets.Sounds
local Animations        = Assets.Animations

local DeathConnectionEvent = game.ReplicatedStorage.CombatSystem.Events.DeathConnectionEvent
local SendStreakUpdate = game.ReplicatedStorage.Events:WaitForChild("UpdateStreakInfo")
local IncreaseUltProgress = game.ReplicatedStorage.Events.IcreaseUltProgress

local CombatReplicator = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local StateManager      = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local DamageIndicator   = require(ReplicatedStorage.Modules.Shared:WaitForChild("DamageIndicator"))
local DamageModule = require(game.ReplicatedStorage.CombatSystem.DamageModule)

local SKILL_CONFIG = {
	HealPerTick     = 8,
	HealTickRate    = 1,
	HealDuration    = 5,
	TotalTicks      = 5, -- HealDuration / HealTickRate
}

function module.UseSkill(char: Model)
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end

	local humanoid  = char:FindFirstChild("Humanoid")
	local humRP     = char:FindFirstChild("HumanoidRootPart")
	local animator  = humanoid and humanoid:FindFirstChild("Animator") :: Animator

	if not (humanoid and humRP and animator) then return end

	local SkillTrack = animator:LoadAnimation(Animations.Ability2) :: AnimationTrack

	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
	StateManager.POST(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	SkillTrack.Priority = Enum.AnimationPriority.Action2
	SkillTrack:Play()

	-- controla se o buff foi ativado e se está rodando
	local buffActivated = false
	local buffRunning   = false
	local buffThread    = nil

	-- função que roda o heal ao longo do tempo
	local function RunHealthBuff()
		if buffRunning then return end
		buffRunning  = true
		buffActivated = true

		CombatReplicator.Enable(humRP, Fx.Ab2Stun, SKILL_CONFIG.HealDuration) -- troque pelo VFX de buff que quiser

		buffThread = task.spawn(function()
			local elapsed = 0

			while elapsed < SKILL_CONFIG.HealDuration do
				task.wait(SKILL_CONFIG.HealTickRate)
				elapsed += SKILL_CONFIG.HealTickRate

				if not buffRunning then break end
				if humanoid.Health <= 0 then break end

				local heal = SKILL_CONFIG.HealPerTick
				humanoid.Health = math.min(humanoid.Health + heal, humanoid.MaxHealth)

				-- feedback visual de cura
				DamageIndicator(char, heal, Color3.new(0, 1, 0.4))
				CombatReplicator.Highlight(char, {Color = Color3.fromRGB(47, 255, 0), Duration = 0.5})

				local HealSFX = Sounds:FindFirstChild("Ability2"):Clone() -- troque pelo SFX de cura se houver
				HealSFX.Parent = char:FindFirstChild("Torso") or humRP
				HealSFX:Play()
				HealSFX.Ended:Connect(function() HealSFX:Destroy() end)
			end

			buffRunning = false
		end)
	end

	-- escuta o evento de marker da animação chamado "HealthBuff"
	local markerConn = SkillTrack:GetMarkerReachedSignal("HealthBuff"):Connect(function()
		RunHealthBuff()
		local HealSFX = Sounds:FindFirstChild("Ability2"):Clone() -- troque pelo SFX de cura se houver
		HealSFX.Parent = char:FindFirstChild("Torso") or humRP
		HealSFX:Play()
		HealSFX.Ended:Connect(function() HealSFX:Destroy() end)
		
		DamageIndicator(char, SKILL_CONFIG.HealPerTick, Color3.new(0, 1, 0.4))
		CombatReplicator.Highlight(char, {Color = Color3.fromRGB(47, 255, 0), Duration = 0.5})
	end)

	-- quando a animação terminar (naturalmente ou cancelada)
	SkillTrack.Stopped:Connect(function()
		markerConn:Disconnect()

		-- se o buff ainda NÃO foi ativado (animação cancelada antes do marker), não inicia
		if not buffActivated then
			buffRunning = false
		end

		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_INSKILL)
		StateManager.REMOVE(char, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED)
	end)
end

return module