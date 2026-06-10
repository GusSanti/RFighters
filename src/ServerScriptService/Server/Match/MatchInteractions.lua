local MatchInteractions = {}

--[[
	REFATORAÇÃO: suporte genérico a NvN (2v2, 3v3, 4v4, 5v5).

	Mudanças de round timer:
	- Cada round dura 90 segundos.
	- Ao expirar o timer, quem tiver mais HP ganha o round; o perdedor
	  "conta como morto" (DeathConnectionEvent é simulado via HandleRoundTimeout_*).
	- O timer é resetado para o próximo round (feito no MatchServer).
	- Offline mode usa 999s → sem timeout prático.

	CORREÇÃO: Semáforo anti-KO-duplo simultâneo adicionado em 1v1 e NvN.
	- No 1v1: variável `roundProcessing` impede que dois KOs no mesmo frame
	  acionem HandleRoundLoss duas vezes.
	- No NvN: variável `deathProcessing` complementa a checagem de PlayersAlive,
	  cobrindo o race condition antes de SetPlayerDead ser chamado.
]]

type Arena = {
	ID        : number,
	MatchType : string,
	MatchArgs : { any },
	Bounds    : Model,
	InUse     : boolean,
}

local Players        = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local RunService     = game:GetService("RunService")

local StateEnum             = require(game.ReplicatedStorage.StateManager.ENUM)
local StateManager          = require(game.ReplicatedStorage.StateManager.StateManager)
local PlayerState           = require(game.ReplicatedStorage.PlayerState.PlayerStateServer)
local MatchModule           = require(game.ReplicatedStorage.MatchSystem.MatchModule)
local CombatKnockback       = require(game.ReplicatedStorage.CombatSystem.CombatKnockback)
local UltimateCutsceneUtils = require(game.ServerStorage.SkillStorage.UltimateCutsceneUtils)
local QuestAchievementsModule = require(game.ReplicatedStorage.QuestAchievementsSystem.QuestAchievementsTriggerModule)
local QuestAchievementsEnum = require(game.ReplicatedStorage.QuestAchievementsSystem.TriggersEnum)

local ToggleMovementRemote        = game.ReplicatedStorage.Events.Movement.ToggleMovement
local MatchCameraConnectionRemote = game.ReplicatedStorage.Events.Match.MatchCameraConnection
local DeathConnectionEvent        = game.ReplicatedStorage.CombatSystem.Events.DeathConnectionEvent
local MatchMapsRemoteEvent        = game.ReplicatedStorage.Events.Match.MatchMapsRemoteEvent
local MatchUsedUltEvent           = game.ReplicatedStorage.Events.Match.MatchUsedUltimate
local MatchRemoteEvent            = game.ReplicatedStorage.Events.Match.MatchRemoteEvent
local MatchUIInteractions         = game.ReplicatedStorage.Events.Match.MatchUIInteractions
local ReturnToLobbyEvent          = game.ReplicatedStorage.Events.Match.MatchReturnToLobby
local GetCharacterPoolData        = game.ReplicatedStorage.Events.GetCharacterPoolData
local MatchSendStatBindableEvent  = game.ReplicatedStorage.Events.Match.MatchSendStatBindableEvent

-- ── Skins: BindableFunction para consultar a skin equipada ───────────────────
local GetEquippedSkinFunc = game.ReplicatedStorage:WaitForChild("Events"):WaitForChild("Skins"):WaitForChild("GetEquippedSkin")

local CharacterSwapEvent = game.ReplicatedStorage.Events:FindFirstChild("CharacterSwapped")
	or (function()
		local re = Instance.new("RemoteEvent")
		re.Name   = "CharacterSwapped"
		re.Parent = game.ReplicatedStorage.Events
		return re
	end)()

local MovementReadyRemote = game.ReplicatedStorage.Events.Movement:FindFirstChild("MovementReady")
	or (function()
		local rf = Instance.new("RemoteFunction")
		rf.Name   = "MovementReady"
		rf.Parent = game.ReplicatedStorage.Events.Movement
		return rf
	end)()

local ArenaBounds     = game.ReplicatedStorage.MatchSystem.Storage.MapBounds
local ArenaBoundsDojo = game.ReplicatedStorage.MatchSystem.Storage.MapBoundsDojo
local ArenaStorage    = {}

local CameraConnections = {}
local DeathConnections  = {}
local UltConnections    = {}

local BoundsConnections = {}
local BoundsStopped     = {}

local BOUNDS_CHECK_INTERVAL = 0.5
local BOUNDS_MARGIN         = 30

local ArenaContexts = {}

local FirstArenaPosition = Vector3.new(0, 3000, 0)
local lobbyPosition      = workspace.Lobby.SpawnLocation.Position

local GROUP_PLAYERS = "MatchPlayers"
local GROUP_BOTS    = "MatchBots"

local collisionGroupsReady = false

-- ============================================================
-- MATCH STATS
-- ============================================================
local MatchStats = {}  -- [player] = { damageDealt = 0, damageTaken = 0, roundsWon = 0 }

local function EnsureStats(player)
	if not MatchStats[player] then
		MatchStats[player] = { damageDealt = 0, damageTaken = 0, roundsWon = 0 }
	end
end

local function ClearStats(player)
	MatchStats[player] = nil
end

MatchSendStatBindableEvent.Event:Connect(function(statType, attackerPlayer, victimPlayer, amount)
	if statType ~= "Damage" then return end
	if attackerPlayer then
		EnsureStats(attackerPlayer)
		MatchStats[attackerPlayer].damageDealt += amount
	end
	if victimPlayer then
		EnsureStats(victimPlayer)
		MatchStats[victimPlayer].damageTaken += amount
	end
end)

-- ============================================================
-- ARENA ID / POSITION
-- ============================================================
local ArenaStudsOffset = 1000
local GridSize         = 5
local GridBlockOffset  = GridSize * ArenaStudsOffset
local GridBlockSize    = 5
local GridBlockOffset2 = GridBlockSize * GridBlockOffset
local nextArenaId      = 1

local function GetNextId(): number
	local id = nextArenaId
	nextArenaId += 1
	return id
end

local function CalculateArenaOffset(arenaId: number): Vector3
	local zeroId    = arenaId - 1
	local localSize = GridSize * GridSize
	local localIdx  = zeroId % localSize
	local blockIdx  = math.floor(zeroId / localSize)
	local localRow  = math.floor(localIdx / GridSize)
	local localCol  = localIdx % GridSize
	local blockRow  = math.floor(blockIdx / GridBlockSize)
	local blockCol  = blockIdx % GridBlockSize
	local x = blockCol * GridBlockOffset + localCol * ArenaStudsOffset
	local z = blockRow * GridBlockOffset + localRow * ArenaStudsOffset
	return Vector3.new(x, 0, z)
end

-- ============================================================
-- ANCHOR / UNANCHOR
-- ============================================================
local function AnchorCharacter(char: Model)
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.AssemblyLinearVelocity  = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function UnanchorCharacter(char: Model)
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
end

-- ============================================================
-- TELEPORT UNIFICADO
-- ============================================================
local function TeleportToArena(
	playerOrChar: Player | Model,
	arenaBounds: Model,
	offset: Vector3,
	onReady: (() -> ())?
)
	task.spawn(function()
		local char: Model?
		local player: Player?

		if playerOrChar:IsA("Player") then
			player = playerOrChar :: Player
			char   = player.Character
		else
			char = playerOrChar :: Model
		end

		if not char or not char.Parent then
			warn("[TeleportToArena] char ausente para " .. tostring(playerOrChar))
			if onReady then onReady() end
			return
		end

		local hrp = char:FindFirstChild("HumanoidRootPart")
			or char:WaitForChild("HumanoidRootPart", 5)

		if not hrp then
			warn("[TeleportToArena] HRP não encontrado")
			if onReady then onReady() end
			return
		end

		AnchorCharacter(char)

		local targetCFrame = arenaBounds:GetPivot() + offset
		UltimateCutsceneUtils.StoreFightResetCFrame(char, targetCFrame)
		char:PivotTo(targetCFrame)
		task.wait(0.15)

		local currentChar = player and player.Character or char
		if currentChar == char and char.Parent then
			char:PivotTo(targetCFrame)
		end

		task.wait(0.1)
		UnanchorCharacter(char)

		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.AssemblyLinearVelocity = Vector3.zero
				part.AssemblyAngularVelocity = Vector3.zero
			end
		end

		if onReady then onReady() end
	end)
end

