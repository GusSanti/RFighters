local EffectsReplicator = {}
local EffectsReplicatorEvent = game.ReplicatedStorage.CombatSystem.Events.EffectsReplicatorEvent

function EffectsReplicator.Emit(TargetPart, Effect, options)
	-- options: {C0, C1, OnlyPosition, Orientation}
	EffectsReplicatorEvent:FireAllClients('Emit', TargetPart, Effect, nil, options)
end

function EffectsReplicator.Enable(TargetPart, Effect, Lifetime, options)
	-- options: {C0, C1, OnlyPosition, Orientation}
	EffectsReplicatorEvent:FireAllClients('Enable', TargetPart, Effect, Lifetime, options)
end

function EffectsReplicator.Highlight(TargetPart, options)
	EffectsReplicatorEvent:FireAllClients('HIGHLIGHT', TargetPart, nil, nil, options)
end

function EffectsReplicator.BodyPosition(TargetPart, options)
	-- options: { offset, duration, tweenInfo, maxForce, pValue, dValue }
	EffectsReplicatorEvent:FireAllClients('BODYPOSITION', TargetPart, nil, nil, options)
end

function EffectsReplicator.CameraShake(options)
	-- options: { magnitude, position, radius, duration, fadeIn, fadeOut }
	EffectsReplicatorEvent:FireAllClients('CAMERASHAKE', nil, nil, nil, options)
end

return EffectsReplicator