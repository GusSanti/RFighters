local module = {}
local PlayAnimationEvent = game.ReplicatedStorage.CombatSystem.Events.PlayAnimation
local CombatReplicator = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local CombatUtils = require(game.ReplicatedStorage.CombatSystem.CombatUtils)
local function PlayExclusiveAnimation(humanoid, animation, isSmooth, priority)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	if not isSmooth then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			if track.Priority == Enum.AnimationPriority.Action
				or track.Priority == Enum.AnimationPriority.Action2
				or track.Priority == Enum.AnimationPriority.Action3
				or track.Priority == Enum.AnimationPriority.Action4 then
				track:Stop()
			end
		end
	end
	local track = animator:LoadAnimation(animation)
	track.Priority = priority or Enum.AnimationPriority.Action
	track:Play()
	return track
end
function module.StopAnimation(character, animation)
	if animation and animation:IsA('AnimationTrack') then
		if animation.IsPlaying then
			animation:Stop()
			CombatReplicator.Emit(character.HumanoidRootPart, game.ReplicatedStorage.CombatStorage.GlobalVFX.AnimationCancelPop)
			CombatReplicator.Highlight(character, {Color = Color3.fromRGB(255, 255, 255), Duration = 0.2})

			warn("PAROU ANIM COM HIGHLIGHT")
		end
		return
	end
	if animation and animation:IsA('Animation') then
		local player = game.Players:GetPlayerFromCharacter(character)
		if player then
			PlayAnimationEvent:FireClient(player, 'StopAnimation', animation)
		else
			local humanoid = character:FindFirstChildOfClass('Humanoid')
			local animator = humanoid and humanoid:FindFirstChildOfClass('Animator')
			if not animator then return end
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				if track.Animation and track.Animation.AnimationId == animation.AnimationId then
					track:Stop()
					warn("PAROU ANIM COM HIGHLIGHT MODEL")
					CombatReplicator.Emit(character.HumanoidRootPart, game.ReplicatedStorage.CombatStorage.GlobalVFX.AnimationCancelPop)
					CombatReplicator.Highlight(character, {Color = Color3.fromRGB(255, 255, 255), Duration = 0.2})
					break
				end
			end
		end
	end
end
function module.PlayCharacterAnimation(character, animation, stopdelay, IsSmooth, priority)
	local humanoid = character:FindFirstChild("Humanoid")
	local player = game.Players:GetPlayerFromCharacter(character)
	local track
	if typeof(animation) == 'table' then
		if animation.InAirAnimation and CombatUtils.IsCharacterInAir(character) then
			animation = animation.InAirAnimation
		elseif animation.OnGroundAnimation and not CombatUtils.IsCharacterInAir(character) then
			animation = animation.OnGroundAnimation
		else
			local resolved = nil
			for _, anim in animation do
				if typeof(anim) == 'Instance' and anim:IsA('Animation') then
					resolved = anim; break
				end
			end
			if not resolved then return end
			animation = resolved
		end
	end
	if not animation then return end
	if player then
		PlayAnimationEvent:FireClient(player, 'PlayAnimation', animation, stopdelay, IsSmooth, priority)
	else
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if not animator then return end
		track = PlayExclusiveAnimation(humanoid, animation, IsSmooth, priority)

		warn("PAROU a anim")
		if stopdelay and track then
			task.delay(math.max(tonumber(stopdelay) or 0, 0), function()
				if track and track.IsPlaying then
					track:Stop()
					CombatReplicator.Emit(character.HumanoidRootPart, game.ReplicatedStorage.CombatStorage.GlobalVFX.AnimationCancelPop)
					CombatReplicator.Highlight(character, {Color = Color3.fromRGB(255, 255, 255), Duration = 0.2})
				end
			end)
		end
	end
	return track or animation
end
return module