-- ============================================================
-- SWAP CHARACTER
-- ============================================================
local swapSemaphore = {}

local function ResolveStarterModel(player: Player, activeCharId: string): Model?
	local combatChar = game.ReplicatedStorage.CombatStorage:FindFirstChild(activeCharId)
	if not combatChar then
		warn("[ResolveStarter] CombatStorage entry não encontrado: " .. activeCharId)
		return nil
	end

	local equippedModelName = "default"
	local ok, result = pcall(function()
		return GetEquippedSkinFunc:Invoke(player, activeCharId)
	end)
	if ok and type(result) == "string" then
		equippedModelName = result
	else
		warn("[ResolveStarter] Erro ao consultar GetEquippedSkin para " .. player.Name .. ": " .. tostring(result))
	end

	if equippedModelName ~= "default" then
		local skinModel = combatChar:FindFirstChild(equippedModelName)
		if skinModel and skinModel:IsA("Model") then
			print("[ResolveStarter] Usando skin '" .. equippedModelName .. "' para " .. player.Name)
			return skinModel
		else
			warn("[ResolveStarter] Skin model '" .. equippedModelName .. "' não encontrado em CombatStorage/" .. activeCharId .. " — usando StarterCharacter padrão.")
		end
	end

	local defaultModel = combatChar:FindFirstChild("StarterCharacter")
	if not defaultModel then
		warn("[ResolveStarter] StarterCharacter não encontrado em: " .. activeCharId)
	end
	return defaultModel
end

local function SwapCharacterForMatch(player: Player, onReady: (Model) -> ())
	if swapSemaphore[player] then
		local waited = 0
		while swapSemaphore[player] and waited < 8 do
			task.wait(0.05); waited += 0.05
		end
		if swapSemaphore[player] then
			warn("[SwapChar] Semáforo travado para " .. player.Name)
			onReady(player.Character)
			return
		end
	end

	swapSemaphore[player] = true

	task.spawn(function()
		local attempts = 0
		repeat task.wait(0.05); attempts += 1
		until PlayerState.IsPlayerDataReady(player) or attempts >= 60

		if not PlayerState.IsPlayerDataReady(player) then
			warn("[SwapChar] Timeout nos dados de " .. player.Name)
			swapSemaphore[player] = nil
			onReady(player.Character)
			return
		end

		local activeCharId = PlayerState.Get(player, "ActiveCharacter")
		if not activeCharId then
			warn("[SwapChar] Nenhum ActiveCharacter para " .. player.Name)
			swapSemaphore[player] = nil
			onReady(player.Character)
			return
		end

		local starterModel = ResolveStarterModel(player, activeCharId)
		if not starterModel then
			swapSemaphore[player] = nil
			onReady(player.Character)
			return
		end

		local newChar = starterModel:Clone()
		newChar.Name   = player.Name
		newChar.Parent = workspace

		local hrp      = newChar:FindFirstChild("HumanoidRootPart")
		local humanoid = newChar:FindFirstChildOfClass("Humanoid")

		if not hrp or not humanoid then
			warn("[SwapChar] HRP/Humanoid ausente em " .. player.Name)
			newChar:Destroy()
			swapSemaphore[player] = nil
			onReady(player.Character)
			return
		end

		AnchorCharacter(newChar)

		local oldChar = player.Character
		if oldChar then oldChar.Parent = nil end
		player.Character = newChar

		CharacterSwapEvent:FireClient(player, newChar)

		local stateReady = false
		local stateConn
		stateConn = humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.GettingUp
				or new == Enum.HumanoidStateType.Running
				or new == Enum.HumanoidStateType.RunningNoPhysics then
				stateReady = true
				stateConn:Disconnect()
			end
		end)

		local w = 0
		while not stateReady and w < 3 do task.wait(0.05); w += 0.05 end
		if stateConn then pcall(function() stateConn:Disconnect() end) end

		task.wait(0.1)
		if oldChar then oldChar:Destroy() end

		swapSemaphore[player] = nil
		print("[SwapChar] Pronto: " .. player.Name .. " → " .. activeCharId)
		onReady(newChar)
	end)
end

--------------------------------------

local function GiveCrystalReward(winner: Player)
	local base = 250
	local has2x = PlayerState.Get(winner, "Has2xCrystals")
	local isVip = PlayerState.Get(winner, "HasVIP")
	local amount
	if has2x then amount = base * 2
	elseif isVip then amount = math.floor(base * 1.2)
	else amount = base end
	PlayerState.Increment(winner, "Crystals", amount)
	warn(string.format("[CrystalReward] %s recebeu %d crystals (2x: %s | VIP: %s)", winner.Name, amount, tostring(has2x), tostring(isVip)))
end

local function GiveCrystalRewardLoser(winner: Player)
	local base = 150
	local has2x = PlayerState.Get(winner, "Has2xCrystals")
	local isVip = PlayerState.Get(winner, "HasVIP")
	local amount
	if has2x then amount = base * 2
	elseif isVip then amount = math.floor(base * 1.2)
	else amount = base end
	PlayerState.Increment(winner, "Crystals", amount)
	warn(string.format("[CrystalReward] %s recebeu %d crystals (2x: %s | VIP: %s)", winner.Name, amount, tostring(has2x), tostring(isVip)))
end

local function GiveDiamondsReward(winner: Player)
	local base = 150
	local has2x = PlayerState.Get(winner, "Has2xCrystals")
	local isVip = PlayerState.Get(winner, "HasVIP")
	local amount
	if has2x then amount = base * 2
	elseif isVip then amount = math.floor(base * 1.2)
	else amount = base end
	PlayerState.Increment(winner, "Diamonds", amount)
	warn(string.format("[CrystalReward] %s recebeu %d diamonds (2x: %s | VIP: %s)", winner.Name, amount, tostring(has2x), tostring(isVip)))
end

local function GiveDiamondsRewardLoser(winner: Player)
	local base = 75
	local has2x = PlayerState.Get(winner, "Has2xCrystals")
	local isVip = PlayerState.Get(winner, "HasVIP")
	local amount
	if has2x then amount = base * 2
	elseif isVip then amount = math.floor(base * 1.2)
	else amount = base end
	PlayerState.Increment(winner, "Diamonds", amount)
	warn(string.format("[CrystalReward] %s recebeu %d diamonds (2x: %s | VIP: %s)", winner.Name, amount, tostring(has2x), tostring(isVip)))
end

local function GiveRollRewards(winner: Player)
	local base = 3
	local has2x = PlayerState.Get(winner, "Has2xCrystals")
	local isVip = PlayerState.Get(winner, "HasVIP")
	local amount
	if has2x then amount = base * 2
	elseif isVip then amount = math.floor(base * 1.2)
	else amount = base end
	PlayerState.Increment(winner, "Rolls", amount)
	warn(string.format("[CrystalReward] %s recebeu %d rolls (2x: %s | VIP: %s)", winner.Name, amount, tostring(has2x), tostring(isVip)))
end

local function GiveRollRewardsLoser(winner: Player)
	local base = 1
	local has2x = PlayerState.Get(winner, "Has2xCrystals")
	local isVip = PlayerState.Get(winner, "HasVIP")
	local amount
	if has2x then amount = base * 2
	elseif isVip then amount = math.floor(base * 1.2)
	else amount = base end
	PlayerState.Increment(winner, "Rolls", amount)
	warn(string.format("[CrystalReward] %s recebeu %d rolls (2x: %s | VIP: %s)", winner.Name, amount, tostring(has2x), tostring(isVip)))
end

local function GiveXPReward(player: Player)
	local base = 200
	local has2x = PlayerState.Get(player, "Has2xXP")
	local isVip = PlayerState.Get(player, "HasVIP")
	local amount
	if has2x then amount = base * 2
	elseif isVip then amount = math.floor(base * 1.2)
	else amount = base end
	PlayerState.Increment(player, "Xp", amount)
	warn(string.format("[XPReward] %s recebeu %d XP (2x: %s | VIP: %s)", player.Name, amount, tostring(has2x), tostring(isVip)))
end

local function GiveXPRewardLoser(player: Player)
	local base = 100
	local has2x = PlayerState.Get(player, "Has2xXP")
	local isVip = PlayerState.Get(player, "HasVIP")
	local amount
	if has2x then amount = base * 2
	elseif isVip then amount = math.floor(base * 1.2)
	else amount = base end
	PlayerState.Increment(player, "Xp", amount)
	warn(string.format("[XPReward] %s recebeu %d XP (2x: %s | VIP: %s)", player.Name, amount, tostring(has2x), tostring(isVip)))
