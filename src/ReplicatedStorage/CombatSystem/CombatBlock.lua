local CombatBlock = {}

local Debris = game:GetService("Debris")

local CombatServerRequests = game.ReplicatedStorage.CombatSystem.Events.ServerRequests

local CharacterManager = require(game.ReplicatedStorage.CombatSystem.CharacterManager)
local StateManager = require(game.ReplicatedStorage.StateManager.StateManager)
local StateManagerEnums = require(game.ReplicatedStorage.StateManager.ENUM)
local CombatReplicator = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local CombatFreeze = require(game.ReplicatedStorage.CombatSystem.CombatFreeze)
local PlayAnimation = require(game.ReplicatedStorage.CombatSystem.PlayAnimationServer)
local EffectsHelper = require(game.ReplicatedStorage.CombatSystem.EffectsHelper)

local SendStreakUpdate = game.ReplicatedStorage.Events:WaitForChild("UpdateStreakInfo")

function CombatBlock.EnableBlock(player)
	local CharacterStorageModule = CharacterManager.GetModule(player)
	if not CharacterStorageModule then return end
	
	local CanBlock = CombatServerRequests:Invoke('RequestCanBlock', {Player = player})
	
	if not CanBlock then return end
	
	local playedAnim = PlayAnimation.PlayCharacterAnimation(player.Character, CharacterStorageModule.Visuals.Animations.BasicInputs.BLOCK.Holding, nil, nil, Enum.AnimationPriority.Idle)
	
	CombatServerRequests:Invoke('SetBlockHolding', {Player = player})
	CombatServerRequests:Invoke('SetParryTimer', {Player = player, Timer = CharacterStorageModule.Logic.BasicInputs.BLOCK.CanParryTime})
	CombatServerRequests:Invoke('RegisterBlockHoldingAnimation', {Player = player, Animation = playedAnim})
end

function CombatBlock.DisableBlock(player)
	local CharacterStorageModule = CharacterManager.GetModule(player)
	if not CharacterStorageModule then return end
	
	CombatServerRequests:Invoke('RemoveBlockHolding', {Player = player})
	CombatServerRequests:Invoke('RemoveParryTimer', {Player = player})
	local HoldingAnim = CombatServerRequests:Invoke('GetBlockHoldingAnimation', {Player = player})
	
	if HoldingAnim then
		PlayAnimation.StopAnimation(player.Character, HoldingAnim)
	end
	
	CombatServerRequests:Invoke('RemoveBlockHoldingAnimation', {Player = player})
	CombatServerRequests:Invoke('AddBlockCooldown', {Player = player})
end

