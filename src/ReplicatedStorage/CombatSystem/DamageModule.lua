local module = {}
local StateManager = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local GetRandomHitAnimation = require(game.ReplicatedStorage.CombatStorage.GetRandomHitAnimation)
local PlayAnimation = require(game.ReplicatedStorage.CombatSystem.PlayAnimationServer)
local CombatBlock = require(game.ReplicatedStorage.CombatSystem.CombatBlock)
local DeathConnectionEvent = game.ReplicatedStorage.CombatSystem.Events.DeathConnectionEvent
local ServerEvents = game.ReplicatedStorage.CombatSystem.Events.ServerEvents
local GetStreakInfo = game.ReplicatedStorage.Events.GetStreakInfo
local MatchSendStatBindableEvent = game.ReplicatedStorage.Events.Match.MatchSendStatBindableEvent
local RunService = game:GetService("RunService")

local MAX_MULTIPLIER = 2.5
local MAX_STREAK = 25

local function getStreakMultiplier(player)
	if not player then return 1 end
	local streak = GetStreakInfo:Invoke(player) or 0
	warn('STREAK DAMAGE MODULE = ', streak)
	local t = math.clamp(streak / MAX_STREAK, 0, 1)
	return 1 + (MAX_MULTIPLIER - 1) * t
end

function module.TakeDamage(character, damage, playHitAnim, attacker)
	if RunService:IsClient() then
		warn('Server Exclusive Module')
		return
	end

	local player = game.Players:GetPlayerFromCharacter(character)
	local attackerPlayer = game.Players:GetPlayerFromCharacter(attacker)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		warn('No Humanoid')
		return
	end

	-- Multiplier antes de qualquer checagem de estado
	local multiplier = getStreakMultiplier(attackerPlayer)
	warn(multiplier)
	local finalDamage = damage * multiplier

	if StateManager.GET(character)[StateManagerEnums.STATES_ENUM.COMBAT_DEFENSE_EFFECT] then
		finalDamage = finalDamage / 2
	end

	if finalDamage > humanoid.Health then
		humanoid.Health = 10
		DeathConnectionEvent:Fire(character)
	else
		humanoid:TakeDamage(finalDamage)
		MatchSendStatBindableEvent:Fire("Damage", attackerPlayer, player, finalDamage)
	end

	if player then CombatBlock.DisableBlock(player) end

	if playHitAnim and typeof(playHitAnim) == 'table' then
		PlayAnimation.PlayCharacterAnimation(character, GetRandomHitAnimation.GetRandom(), playHitAnim.StopDelay, true)
	end
end

return module