end

--------------------------------------

local function SwapCharacterBack(player: Player, onReady: ((Model) -> ())?)
	if swapSemaphore[player] then
		local waited = 0
		while swapSemaphore[player] and waited < 8 do
			task.wait(0.05); waited += 0.05
		end
		if swapSemaphore[player] then
			warn("[SwapBack] Semáforo travado para " .. player.Name)
			if onReady then onReady(player.Character) end
			return
		end
	end

	swapSemaphore[player] = true

	task.spawn(function()
		local newChar = nil
		local charConn
		charConn = player.CharacterAdded:Connect(function(c)
			newChar = c
			charConn:Disconnect()
		end)

		local ok, err = pcall(function() player:LoadCharacterAsync() end)
		if not ok then
			warn("[SwapBack] LoadCharacterAsync falhou: " .. tostring(err))
			charConn:Disconnect()
			swapSemaphore[player] = nil
			if onReady then onReady(player.Character) end
			return
		end

		local t = 0
		while not newChar and t < 8 do task.wait(0.05); t += 0.05 end

		if not newChar then
			warn("[SwapBack] CharacterAdded não disparou para " .. player.Name)
			swapSemaphore[player] = nil
			if onReady then onReady(player.Character) end
			return
		end

		local hrp = newChar:FindFirstChild("HumanoidRootPart")
			or newChar:WaitForChild("HumanoidRootPart", 5)
		if not hrp then warn("[SwapBack] HRP não apareceu para " .. player.Name) end

		swapSemaphore[player] = nil
		print("[SwapBack] Skin restaurada: " .. player.Name)
		if onReady then onReady(newChar) end
	end)
end

-- ============================================================
-- ENABLE MOVEMENT WITH HANDSHAKE
-- ============================================================
local function EnableMovementWithHandshake(player: Player, enemy: Model, maxAttempts: number?, retryDelay: number?)
	maxAttempts = maxAttempts or 5
	retryDelay  = retryDelay  or 0.8

	task.spawn(function()
		for attempt = 1, maxAttempts do
			if not player or not player.Parent then return end
			if not enemy  or not enemy.Parent  then return end

			local ok, result = pcall(function()
				return MovementReadyRemote:InvokeClient(player, "Enable", { Enemy = enemy })
			end)

			if ok and result == true then
				warn("[Handshake] OK para " .. player.Name .. " (tentativa " .. attempt .. ")")
				return
			end

			warn("[Handshake] Tentativa " .. attempt .. " falhou para " .. player.Name)
			task.wait(retryDelay)
		end

		warn("[Handshake] Fallback sem confirmação para " .. player.Name)
		if player and player.Parent and enemy and enemy.Parent then
			ToggleMovementRemote:FireClient(player, "Enable", { Enemy = enemy })
		end
	end)
end

-- ============================================================
-- BOUNDS
-- ============================================================
local function GetHRP(player: Player): BasePart?
	local char = player and player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function IsInsideBounds(pos: Vector3, arenaBoundsModel: Model): boolean
	local zone = arenaBoundsModel:FindFirstChild("BoundsZone")
	if not zone or not zone:IsA("BasePart") then
		warn("[BoundsCheck] BoundsZone não encontrada em " .. arenaBoundsModel.Name)
		return true
	end
	local localPos = zone.CFrame:PointToObjectSpace(pos)
	local half     = zone.Size / 2 + Vector3.new(BOUNDS_MARGIN, BOUNDS_MARGIN, BOUNDS_MARGIN)
	return  math.abs(localPos.X) <= half.X
		and math.abs(localPos.Y) <= half.Y
		and math.abs(localPos.Z) <= half.Z
end

local function GetRespawnCFrame(arenaBounds: Model): CFrame
	return arenaBounds:GetPivot() + Vector3.new(0, 5, 0)
end

local function GetSafeArenaReturnCFrame(char: Model, arenaBounds: Model): CFrame
	return UltimateCutsceneUtils.GetStoredFightCFrame(char, GetRespawnCFrame(arenaBounds))
end

local function ResetCharacterToArenaPoint(char: Model, arenaBounds: Model)
	if not char or not char.Parent then return end

	local safeCFrame = GetSafeArenaReturnCFrame(char, arenaBounds)
	UltimateCutsceneUtils.StoreFightResetCFrame(char, safeCFrame)
	AnchorCharacter(char)
	UltimateCutsceneUtils.ClearTemporaryMovementControllers(char)
	char:PivotTo(safeCFrame)
	task.wait(0.05)

	if char.Parent then
		char:PivotTo(safeCFrame)
		UltimateCutsceneUtils.ZeroCharacterVelocity(char)
		UnanchorCharacter(char)
		UltimateCutsceneUtils.ZeroCharacterVelocity(char)
	end
end

local function PushBackToArena(player: Player, arenaBounds: Model)
	local char = player and player.Character
	if not char or not char.Parent then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	warn(string.format("[BoundsCheck] %s saiu dos limites — teleportando de volta.", player.Name))
	ResetCharacterToArenaPoint(char, arenaBounds)
end

local function GetActiveFighters(arenaId: number): { Player }
	local fighters = {}
	local ctx = ArenaContexts[arenaId]
	if not ctx then return fighters end

	if ctx.OneVOne then
		for _, arena in pairs(ArenaStorage) do
			if arena.ID == arenaId then
				local args = arena.MatchArgs
				if args.Player1 and args.Player1.Parent then table.insert(fighters, args.Player1) end
				if args.Player2 and args.Player2.Parent then table.insert(fighters, args.Player2) end
				break
			end
		end
		return fighters
	end

	if ctx.NvN then
		local teamChars = ctx.NvN.teamChars
		local team1     = ctx.NvN.team1
		local team2     = ctx.NvN.team2
		for _, team in ipairs({ team1, team2 }) do
			local idx    = teamChars[team].activeIndex
			local player = team.Players[idx]
			if player and player.Parent then table.insert(fighters, player) end
		end
		return fighters
	end

	for _, arena in pairs(ArenaStorage) do
		if arena.ID == arenaId then
			local args = arena.MatchArgs
			if args.Player and args.Player.Parent then table.insert(fighters, args.Player) end
			break
		end
	end

	return fighters
end

-- ============================================================
-- COLLISION GROUPS
-- ============================================================
local function SetupCollisionGroups()
	if collisionGroupsReady then return end
	for _, g in ipairs({ GROUP_PLAYERS, GROUP_BOTS }) do
		pcall(function() PhysicsService:RegisterCollisionGroup(g) end)
	end
	PhysicsService:CollisionGroupSetCollidable(GROUP_PLAYERS, GROUP_PLAYERS, false)
	PhysicsService:CollisionGroupSetCollidable(GROUP_PLAYERS, GROUP_BOTS, false)
	PhysicsService:CollisionGroupSetCollidable(GROUP_BOTS, GROUP_BOTS, false)
	collisionGroupsReady = true
end

local function ApplyCollisionGroup(model: Model, groupName: string)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then part.CollisionGroup = groupName end
	end
	model.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then part.CollisionGroup = groupName end
	end)
end

-- ============================================================
-- CAMERA HELPERS
-- ============================================================
local function ConnectSpectateCamera(hostPlayer, spectatorPlayer)
	MatchCameraConnectionRemote:FireClient(hostPlayer,      'EnableHost')
	MatchCameraConnectionRemote:FireClient(spectatorPlayer, 'EnableSpectate')
	CameraConnections[spectatorPlayer] = MatchCameraConnectionRemote.OnServerEvent:Connect(function(plr, cameraCFrame)
		if plr == hostPlayer and cameraCFrame ~= nil then
			MatchCameraConnectionRemote:FireClient(spectatorPlayer, 'CameraConnection', cameraCFrame)
		end
	end)
end

local function DisconnectSpectateCamera(spectatorPlayer)
	MatchCameraConnectionRemote:FireClient(spectatorPlayer, 'DisableSpectate')
	if CameraConnections[spectatorPlayer] then
		CameraConnections[spectatorPlayer]:Disconnect()
		CameraConnections[spectatorPlayer] = nil
	end
end

local function DisconnectHostCamera(hostPlayer)
	MatchCameraConnectionRemote:FireClient(hostPlayer, 'DisableHost')
end

-- ============================================================
-- QUEST HELPER
-- ============================================================
local function HandleUseUlt(player, map)
	QuestAchievementsModule.Trigger(player, QuestAchievementsEnum.EnumList.CombatUsedUlt, { Map = map })
