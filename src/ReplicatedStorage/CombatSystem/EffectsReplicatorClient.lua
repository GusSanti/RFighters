local EffectsReplicator = {}
local EffectsReplicatorEvent = game.ReplicatedStorage.CombatSystem.Events.ClientToServerEffect

function EffectsReplicator.Emit(TargetPart, Effect, options)
	-- options: {C0, C1, OnlyPosition, Orientation}
	EffectsReplicatorEvent:FireServer('Emit', TargetPart, Effect, nil, options)
end

function EffectsReplicator.Enable(TargetPart, Effect, Lifetime, options)
	-- options: {C0, C1, OnlyPosition, Orientation}
	EffectsReplicatorEvent:FireServer('Enable', TargetPart, Effect, Lifetime, options)
end

function EffectsReplicator.Highlight(TargetPart, options)
	EffectsReplicatorEvent:FireServer('HIGHLIGHT', TargetPart, nil, nil, options)
end

function EffectsReplicator.BodyPosition(TargetPart, options)
	-- options: { offset, duration, tweenInfo, maxForce, pValue, dValue }
	EffectsReplicatorEvent:FireServer('BODYPOSITION', TargetPart, nil, nil, options)
end

function EffectsReplicator.CameraShake(options)
	-- options: { magnitude, position, radius, duration, fadeIn, fadeOut }
	EffectsReplicatorEvent:FireServer('CAMERASHAKE', nil, nil, nil, options)
end

return EffectsReplicator