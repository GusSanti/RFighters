local module = {}

local FIGHT_RESET_CFRAME_NAME = "__FightResetCFrame"
local TEMPORARY_MOVER_NAMES = {
	["__FloatHold"] = true,
	["__KBTween"] = true,
	["__KnockbackPhysicsLock"] = true,
	["__SelfImpulseAttach"] = true,
	["__SelfImpulseLV"] = true,
}

local function forEachBasePart(character: Model, callback)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			callback(descendant)
		end
	end
end

function module.SetCharacterAnchored(character: Model, anchored: boolean)
	forEachBasePart(character, function(part)
		part.Anchored = anchored
	end)
end

function module.ZeroCharacterVelocity(character: Model)
	forEachBasePart(character, function(part)
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
	end)
end

function module.ClearTemporaryMovementControllers(character: Model)
	for _, descendant in ipairs(character:GetDescendants()) do
		if not TEMPORARY_MOVER_NAMES[descendant.Name] then
			continue
		end

		if descendant:IsA("Attachment")
			or descendant:IsA("BodyVelocity")
			or descendant:IsA("LinearVelocity")
			or descendant:IsA("BoolValue")
		then
			descendant:Destroy()
		end
	end
end

function module.StoreFightResetCFrame(character: Model, resetCFrame: CFrame)
	local cframeValue = character:FindFirstChild(FIGHT_RESET_CFRAME_NAME)
	if not cframeValue then
		cframeValue = Instance.new("CFrameValue")
		cframeValue.Name = FIGHT_RESET_CFRAME_NAME
		cframeValue.Parent = character
	end

	cframeValue.Value = resetCFrame
end

function module.GetStoredFightCFrame(character: Model, fallbackCFrame: CFrame)
	local cframeValue = character:FindFirstChild(FIGHT_RESET_CFRAME_NAME)
	if cframeValue and cframeValue:IsA("CFrameValue") then
		return cframeValue.Value
	end

	return fallbackCFrame
end

function module.ResetCharactersToFightPositions(
	character: Model,
	enemyCharacter: Model,
	jointWeld,
	characterCFrame: CFrame,
	enemyCFrame: CFrame
)
	module.SetCharacterAnchored(character, true)
	module.SetCharacterAnchored(enemyCharacter, true)
	module.ClearTemporaryMovementControllers(character)
	module.ClearTemporaryMovementControllers(enemyCharacter)
	module.ZeroCharacterVelocity(character)
	module.ZeroCharacterVelocity(enemyCharacter)
	
	character:PivotTo(characterCFrame)
	task.wait()
	if jointWeld and jointWeld.Parent then
		jointWeld:Destroy()
	end
	
	module.ClearTemporaryMovementControllers(character)
	module.ClearTemporaryMovementControllers(enemyCharacter)
	module.ZeroCharacterVelocity(character)
	module.ZeroCharacterVelocity(enemyCharacter)
	module.SetCharacterAnchored(character, false)
	module.SetCharacterAnchored(enemyCharacter, false)
	module.ZeroCharacterVelocity(character)
	module.ZeroCharacterVelocity(enemyCharacter)
end

return module