end

-- ============================================================
-- COMBAT HELPERS
-- ============================================================
local function KOPlayer(playerThatDied, opponent)
	StateManager.POST_REMOVE(playerThatDied, StateEnum.STATES_ENUM.COMBAT_FULL_STUNNED, 2)
	StateManager.POST_REMOVE(opponent,       StateEnum.STATES_ENUM.COMBAT_FULL_STUNNED, 2)

	CombatKnockback.ApplyKnockback({
		Profile = require(game.ServerStorage.CombatStorage.GlobalStorage.KnockbackProfiles).LauncherHeavy,
		KnockdownInfo = {
			Duration    = 1.5,
			InAirAnim   = game.ReplicatedStorage.CombatStorage.GlobalAnimations.airlow,
			FallAnim    = game.ReplicatedStorage.CombatStorage.GlobalAnimations.fall,
			WakeUpAnim  = game.ReplicatedStorage.CombatStorage.GlobalAnimations.wakeup,
		},
	}, playerThatDied.Character)

	MatchUIInteractions:FireClient(playerThatDied, 'KOEffect')
	MatchUIInteractions:FireClient(opponent,        'KOEffect')

	PlayerState.Increment(opponent, 'Wins', 1)
	PlayerState.Increment(opponent, 'Kills', 1)
	PlayerState.Increment(opponent, 'KillStreak', 1)
	PlayerState.Set(playerThatDied, 'KillStreak', 0)
end

local function RelockPlayer(player, enemyCharacter)
	ToggleMovementRemote:FireClient(player, "Disable")
	task.delay(0.1, function()
		ToggleMovementRemote:FireClient(player, "Enable", { Enemy = enemyCharacter })
	end)
end

-- ============================================================
-- HP COMPARISON HELPER
-- ============================================================
local function GetPlayerHP(player: Player): number
	local char = player and player.Character
	if not char then return 0 end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return 0 end
	return hum.Health
end

local function GetActivePlayerHP(team, teamChars): number
	local idx = teamChars[team].activeIndex
	local p = team.Players[idx]
	if not p then return 0 end
	return GetPlayerHP(p)
end

-- ============================================================
-- NvN TEAM HELPERS
-- ============================================================
local function GetAlivePlayers(team): { Player }
	local alive = {}
	for _, p in ipairs(team.Players) do
		if team.PlayersAlive[p] then table.insert(alive, p) end
	end
	return alive
end

local function SetPlayerDead(team, player)
	team.PlayersAlive[player] = false
	for i, p in ipairs(team.Players) do
		if p == player then
			team["Player" .. i .. "Alive"] = false
			break
		end
	end
end

local function InitAliveState(team)
	for _, p in ipairs(team.Players) do
		team.PlayersAlive[p] = true
		for i, pp in ipairs(team.Players) do
			if pp == p then team["Player" .. i .. "Alive"] = true end
		end
	end
end

local function FireAllPlayers(team1, team2, event, ...)
	local args = { ... }
	for _, team in ipairs({ team1, team2 }) do
		for _, p in ipairs(team.Players) do
			MatchRemoteEvent:FireClient(p, event, table.unpack(args))
		end
	end
end

local function FireAllPlayersUI(team1, team2, event, ...)
	local args = { ... }
	for _, team in ipairs({ team1, team2 }) do
		for _, p in ipairs(team.Players) do
			MatchUIInteractions:FireClient(p, event, table.unpack(args))
		end
	end
end

-- ============================================================
-- NvN FIGHT UI
-- ============================================================
local function UpdateFightUIForAll(fighter1: Model, fighter2: Model, teamA, teamB)
	task.delay(0.5, function()
		for _, p in ipairs(teamA.Players) do
			MatchUIInteractions:FireClient(p, 'Init', { Character1 = fighter1, Character2 = fighter2 })
		end
		for _, p in ipairs(teamB.Players) do
			MatchUIInteractions:FireClient(p, 'Init', { Character1 = fighter2, Character2 = fighter1 })
		end
	end)
end

local function StartNvNFight(
	activePlayerA: Player, charA: Model,
	activePlayerB: Player, charB: Model,
	teamA, teamB
)
	RelockPlayer(activePlayerA, charB)
	RelockPlayer(activePlayerB, charA)
	UpdateFightUIForAll(charA, charB, teamA, teamB)
end

-- ============================================================
-- NvN DEATH HANDLER
-- ============================================================
local function CreateNvNDeathHandler(arenaId, team1, team2, teamChars, arenaBounds, matchArgs)

	local deathProcessing = false

	local function GetActivePlayer(team)
		local idx = teamChars[team].activeIndex
		return team.Players[idx]
	end

	local function GetActiveChar(team): Model?
		local p = GetActivePlayer(team)
		return p and teamChars[team].chars[p]
	end

	local function GetNextPlayerIndex(team): number?
		for i = teamChars[team].activeIndex + 1, #team.Players do
			if team.PlayersAlive[team.Players[i]] then return i end
		end
		return nil
	end

	local function TriggerRoundQuests(winner, map)
		QuestAchievementsModule.Trigger(winner, QuestAchievementsEnum.EnumList.MatchWinRound2v2)
		QuestAchievementsModule.Trigger(winner, QuestAchievementsEnum.EnumList.CombatKillPlayer2v2)
	end

	local function TriggerMatchQuests(winner, map)
		QuestAchievementsModule.Trigger(winner, QuestAchievementsEnum.EnumList.MatchWinMatch2v2)
	end

	local function HandleDeath(deadPlayer, deadTeam, enemyTeam, byTimeout: boolean?)
		if not deadTeam.PlayersAlive[deadPlayer] then return end
		if deathProcessing then return end
		deathProcessing = true

		SetPlayerDead(deadTeam, deadPlayer)

		local currentActiveOfDead  = GetActivePlayer(deadTeam)
		local currentActiveOfEnemy = GetActivePlayer(enemyTeam)
		local currentCharOfEnemy   = GetActiveChar(enemyTeam)

		local nextIndex  = GetNextPlayerIndex(deadTeam)
		local nextPlayer = nextIndex and deadTeam.Players[nextIndex] or nil

		TriggerRoundQuests(currentActiveOfEnemy, matchArgs.Map)

		if not nextPlayer then
			KOPlayer(deadPlayer, currentActiveOfEnemy)
			TriggerMatchQuests(currentActiveOfEnemy, matchArgs.Map)

			for _, p in ipairs(enemyTeam.Players) do
				if p and p.Parent then
					GiveCrystalReward(p)
					GiveRollRewards(p)
					GiveXPReward(p)
					GiveDiamondsReward(p)
				end
			end

			for _, p in ipairs(deadTeam.Players) do
				if p and p.Parent then
					GiveCrystalRewardLoser(p)
					GiveRollRewardsLoser(p)
					GiveXPRewardLoser(p)
					GiveDiamondsRewardLoser(p)
				end
			end

			if DeathConnections[arenaId] then
				DeathConnections[arenaId]:Disconnect()
				DeathConnections[arenaId] = nil
			end

			task.delay(2.2, function()
				MatchModule.Stop2v2Match(team1, team2)
			end)
			return
		end

		KOPlayer(deadPlayer, currentActiveOfEnemy)

		DisconnectHostCamera(deadPlayer)
		DisconnectSpectateCamera(nextPlayer)

		ToggleMovementRemote:FireClient(deadPlayer, "Disable")

		local deadChar = deadPlayer.Character
		if deadChar and deadChar.Parent then
			task.spawn(function()
				deadChar:PivotTo(CFrame.new(lobbyPosition + Vector3.new(0, 9, 0)))
				local hum = deadChar:FindFirstChildOfClass("Humanoid")
				if hum then hum.Health = hum.MaxHealth end
			end)
		end

		FireAllPlayers(team1, team2, 'FadeIn')

		SwapCharacterForMatch(nextPlayer, function(newChar)
			teamChars[deadTeam].chars[nextPlayer] = newChar
			teamChars[deadTeam].activeIndex = nextIndex

			local deadSide  = (deadTeam == team1) and -1 or  1
			local enemySide = (deadTeam == team1) and  1 or -1

			TeleportToArena(nextPlayer,           arenaBounds, Vector3.new(deadSide  * 10, -30, 0))
			TeleportToArena(currentActiveOfEnemy, arenaBounds, Vector3.new(enemySide * 10, -30, 0))

			task.wait(0.6)

			if currentCharOfEnemy and currentCharOfEnemy:FindFirstChildOfClass("Humanoid") then
				local hum = currentCharOfEnemy:FindFirstChildOfClass("Humanoid")
				hum.Health = hum.MaxHealth
			end

			MatchModule.UpdateMatchTeamsCurrentRound(team1.Player1, team1.Player2)

			for _, p in ipairs(deadTeam.Players) do
				if p ~= nextPlayer and p.Parent then
					ConnectSpectateCamera(nextPlayer, p)
				end
			end

			FireAllPlayers(team1, team2, 'FadeOut')

			StartNvNFight(
				nextPlayer,           newChar,
				currentActiveOfEnemy, currentCharOfEnemy,
				deadTeam, enemyTeam
			)

			EnableMovementWithHandshake(nextPlayer,           currentCharOfEnemy)
			EnableMovementWithHandshake(currentActiveOfEnemy, newChar)

			StateManager.POST_REMOVE(nextPlayer,           StateEnum.STATES_ENUM.COMBAT_COUNTDOWN_STUNNED, 4)
			StateManager.POST_REMOVE(currentActiveOfEnemy, StateEnum.STATES_ENUM.COMBAT_COUNTDOWN_STUNNED, 4)

			local currentRound
			for _, matchTeams in pairs(MatchModule.GetInMatchTeams()) do
				if matchTeams.Team1.Player1 == team1.Player1 then
					currentRound = matchTeams.CurrentRound
					break
				end
			end

			for _, p in ipairs(deadTeam.Players) do
				if p.Parent then MatchUIInteractions:FireClient(p, 'StartRoundCountdown', currentRound) end
			end
			for _, p in ipairs(enemyTeam.Players) do
				if p.Parent then MatchUIInteractions:FireClient(p, 'StartRoundCountdown', currentRound) end
			end

			task.delay(4, function()
				MatchModule.ResetMatchTimerTeams(team1, team2)
				MatchModule.SetMatchReady(team1.Players[1])
				deathProcessing = false
			end)
		end)
	end

	ArenaContexts[arenaId] = ArenaContexts[arenaId] or {}
	ArenaContexts[arenaId].NvN = {
		team1       = team1,
		team2       = team2,
		teamChars   = teamChars,
		HandleDeath = HandleDeath,
	}

	return DeathConnectionEvent.Event:Connect(function(character)
		local deadPlayer = game.Players:GetPlayerFromCharacter(character)
		if not deadPlayer then return end

		local deadTeam, enemyTeam
		for _, p in ipairs(team1.Players) do
			if p == deadPlayer then deadTeam = team1; enemyTeam = team2; break end
		end
		if not deadTeam then
			for _, p in ipairs(team2.Players) do
				if p == deadPlayer then deadTeam = team2; enemyTeam = team1; break end
			end
		end
		if not deadTeam then return end

		HandleDeath(deadPlayer, deadTeam, enemyTeam, false)
	end)