function CombatBlock.CheckAndApplyCombat(victimPlayer, attackerPlayer, HitDamage)
	local VictmimCharacter = victimPlayer.Character
	local AttackerCharacter = attackerPlayer.Character

	local CharacterStorageModule = CharacterManager.GetModule(victimPlayer)
	if not CharacterStorageModule then return end
	
	local CanParry = CombatServerRequests:Invoke('RequestCanParry', {Player = victimPlayer})
	local CanBlock = CombatServerRequests:Invoke('RequestCanBlockHit', {Player = victimPlayer})
	local WillBlockBreak = CombatServerRequests:Invoke('RequestWillBlockBreak', {Player = victimPlayer})

	if CharacterStorageModule then
		if CanParry then
			StateManager.POST_REMOVE(victimPlayer, StateManagerEnums.STATES_ENUM.COMBAT_IFRAME, CharacterStorageModule.Logic.BasicInputs.BLOCK.ParryIFrameTime)
			StateManager.POST_REMOVE(victimPlayer, StateManagerEnums.STATES_ENUM.COMBAT_BLOCKING, 0.66)

			EffectsHelper.PlayEffect(CharacterStorageModule.Visuals.Effects.BasicInputs.BLOCK.Parry, VictmimCharacter)
			EffectsHelper.PlaySound(CharacterStorageModule.Visuals.Sounds.BasicInputs.BLOCK.Parry, VictmimCharacter)
			CombatFreeze.Freeze(AttackerCharacter, 0.25)
			CombatReplicator.Highlight(VictmimCharacter, {Color = Color3.fromRGB(255, 255, 255), Duration = CharacterStorageModule.Logic.BasicInputs.BLOCK.ParryIFrameTime})
			PlayAnimation.PlayCharacterAnimation(VictmimCharacter, CharacterStorageModule.Visuals.Animations.BasicInputs.BLOCK.Parry)
			
			return true
		end
		
		if WillBlockBreak then
			-- remove blocking e iframe imediatamente
			StateManager.POST_REMOVE(victimPlayer, StateManagerEnums.STATES_ENUM.COMBAT_BLOCKING, 0)
			StateManager.POST_REMOVE(victimPlayer, StateManagerEnums.STATES_ENUM.COMBAT_IFRAME, 0)

			-- stun de 1.5s
			StateManager.POST_REMOVE(victimPlayer, StateManagerEnums.STATES_ENUM.COMBAT_FULL_STUNNED, 1.5)
			StateManager.POST_REMOVE(victimPlayer, StateManagerEnums.STATES_ENUM.COMBAT_BEING_ATTACKED, 1.5)

			-- efeito de break do storage do personagem
			EffectsHelper.PlayEffect(CharacterStorageModule.Visuals.Effects.BasicInputs.BLOCK.Break, VictmimCharacter)
			EffectsHelper.PlaySound(CharacterStorageModule.Visuals.Sounds.BasicInputs.BLOCK.Break, VictmimCharacter)

			CombatFreeze.Freeze(VictmimCharacter, 0.6)
			CombatReplicator.Highlight(VictmimCharacter, {
				Color = Color3.fromRGB(255, 50, 50),
				Duration = 0.8
			})
			PlayAnimation.PlayCharacterAnimation(
				VictmimCharacter,
				CharacterStorageModule.Visuals.Animations.BasicInputs.BLOCK.Break
			)
			
			CombatBlock.DisableBlock(victimPlayer)

			return false -- deixa o hit continuar normalmente (knockback, dano, etc.)
		end
	
		if CanBlock then
			StateManager.POST_REMOVE(victimPlayer, StateManagerEnums.STATES_ENUM.COMBAT_IFRAME, CharacterStorageModule.Logic.BasicInputs.BLOCK.IFrameTime)
			--StateManager.POST_REMOVE(victimPlayer, StateManagerEnums.STATES_ENUM.COMBAT_BLOCKING, 0.66)

			VictmimCharacter.Humanoid:TakeDamage(HitDamage - (HitDamage * CharacterStorageModule.Logic.BasicInputs.BLOCK.DefensePercentage / 100))
			CombatReplicator.Highlight(VictmimCharacter, {Color = Color3.fromRGB(255, 0, 0), Duration = 0.6})

			SendStreakUpdate:Fire(attackerPlayer)

			EffectsHelper.PlayEffect(CharacterStorageModule.Visuals.Effects.BasicInputs.BLOCK.Normal, VictmimCharacter)
			EffectsHelper.PlaySound(CharacterStorageModule.Visuals.Sounds.BasicInputs.BLOCK.Normal, VictmimCharacter)
			CombatFreeze.Freeze(AttackerCharacter, 0.25)
			CombatReplicator.Highlight(VictmimCharacter, {Color = Color3.fromRGB(255, 255, 255), Duration = CharacterStorageModule.Logic.BasicInputs.BLOCK.IFrameTime})
			PlayAnimation.PlayCharacterAnimation(VictmimCharacter, CharacterStorageModule.Visuals.Animations.BasicInputs.BLOCK.Normal)
			
			CombatServerRequests:Invoke('RegisterBlockHit', {Player = victimPlayer})	
			
			return true
		end

	end
	
	return false
end

return CombatBlock