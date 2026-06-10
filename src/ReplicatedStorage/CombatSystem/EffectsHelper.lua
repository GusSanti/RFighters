local module = {}

local RunService = game:GetService('RunService')
local Debris = game:GetService('Debris')
local CombatReplicator = require(game.ReplicatedStorage.CombatSystem.EffectsReplicator)
local CombatReplicatorClient = require(game.ReplicatedStorage.CombatSystem.EffectsReplicatorClient)

local function PlayEffectServer(EffectsTable, Character, OnlyPos, Orientation, WeldPos)
	if EffectsTable then
		task.delay(EffectsTable.Delay, function()
			local c0 = WeldPos and WeldPos.C0
			local c1 = WeldPos and WeldPos.C1
			if EffectsTable.Type == 'Emit' then
				CombatReplicator.Emit(Character:FindFirstChild(EffectsTable.TargetCharacterBodyPart), EffectsTable.Effect, {OnlyPosition = OnlyPos, Orientation = Orientation, C0 = c0, C1 = c1})
			else
				CombatReplicator.Enable(Character:FindFirstChild(EffectsTable.TargetCharacterBodyPart), EffectsTable.Effect, EffectsTable.Lifetime, {OnlyPosition = OnlyPos, Orientation = Orientation, C0 = c0, C1 = c1})
			end
		end)
	end
end

local function PlaySoundServer(SoundTable, Character)
	if SoundTable then
		local NewSound = SoundTable.Sound:Clone()
		NewSound.Parent = Character:FindFirstChild(SoundTable.TargetCharacterBodyPart)
		NewSound.RollOffMode = Enum.RollOffMode.Linear
		NewSound.MaxDistance = 100 -- ou algo adequado pro seu jogo
		NewSound.MinDistance = 5
		NewSound:Play()
		NewSound.Ended:Connect(function()
			Debris:AddItem(NewSound)
		end)
	end
end

local function PlayEffectClient(EffectsTable, Character, OnlyPos, Orientation, WeldPos)
	if EffectsTable then
		task.delay(EffectsTable.Delay, function()
			local c0 = WeldPos and WeldPos.C0
			local c1 = WeldPos and WeldPos.C1
			if EffectsTable.Type == 'Emit' then
				CombatReplicatorClient.Emit(Character:FindFirstChild(EffectsTable.TargetCharacterBodyPart), EffectsTable.Effect, {OnlyPosition = OnlyPos, Orientation = Orientation, C0 = c0, C1 = c1})
			else
				CombatReplicatorClient.Enable(Character:FindFirstChild(EffectsTable.TargetCharacterBodyPart), EffectsTable.Effect, EffectsTable.Lifetime, {OnlyPosition = OnlyPos, Orientation = Orientation, C0 = c0, C1 = c1})
			end
		end)
	end
end

local function PlaySoundClient(SoundTable, Character)
	if SoundTable then
		local NewSound = SoundTable.Sound:Clone()
		NewSound.Parent = Character:FindFirstChild(SoundTable.TargetCharacterBodyPart)
		NewSound.RollOffMode = Enum.RollOffMode.Linear
		NewSound.MaxDistance = 100 -- ou algo adequado pro seu jogo
		NewSound.MinDistance = 5
		NewSound:Play()
		NewSound.Ended:Connect(function()
			Debris:AddItem(NewSound)
		end)
	end
end

function module.PlayEffect(EffectsTable, Character, OnlyPos, Orientation, WeldPos)
	if RunService:IsClient() then
		PlayEffectClient(EffectsTable, Character, OnlyPos, Orientation, WeldPos)
	else
		PlayEffectServer(EffectsTable, Character, OnlyPos, Orientation, WeldPos)
	end
end

function module.PlaySound(SoundTable, Character)
	if RunService:IsClient() then
		PlaySoundClient(SoundTable, Character)
	else
		PlaySoundServer(SoundTable, Character)
	end
end

return module