end

-- ============================================================
-- ROUND TIMEOUT HANDLERS
-- ============================================================
function MatchInteractions.HandleRoundTimeout_1v1(player1, player2, arenaID)
	if not player1 or not player2 then return end
	if not player1.Parent or not player2.Parent then return end

	local ctx = ArenaContexts[arenaID] and ArenaContexts[arenaID].OneVOne
	if not ctx then
		warn("[Timeout 1v1] Contexto não encontrado para arena " .. tostring(arenaID))
		return
	end

	local hp1 = GetPlayerHP(player1)
	local hp2 = GetPlayerHP(player2)

	local loser, winner
	if hp1 >= hp2 then loser = player2; winner = player1
	else loser = player1; winner = player2 end

	warn(string.format("[Timeout 1v1] %s venceu o round por tempo (%.1f HP vs %.1f HP)", winner.Name, GetPlayerHP(winner), GetPlayerHP(loser)))

	ctx.HandleRoundLoss(loser, winner)
end

function MatchInteractions.HandleRoundTimeout_NvN(team1, team2, arenaID)
	local ctx = ArenaContexts[arenaID] and ArenaContexts[arenaID].NvN
	if not ctx then
		warn("[Timeout NvN] Contexto não encontrado para arena " .. tostring(arenaID))
		return
	end

	local teamChars = ctx.teamChars
	local idx1      = teamChars[team1].activeIndex
	local idx2      = teamChars[team2].activeIndex
	local fighter1  = team1.Players[idx1]
	local fighter2  = team2.Players[idx2]

	if not fighter1 or not fighter2 then return end

	local hp1 = GetPlayerHP(fighter1)
	local hp2 = GetPlayerHP(fighter2)

	local loserPlayer, loserTeam, winnerTeam
	if hp1 >= hp2 then loserPlayer = fighter2; loserTeam = team2; winnerTeam = team1
	else loserPlayer = fighter1; loserTeam = team1; winnerTeam = team2 end

	local winnerPlayer = (loserTeam == team1) and team2.Players[teamChars[team2].activeIndex]
		or team1.Players[teamChars[team1].activeIndex]

	warn(string.format("[Timeout NvN] %s venceu o round por tempo (%.1f HP vs %.1f HP)", winnerPlayer.Name, GetPlayerHP(winnerPlayer), GetPlayerHP(loserPlayer)))

	ctx.HandleDeath(loserPlayer, loserTeam, winnerTeam, true)
end

-- ============================================================
-- CREATE ARENA
-- ============================================================
local function CreateArena(arenaId: number, MatchType: string, MatchArgs: { any })
	SetupCollisionGroups()

	local newArena: Arena = {
		ID        = arenaId,
		MatchType = MatchType,
		MatchArgs = MatchArgs,
		InUse     = true,
	}

	if MatchArgs.Map and MatchArgs.Map.Name == 'Map_Dojo' then
		newArena.Bounds = ArenaBoundsDojo:Clone()
	else
		newArena.Bounds = ArenaBounds:Clone()
	end

	newArena.Bounds.Parent = workspace.Map
	newArena.Bounds.Name   = tostring(arenaId)
	newArena.Bounds:PivotTo(CFrame.new(FirstArenaPosition + CalculateArenaOffset(newArena.ID)))

	ArenaContexts[arenaId] = {}

	-- ============================================================
	-- OFFLINE 1v1
	-- ============================================================
	if MatchType == 'Offline1v1' then
		local player = MatchArgs.Player

		MatchRemoteEvent:FireClient(player, 'FadeIn')

		SwapCharacterForMatch(player, function(chr)
			local offlineBot = game.ReplicatedStorage.MatchSystem.Storage.OfflineBot:Clone()
			offlineBot.Parent = workspace

			local humanoid       = offlineBot:WaitForChild("Humanoid")
			local lastDamageTime = os.clock()
			local lastHealth     = humanoid.Health

			local damageConnection
			damageConnection = humanoid.HealthChanged:Connect(function(newHealth)
				if newHealth < lastHealth then lastDamageTime = os.clock() end
				lastHealth = newHealth
				if newHealth < 100 then humanoid.Health = 100 end
			end)

			local regenConnection
			regenConnection = RunService.Heartbeat:Connect(function(dt)
				if not offlineBot or not offlineBot.Parent or humanoid.Health <= 0 then
					if damageConnection then damageConnection:Disconnect() end
					if regenConnection  then regenConnection:Disconnect()  end
					return
				end
				if os.clock() - lastDamageTime >= 2 then
					humanoid.Health = math.min(humanoid.Health + 100 * dt, humanoid.MaxHealth)
				end
			end)

			local returnConnection
			returnConnection = ReturnToLobbyEvent.OnServerEvent:Connect(function(plr)
				if plr ~= player then return end
				MatchRemoteEvent:FireClient(player, 'DisableBackToLobbyButton')
				MatchModule.Stop1v1Match(player, nil)
				if returnConnection then returnConnection:Disconnect() end
			end)

			TeleportToArena(chr,        newArena.Bounds, Vector3.new(0,  -30, 0))
			TeleportToArena(offlineBot, newArena.Bounds, Vector3.new(20, -30, 0))

			local LockToggle = Instance.new('BoolValue')
			LockToggle.Parent = offlineBot
			LockToggle.Name   = 'LockToggle'
			LockToggle.Value  = true

			task.spawn(function()
				while chr and chr.Parent and offlineBot and offlineBot.Parent do
					if not LockToggle.Value then task.wait(0.025); continue end
					local pos       = offlineBot.HumanoidRootPart.Position
					local targetPos = chr.HumanoidRootPart.Position
					local dir = (targetPos.X > pos.X) and 1 or -1
					offlineBot.HumanoidRootPart.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(90 * -dir), 0)
					task.wait(0.025)
				end
			end)

			task.spawn(function()
				local elapsed = 0
				while offlineBot and offlineBot.Parent and chr and chr.Parent do
					elapsed += task.wait()
					if elapsed < BOUNDS_CHECK_INTERVAL then continue end
					elapsed = 0
					local hrp = offlineBot:FindFirstChild("HumanoidRootPart")
					if hrp and not IsInsideBounds(hrp.Position, newArena.Bounds) then
						warn("[BoundsCheck] OfflineBot saiu dos limites — teleportando de volta.")
						ResetCharacterToArenaPoint(offlineBot, newArena.Bounds)
					end
				end
			end)

			ApplyCollisionGroup(chr,        GROUP_PLAYERS)
			ApplyCollisionGroup(offlineBot, GROUP_BOTS)

			player.CharacterAdded:Connect(function(newChr)
				task.defer(function() ApplyCollisionGroup(newChr, GROUP_PLAYERS) end)
			end)

			local TargetCFrame = newArena.Bounds.PrimaryPart or newArena.Bounds:FindFirstChildWhichIsA('Part')
			MatchMapsRemoteEvent:FireClient(player, "CloneMap", { Map = MatchArgs.Map, TargetCFrame = TargetCFrame.CFrame })
			MatchRemoteEvent:FireClient(player, 'DisableHUD')
			MatchRemoteEvent:FireClient(player, 'EnableFightingFrame')
			MatchRemoteEvent:FireClient(player, 'DisableMapUI')

			task.delay(0.5, function()
				MatchUIInteractions:FireClient(player, 'Init', { Character1 = chr, Character2 = offlineBot })
			end)
			MatchRemoteEvent:FireClient(player, 'FadeOut')

			EnableMovementWithHandshake(player, offlineBot)

			StateManager.POST_REMOVE(player, StateEnum.STATES_ENUM.COMBAT_COUNTDOWN_STUNNED, 4)
			MatchUIInteractions:FireClient(player, 'StartCountdown')

			task.delay(4, function() MatchModule.SetMatchReady(player) end)

			task.delay(4.5, function()
				MatchInteractions.StartBoundsCheck(newArena.ID)
				MatchRemoteEvent:FireClient(player, 'EnableBackToLobbyButton')
			end)
		end)

		-- ============================================================
		-- ONLINE 1v1
		-- ============================================================
	elseif MatchType == 'Online1v1' then
		warn('1V1 ONLINE MATCH STARTED')
		task.spawn(function()
			local p1 = MatchArgs.Player1
			local p2 = MatchArgs.Player2

			local hasStarted = false
			local p1Ready    = false
			local p2Ready    = false
			local Timer      = 30
			local ButtonConnection

			local chrp1      = PlayerState.Get(p1, 'ActiveCharacter')
			local charDatap1 = GetCharacterPoolData:Invoke(chrp1)
			local chrp2      = PlayerState.Get(p2, 'ActiveCharacter')
			local charDatap2 = GetCharacterPoolData:Invoke(chrp2)

			MatchRemoteEvent:FireClient(p1, 'DisableHUD')
			MatchRemoteEvent:FireClient(p2, 'DisableHUD')
			MatchRemoteEvent:FireClient(p1, 'EnableCharacterSelection')
			MatchRemoteEvent:FireClient(p2, 'EnableCharacterSelection')
			MatchRemoteEvent:FireClient(p1, 'UpdateCharacterSelectionPlayerState', { Player = 'Player1', State = p1Ready })
			MatchRemoteEvent:FireClient(p2, 'UpdateCharacterSelectionPlayerState', { Player = 'Player2', State = p1Ready })
			MatchRemoteEvent:FireClient(p1, 'UpdateCharacterSelectionPlayerState', { Player = 'Player2', State = p2Ready })
			MatchRemoteEvent:FireClient(p2, 'UpdateCharacterSelectionPlayerState', { Player = 'Player1', State = p2Ready })
			MatchRemoteEvent:FireClient(p1, 'UpdatePlayerDescription', { Player = 'Player1', Data = charDatap1 })
			MatchRemoteEvent:FireClient(p2, 'UpdatePlayerDescription', { Player = 'Player2', Data = charDatap1, Enemy = p1 })
			MatchRemoteEvent:FireClient(p1, 'UpdatePlayerDescription', { Player = 'Player2', Data = charDatap2, Enemy = p2 })
			MatchRemoteEvent:FireClient(p2, 'UpdatePlayerDescription', { Player = 'Player1', Data = charDatap2 })

			ButtonConnection = MatchRemoteEvent.OnServerEvent:Connect(function(plr, action)
				if plr ~= p1 and plr ~= p2 then return end
				if action == 'SetReadyState' then
					if plr == p1 then
						p1Ready = not p1Ready
						MatchRemoteEvent:FireClient(p1, 'UpdateCharacterSelectionPlayerState', { Player = 'Player1', State = p1Ready })
						MatchRemoteEvent:FireClient(p2, 'UpdateCharacterSelectionPlayerState', { Player = 'Player2', State = p1Ready })
					elseif plr == p2 then
						p2Ready = not p2Ready
						MatchRemoteEvent:FireClient(p1, 'UpdateCharacterSelectionPlayerState', { Player = 'Player2', State = p2Ready })
						MatchRemoteEvent:FireClient(p2, 'UpdateCharacterSelectionPlayerState', { Player = 'Player1', State = p2Ready })
					end
				end
			end)

			while not hasStarted do
				task.wait(1)
				Timer -= 1
				if Timer <= 0 then hasStarted = true end
				if p1Ready and p2Ready and Timer > 5 then Timer = 5 end
				MatchRemoteEvent:FireClient(p1, 'UpdateCharacterSelectionTimer', { NewTime = Timer })
				MatchRemoteEvent:FireClient(p2, 'UpdateCharacterSelectionTimer', { NewTime = Timer })
			end

			if ButtonConnection then ButtonConnection:Disconnect(); ButtonConnection = nil end

			MatchRemoteEvent:FireClient(p1, 'DisableCharacterSelection')
			MatchRemoteEvent:FireClient(p2, 'DisableCharacterSelection')
			MatchRemoteEvent:FireClient(p1, 'FadeIn')
			MatchRemoteEvent:FireClient(p2, 'FadeIn')

			SwapCharacterForMatch(p1, function(chr1)
				SwapCharacterForMatch(p2, function(chr2)
					TeleportToArena(p1, newArena.Bounds, Vector3.new(-10, -30, 0))
					TeleportToArena(p2, newArena.Bounds, Vector3.new( 10, -30, 0))

					ApplyCollisionGroup(chr1, GROUP_PLAYERS)
					ApplyCollisionGroup(chr2, GROUP_PLAYERS)

					task.wait(0.6)

					for _, p in ipairs({ p1, p2 }) do
						p.CharacterAdded:Connect(function(newChr)
							task.defer(function() ApplyCollisionGroup(newChr, GROUP_PLAYERS) end)
						end)
					end

					local TargetCFrame = newArena.Bounds.PrimaryPart or newArena.Bounds:FindFirstChildWhichIsA('Part')
					MatchMapsRemoteEvent:FireClient(p1, "CloneMap", { Map = MatchArgs.Map, TargetCFrame = TargetCFrame.CFrame })
					MatchRemoteEvent:FireClient(p1, 'EnableFightingFrame')
					task.delay(0.5, function() MatchUIInteractions:FireClient(p1, 'Init', { Character1 = p1.Character, Character2 = p2.Character }) end)
					MatchMapsRemoteEvent:FireClient(p2, "CloneMap", { Map = MatchArgs.Map, TargetCFrame = TargetCFrame.CFrame })
					MatchRemoteEvent:FireClient(p2, 'EnableFightingFrame')
					task.delay(0.5, function() MatchUIInteractions:FireClient(p2, 'Init', { Character1 = p2.Character, Character2 = p1.Character }) end)

					EnableMovementWithHandshake(p1, p2.Character)
					EnableMovementWithHandshake(p2, p1.Character)

					UltConnections[p1] = MatchUsedUltEvent.Event:Connect(function(player)
						if player == p1 then HandleUseUlt(player, MatchArgs.Map) end
					end)
					UltConnections[p2] = MatchUsedUltEvent.Event:Connect(function(player)
						if player == p2 then HandleUseUlt(player, MatchArgs.Map) end
					end)

					StateManager.POST_REMOVE(p1, StateEnum.STATES_ENUM.COMBAT_COUNTDOWN_STUNNED, 4)
					MatchUIInteractions:FireClient(p1, 'StartCountdown')
					StateManager.POST_REMOVE(p2, StateEnum.STATES_ENUM.COMBAT_COUNTDOWN_STUNNED, 4)
					MatchUIInteractions:FireClient(p2, 'StartCountdown')

					MatchRemoteEvent:FireClient(p1, 'FadeOut')
					MatchRemoteEvent:FireClient(p2, 'FadeOut')

					task.delay(4, function() MatchModule.SetMatchReady(p1) end)

					task.delay(4.5, function()
						MatchInteractions.StartBoundsCheck(newArena.ID)
					end)

					local lives           = { [p1] = 2, [p2] = 2 }
					local wins            = { [p1] = 0, [p2] = 0 }
					local currentRound    = 1
					local roundProcessing = false

					local function HandleRoundLoss(loser, winner)
						if roundProcessing then return end
						roundProcessing = true

						lives[loser]  -= 1
						wins[winner]  += 1

						EnsureStats(winner)
						MatchStats[winner].roundsWon += 1

						local winRound = wins[winner]

						QuestAchievementsModule.Trigger(winner, QuestAchievementsEnum.EnumList.MatchWinRound1v1, { Map = MatchArgs.Map })
						QuestAchievementsModule.Trigger(winner, QuestAchievementsEnum.EnumList.CombatKillPlayer1v1, { Map = MatchArgs.Map })

						MatchUIInteractions:FireClient(winner, 'UpdatePlayer1RoundWin', { Round = winRound, Won = true })
						MatchUIInteractions:FireClient(loser,  'UpdatePlayer2RoundWin', { Round = winRound, Won = true })

						if lives[loser] <= 0 then
							KOPlayer(loser, winner)
							QuestAchievementsModule.Trigger(winner, QuestAchievementsEnum.EnumList.MatchWinMatch1v1, { Map = MatchArgs.Map })
							GiveCrystalReward(winner)
							GiveDiamondsReward(winner)
							GiveRollRewards(winner)
							GiveXPReward(winner)

							GiveCrystalRewardLoser(loser)
							GiveDiamondsRewardLoser(loser)
							GiveRollRewardsLoser(loser)
							GiveXPRewardLoser(loser)

							task.delay(2, function()
								local winnerStats = MatchStats[winner] or { damageDealt = 0, damageTaken = 0, roundsWon = 0 }
								local loserStats  = MatchStats[loser]  or { damageDealt = 0, damageTaken = 0, roundsWon = 0 }

								-- chrp1/chrp2 foram capturados no início do Online1v1
								-- winner/loser determinam qual char string vai pra cada slot
								local winnerChar = (winner == p1) and chrp1 or chrp2
								local loserChar  = (loser  == p1) and chrp1 or chrp2

								MatchRemoteEvent:FireClient(winner, 'ShowWinnerScreen', {
									PlayerWinner = winner,
									PlayerLoser  = loser,
									WinnerStats  = winnerStats,
									LoserStats   = loserStats,
									WinnerChar   = winnerChar,
									LoserChar    = loserChar,
								})
								MatchRemoteEvent:FireClient(loser, 'ShowWinnerScreen', {
									PlayerWinner = winner,
									PlayerLoser  = loser,
									WinnerStats  = winnerStats,
									LoserStats   = loserStats,
									WinnerChar   = winnerChar,
									LoserChar    = loserChar,
								})
							end)

							if DeathConnections[arenaId] then
								DeathConnections[arenaId]:Disconnect()
								DeathConnections[arenaId] = nil
							end

							task.delay(2.2, function() MatchModule.Stop1v1Match(p1, p2) end)
						else
							KOPlayer(loser, winner)
							MatchRemoteEvent:FireClient(p1, 'FadeIn')
							MatchRemoteEvent:FireClient(p2, 'FadeIn')

							task.spawn(function()
								task.wait(2.2)

								currentRound += 1

								local newDeadChr     = loser.Character
								local newOpponentChr = winner.Character

								if newDeadChr     then TeleportToArena(newDeadChr,     newArena.Bounds, Vector3.new(-10, -30, 0)) end
								if newOpponentChr then TeleportToArena(newOpponentChr, newArena.Bounds, Vector3.new( 10, -30, 0)) end

								task.wait(0.3)

								if newDeadChr and newDeadChr:FindFirstChildOfClass("Humanoid") then
									newDeadChr:FindFirstChildOfClass("Humanoid").Health = newDeadChr:FindFirstChildOfClass("Humanoid").MaxHealth
								end
								if newOpponentChr and newOpponentChr:FindFirstChildOfClass("Humanoid") then
									newOpponentChr:FindFirstChildOfClass("Humanoid").Health = newOpponentChr:FindFirstChildOfClass("Humanoid").MaxHealth
								end

								StateManager.POST_REMOVE(p1, StateEnum.STATES_ENUM.COMBAT_COUNTDOWN_STUNNED, 4)
								StateManager.POST_REMOVE(p2, StateEnum.STATES_ENUM.COMBAT_COUNTDOWN_STUNNED, 4)
								MatchUIInteractions:FireClient(p1, 'StartRoundCountdown', currentRound)
								MatchUIInteractions:FireClient(p2, 'StartRoundCountdown', currentRound)

								MatchModule.ResetMatchTimerPlayers(p1, p2)
								task.delay(4, function()
									MatchModule.SetMatchReady(p1)
									roundProcessing = false
								end)

								MatchRemoteEvent:FireClient(p1, 'FadeOut')
								MatchRemoteEvent:FireClient(p2, 'FadeOut')
							end)
						end
					end

					ArenaContexts[arenaId].OneVOne = {
						HandleRoundLoss = HandleRoundLoss,
					}

					DeathConnections[arenaId] = DeathConnectionEvent.Event:Connect(function(character)
						local deadPlayer = game.Players:GetPlayerFromCharacter(character)
						if not deadPlayer then return end
						if deadPlayer ~= p1 and deadPlayer ~= p2 then return end
						local opponent = (deadPlayer == p1) and p2 or p1
						HandleRoundLoss(deadPlayer, opponent)
					end)
				end)
			end)
		end)

		-- ============================================================
		-- ONLINE NvN  (2v2, 3v3, 4v4, 5v5)
		-- ============================================================
	elseif MatchType == 'Online2v2'
		or MatchType == 'Online3v3'
		or MatchType == 'Online4v4'
		or MatchType == 'Online5v5'
	then
		print('ONLINE NvN: ' .. MatchType)

		local team1 = MatchArgs.Team1
		local team2 = MatchArgs.Team2

		InitAliveState(team1)
		InitAliveState(team2)

		FireAllPlayers(team1, team2, 'FadeIn')

		SwapCharacterForMatch(team1.Players[1], function(Team1ActiveChar)
			SwapCharacterForMatch(team2.Players[1], function(Team2ActiveChar)

				local teamChars = {
					[team1] = {
						activeIndex = 1,
						chars = { [team1.Players[1]] = Team1ActiveChar },
					},
					[team2] = {
						activeIndex = 1,
						chars = { [team2.Players[1]] = Team2ActiveChar },
					},
				}

				for _, team in ipairs({ team1, team2 }) do
					for i = 2, #team.Players do
						local p = team.Players[i]
						teamChars[team].chars[p] = p.Character or p.CharacterAdded:Wait()
					end
				end

				local TargetCFrame = newArena.Bounds.PrimaryPart
					or newArena.Bounds:FindFirstChildWhichIsA('Part')

				TeleportToArena(team1.Players[1], newArena.Bounds, Vector3.new(-10, -30, 0))
				TeleportToArena(team2.Players[1], newArena.Bounds, Vector3.new( 10, -30, 0))

				task.wait(0.6)

				for _, team in ipairs({ team1, team2 }) do
					local activePlayer = team.Players[1]
					for i = 2, #team.Players do
						ConnectSpectateCamera(activePlayer, team.Players[i])
					end
				end

				ApplyCollisionGroup(Team1ActiveChar, GROUP_PLAYERS)
				ApplyCollisionGroup(Team2ActiveChar, GROUP_PLAYERS)

				for _, team in ipairs({ team1, team2 }) do
					for _, p in ipairs(team.Players) do
						p.CharacterAdded:Connect(function(newChr)
							task.defer(function() ApplyCollisionGroup(newChr, GROUP_PLAYERS) end)
						end)
					end
				end

				for _, team in ipairs({ team1, team2 }) do
					for _, p in ipairs(team.Players) do
						MatchRemoteEvent:FireClient(p, 'DisableHUD')
						MatchRemoteEvent:FireClient(p, 'EnableFightingFrame')
						MatchRemoteEvent:FireClient(p, 'DisableQueue2v2')
						MatchMapsRemoteEvent:FireClient(p, "CloneMap", { Map = MatchArgs.Map, TargetCFrame = TargetCFrame.CFrame })
						StateManager.POST_REMOVE(p, StateEnum.STATES_ENUM.COMBAT_COUNTDOWN_STUNNED, 4)
						MatchUIInteractions:FireClient(p, 'StartCountdown')
					end
				end

				UpdateFightUIForAll(Team1ActiveChar, Team2ActiveChar, team1, team2)

				EnableMovementWithHandshake(team1.Players[1], Team2ActiveChar)
				EnableMovementWithHandshake(team2.Players[1], Team1ActiveChar)

				for _, team in ipairs({ team1, team2 }) do
					for _, p in ipairs(team.Players) do
						local captured = p
						UltConnections[captured] = MatchUsedUltEvent.Event:Connect(function(player)
							if player == captured then HandleUseUlt(player, MatchArgs.Map) end
						end)
					end
				end

				FireAllPlayers(team1, team2, 'FadeOut')

				task.delay(4, function()
					MatchModule.SetMatchReady(team1.Players[1])
				end)

				task.delay(4.5, function()
					MatchInteractions.StartBoundsCheck(newArena.ID)
				end)

				DeathConnections[arenaId] = CreateNvNDeathHandler(
					arenaId, team1, team2, teamChars, newArena.Bounds, MatchArgs
				)
			end)
		end)
	end

	table.insert(ArenaStorage, newArena)
	return newArena
end

-- ============================================================
-- STOP MATCHES
-- ============================================================
function MatchInteractions.Stop1v1Match(player1, player2, arenaID)
	if arenaID ~= nil then
		MatchInteractions.StopBoundsCheck(arenaID)
	else
		warn("[Stop1v1Match] arenaID nil — parando bounds por player.")
		if player1 then MatchInteractions.StopBoundsCheckByPlayer(player1) end
		if player2 then MatchInteractions.StopBoundsCheckByPlayer(player2) end
	end

	if player1 and player1.Parent then
		MatchRemoteEvent:FireClient(player1, 'DisableFightingFrame')
		MatchRemoteEvent:FireClient(player1, 'EnableHUD')
		ToggleMovementRemote:FireClient(player1, "DisableReturnLobby")
		MatchMapsRemoteEvent:FireClient(player1, 'Cleanup')
		UltConnections[player1] = nil
	end

	if player2 and player2.Parent then
		MatchRemoteEvent:FireClient(player2, 'DisableFightingFrame')
		MatchRemoteEvent:FireClient(player2, 'EnableHUD')
		ToggleMovementRemote:FireClient(player2, "DisableReturnLobby")
		MatchMapsRemoteEvent:FireClient(player2, 'Cleanup')
		UltConnections[player2] = nil
	end

	task.wait(0.2)

	if player1 and player1:IsA('Player') then
		SwapCharacterBack(player1, function(chr)
			if chr and chr.Parent then
				chr:PivotTo(CFrame.new(lobbyPosition + Vector3.new(0, 9, 0)))
			end
		end)
	end

	if player2 and player2:IsA('Player') then
		SwapCharacterBack(player2, function(chr)
			if chr and chr.Parent then
				chr:PivotTo(CFrame.new(lobbyPosition + Vector3.new(0, 9, 0)))
			end
		end)
	end

	if DeathConnections[arenaID] then
		DeathConnections[arenaID]:Disconnect()
		DeathConnections[arenaID] = nil
	end

	if arenaID and ArenaContexts[arenaID] then ArenaContexts[arenaID] = nil end

	if player1 then ClearStats(player1) end
	if player2 then ClearStats(player2) end

	MatchInteractions.EndMatch(arenaID)
end

function MatchInteractions.Stop2v2Match(team1, team2, arenaID)
	print('stop NvN match interactions')

	if arenaID ~= nil then
		MatchInteractions.StopBoundsCheck(arenaID)
	else
		warn("[Stop2v2Match] arenaID nil — parando bounds por player.")
		for _, team in ipairs({ team1, team2 }) do
			for _, p in ipairs(team.Players) do
				if p then MatchInteractions.StopBoundsCheckByPlayer(p) end
			end
		end
	end

	for _, team in ipairs({ team1, team2 }) do
		for _, p in ipairs(team.Players) do
			if p and p.Parent then
				DisconnectHostCamera(p)
				DisconnectSpectateCamera(p)
				ToggleMovementRemote:FireClient(p, "DisableReturnLobby")
				MatchRemoteEvent:FireClient(p, 'DisableFightingFrame')
				MatchRemoteEvent:FireClient(p, 'EnableHUD')
				MatchMapsRemoteEvent:FireClient(p, 'Cleanup')
				UltConnections[p] = nil
			end
		end
	end

	if DeathConnections[arenaID] then
		DeathConnections[arenaID]:Disconnect()
		DeathConnections[arenaID] = nil
	end

	ArenaContexts[arenaID] = nil

	MatchInteractions.EndMatch(arenaID)

	task.wait(0.2)

	for _, team in ipairs({ team1, team2 }) do
		for _, p in ipairs(team.Players) do
			if p and p:IsA('Player') then
				SwapCharacterBack(p, function(chr)
					if chr and chr.Parent then
						chr:PivotTo(CFrame.new(lobbyPosition + Vector3.new(0, 9, 0)))
					end
				end)
			end
		end
	end
end

-- ============================================================
-- UTILS
-- ============================================================
local function GetArenaByID(arenaId: number): Arena?
	for _, arena in pairs(ArenaStorage) do
		if arena.ID == arenaId then return arena end
	end
	return nil
end

function MatchInteractions.StartMatch(MatchType: string, MatchArgs: { any }): number?
	local arena = CreateArena(GetNextId(), MatchType, MatchArgs)
	return arena.ID
end

function MatchInteractions.EndMatch(arenaId: number)
	local arena = GetArenaByID(arenaId)
	if not arena then return end
	arena.InUse = false
	if arena.Bounds then
		arena.Bounds:Destroy()
		arena.Bounds = nil
	end
end

function MatchInteractions.GetArena(arenaId: number): Arena?
	return GetArenaByID(arenaId)
end

-- ============================================================
-- BOUNDS CHECKING
-- ============================================================
function MatchInteractions.StartBoundsCheck(arenaId: number)
	if BoundsConnections[arenaId] then return end

	BoundsStopped[arenaId] = false
	local elapsed = 0

	BoundsConnections[arenaId] = RunService.Heartbeat:Connect(function(dt)
		if BoundsStopped[arenaId] then
			if BoundsConnections[arenaId] then
				BoundsConnections[arenaId]:Disconnect()
				BoundsConnections[arenaId] = nil
			end
			return
		end

		elapsed += dt
		if elapsed < BOUNDS_CHECK_INTERVAL then return end
		elapsed = 0

		local arena = GetArenaByID(arenaId)
		if not arena or not arena.Bounds or not arena.Bounds.Parent then
			BoundsStopped[arenaId] = true
			return
		end

		for _, player in ipairs(GetActiveFighters(arenaId)) do
			local hrp = GetHRP(player)
			if hrp and not IsInsideBounds(hrp.Position, arena.Bounds) then
				if not BoundsStopped[arenaId] then
					PushBackToArena(player, arena.Bounds)
				end
			end
		end
	end)
end

function MatchInteractions.StopBoundsCheckByPlayer(player: Player)
	for arenaId, _ in pairs(BoundsConnections) do
		local fighters = GetActiveFighters(arenaId)
		for _, f in ipairs(fighters) do
			if f == player then
				MatchInteractions.StopBoundsCheck(arenaId)
				return
			end
		end
		local arena = GetArenaByID(arenaId)
		if arena then
			local args = arena.MatchArgs
			if args.Player1 == player or args.Player2 == player or args.Player == player then
				MatchInteractions.StopBoundsCheck(arenaId)
				return
			end
		end
	end
end

function MatchInteractions.StopBoundsCheck(arenaId: number)
	BoundsStopped[arenaId] = true
	if BoundsConnections[arenaId] then
		BoundsConnections[arenaId]:Disconnect()
		BoundsConnections[arenaId] = nil
	end
end

return MatchInteractions
