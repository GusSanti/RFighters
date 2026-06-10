local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")

local StateManager = require(ServerStorage.NPC.NPCStateManager)
local StateEnums = require(ReplicatedStorage.PlayerState.ENUM)

local VFX = require(ReplicatedStorage.Modules.Utilitary.VFX)

-- Evento de Dash Cancel
local DashCancelEvent = ReplicatedStorage.Movment.Dash.Events:WaitForChild("DashCancelEvent")

local RagdollModule = {}

-- Cache de sons de impacto (carrega uma vez só)
local IMPACT_SOUNDS = {}
local IMPACT_SOUND_FOLDER = script:FindFirstChild("ImpactSounds") 

if IMPACT_SOUND_FOLDER then
	for _, sound in ipairs(IMPACT_SOUND_FOLDER:GetChildren()) do
		if sound:IsA("Sound") then
			table.insert(IMPACT_SOUNDS, sound)
		end
	end
end

-- Configurações de impacto
local IMPACT_CONFIG = {
	MIN_VELOCITY = 20, 
	COOLDOWN = 0.3, 
	MAX_SOUNDS_PER_FRAME = 3 
}

local COLLIDER_PARTS = {
	["Head"] = true,
	["Torso"] = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true
}

-- Tracking de impactos para cooldown
local impactCooldowns = {}
local soundsThisFrame = 0

-- CRIA OS COLLISION GROUPS
local function setupCollisionGroups()
	pcall(function()
		PhysicsService:RegisterCollisionGroup("RagdollParts")
		PhysicsService:RegisterCollisionGroup("RagdollColliders")
	end)

	PhysicsService:CollisionGroupSetCollidable("RagdollColliders", "RagdollColliders", false)
	PhysicsService:CollisionGroupSetCollidable("RagdollParts", "RagdollParts", false)
	PhysicsService:CollisionGroupSetCollidable("RagdollParts", "RagdollColliders", false)
end

setupCollisionGroups()

-- REATIVA MOUSELOCK QUANDO RESPAWNAR
local function setupPlayerRespawnHandler(player)
	local function onCharacterAdded(character)
		player.DevEnableMouseLock = true
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
end

Players.PlayerAdded:Connect(setupPlayerRespawnHandler)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayerRespawnHandler(player)
end

-----------------------------------------------------------
-- SISTEMA DE SOM DE IMPACTO CENTRALIZADO
-----------------------------------------------------------
local function playImpactSound(part, velocity)
	if #IMPACT_SOUNDS == 0 then return end

	local now = tick()
	local lastImpact = impactCooldowns[part]

	if lastImpact and (now - lastImpact) < IMPACT_CONFIG.COOLDOWN then
		return
	end

	if soundsThisFrame >= IMPACT_CONFIG.MAX_SOUNDS_PER_FRAME then
		return
	end

	if velocity < IMPACT_CONFIG.MIN_VELOCITY then
		return
	end

	impactCooldowns[part] = now
	soundsThisFrame = soundsThisFrame + 1

	local randomSound = IMPACT_SOUNDS[math.random(1, #IMPACT_SOUNDS)]
	local sound = randomSound:Clone()
	sound.Parent = part

	local volumeMultiplier = math.clamp(velocity / 50, 0.5, 1.5)
	sound.Volume = sound.Volume * volumeMultiplier

	Debris:AddItem(sound, 3)
	sound:Play()
end

local function setupImpactDetection(character)
	local connections = {}
	local lastVelocities = {}

	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") and COLLIDER_PARTS[part.Name] then
			lastVelocities[part] = Vector3.zero

			local conn = part.Touched:Connect(function(hit)
				if not RagdollModule:IsRagdolled(character) then return end
				if hit:IsDescendantOf(character) then return end
				if hit.Transparency >= 1 then return end
				if hit.Name == "Hitbox" or hit:HasTag("Hitbox") then return end

				local velocity = part.AssemblyLinearVelocity.Magnitude
				playImpactSound(part, velocity)
			end)

			table.insert(connections, conn)
		end
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			task.wait(5)
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
		end)
	end

	return connections
end

RunService.Heartbeat:Connect(function()
	soundsThisFrame = 0
end)

-----------------------------------------------------------
-- Impede o Humanoid de tentar mover o ragdoll
-----------------------------------------------------------
function RagdollModule:FreezeHumanoidMotion(character)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local conn
	conn = RunService.Stepped:Connect(function()
		if not self:IsRagdolled(character) then
			conn:Disconnect()
			return
		end

		humanoid:Move(Vector3.zero, true)

		local hrp = humanoid.RootPart
		if hrp then
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

-----------------------------------------------------------
-- SETUP INICIAL
-----------------------------------------------------------
function RagdollModule:Setup(character)
	RunService.Stepped:Wait()

	if character:FindFirstChild("RagdollObjects") then
		return
	end

	local ragdollObjects = Instance.new("Folder")
	ragdollObjects.Name = "RagdollObjects"
	ragdollObjects.Parent = character

	local ragdollConstraints = Instance.new("Folder")
	ragdollConstraints.Name = "RagdollContraints"
	ragdollConstraints.Parent = ragdollObjects

	local ragdollJoints = Instance.new("Folder")
	ragdollJoints.Name = "RagdollJoints"
	ragdollJoints.Parent = ragdollObjects

	local ragdollColliders = Instance.new("Folder")
	ragdollColliders.Name = "RagdollColliders"
	ragdollColliders.Parent = ragdollObjects

	local humanoid = character:WaitForChild("Humanoid")
	humanoid.BreakJointsOnDeath = false

	for _, joint in pairs(character:GetDescendants()) do
		if joint:IsA("Motor6D") then
			local socket = Instance.new("BallSocketConstraint")
			socket.Enabled = false
			socket.Name = joint.Name
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			socket.MaxFrictionTorque = 0
			socket.TwistLowerAngle = -90
			socket.TwistUpperAngle = 90

			local att0 = Instance.new("Attachment")
			att0.Name = "RagdollAttachment_" .. joint.Part0.Name
			att0.CFrame = joint.C0
			att0.Parent = joint.Part0

			local att1 = Instance.new("Attachment")
			att1.Name = "RagdollAttachment_" .. joint.Part1.Name
			att1.CFrame = joint.C1
			att1.Parent = joint.Part1

			socket.Attachment0 = att0
			socket.Attachment1 = att1
			socket.Parent = ragdollConstraints

			local ref = Instance.new("ObjectValue")
			ref.Value = joint
			ref.Name = joint.Name
			ref.Parent = ragdollJoints
		end
	end

	setupImpactDetection(character)

	humanoid.Died:Once(function()
		self:RagdollDied(character)
	end)
end

-----------------------------------------------------------
-- FUNÇÃO AUXILIAR PARA RAGDOLL
-----------------------------------------------------------
local function applyRagdollPhysics(character, folder)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return false end

	character:SetAttribute("Ragdolled", true)
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true

	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	StateManager.POST(character, StateEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "RagdollParts"
		end
	end

	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") and COLLIDER_PARTS[part.Name] then
			local colName = part.Name .. "_Collider"
			local existingCol = folder.RagdollColliders:FindFirstChild(colName)

			if not existingCol then
				local col = Instance.new("Part")
				col.Size = part.Size
				col.CFrame = part.CFrame
				col.Transparency = 1
				col.CanCollide = true
				col.Anchored = false
				col.Massless = true
				col.Name = colName
				col.CollisionGroup = "RagdollColliders"
				col.Parent = folder.RagdollColliders

				local weld = Instance.new("WeldConstraint")
				weld.Part0 = col
				weld.Part1 = part
				weld.Parent = col
			end
		end
	end

	for _, sk in pairs(folder.RagdollContraints:GetChildren()) do
		if sk:IsA("BallSocketConstraint") then
			sk.Enabled = true
		end
	end

	for _, jv in pairs(folder.RagdollJoints:GetChildren()) do
		if jv.Value and jv.Value:IsA("Motor6D") then
			jv.Value.Enabled = false
		end
	end

	return true
end

local function applyRagdollPhysicsDied(character, folder)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return false end

	character:SetAttribute("Ragdolled", true)
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true

	StateManager.POST(character, StateEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "RagdollParts"
		end
	end

	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") and COLLIDER_PARTS[part.Name] then
			local colName = part.Name .. "_Collider"
			local existingCol = folder.RagdollColliders:FindFirstChild(colName)

			if not existingCol then
				local col = Instance.new("Part")
				col.Size = part.Size
				col.CFrame = part.CFrame
				col.Transparency = 1
				col.CanCollide = true
				col.Anchored = false
				col.Massless = true
				col.Name = colName
				col.CollisionGroup = "RagdollColliders"
				col.Parent = folder.RagdollColliders

				local weld = Instance.new("WeldConstraint")
				weld.Part0 = col
				weld.Part1 = part
				weld.Parent = col
			end
		end
	end

	for _, sk in pairs(folder.RagdollContraints:GetChildren()) do
		if sk:IsA("BallSocketConstraint") then
			sk.Enabled = true
		end
	end

	for _, jv in pairs(folder.RagdollJoints:GetChildren()) do
		if jv.Value and jv.Value:IsA("Motor6D") then
			jv.Value.Enabled = false
		end
	end

	return true
end

-----------------------------------------------------------
-- RAGDOLL
-----------------------------------------------------------
function RagdollModule:Ragdoll(character, duration)
	local folder = character:FindFirstChild("RagdollObjects")
	if not folder then return end

	if not applyRagdollPhysics(character, folder) then
		return
	end

	self:FreezeHumanoidMotion(character)

	-- [SISTEMA DE DASH CANCEL]
	-- Ativa a janela de oportunidade de 5 segundos
	character:SetAttribute("CanDashCancel", true)

	task.delay(5, function()
		if character and character:GetAttribute("CanDashCancel") then
			character:SetAttribute("CanDashCancel", false)
		end
	end)

	if duration and duration > 0 then
		task.delay(duration, function()
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid and humanoid.Health > 0 then
				self:Unragdoll(character)
			end
		end)
	end
end

-----------------------------------------------------------
-- RAGDOLL NA MORTE
-----------------------------------------------------------
function RagdollModule:RagdollDied(character, duration)
	local folder = character:FindFirstChild("RagdollObjects")
	if not folder then return end

	if not applyRagdollPhysicsDied(character, folder) then
		return
	end

	self:FreezeHumanoidMotion(character)

	if duration and duration > 0 then
		task.delay(duration, function()
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid and humanoid.Health > 0 then
				self:Unragdoll(character)
			end
		end)
	end
end

-----------------------------------------------------------
-- UNRAGDOLL (LEVANTAR)
-----------------------------------------------------------
function RagdollModule:Unragdoll(character)
	local folder = character:FindFirstChild("RagdollObjects")
	if not folder then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	character:SetAttribute("Ragdolled", false)
	character:SetAttribute("CanDashCancel", false) -- Limpa flag de dash cancel

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local pos = hrp.Position
		hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(hrp.Orientation.Y), 0)
	end

	humanoid.PlatformStand = false
	humanoid.AutoRotate = true

	StateManager.REMOVE(character, StateEnums.STATES_ENUM.COMBAT_FULL_STUNNED)

	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Default"
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end

	for _, sk in pairs(folder.RagdollContraints:GetChildren()) do
		if sk:IsA("BallSocketConstraint") then
			sk.Enabled = false
		end
	end

	for _, jv in pairs(folder.RagdollJoints:GetChildren()) do
		if jv.Value and jv.Value:IsA("Motor6D") then
			jv.Value.Enabled = true
		end
	end

	folder.RagdollColliders:ClearAllChildren()

	for part, _ in pairs(impactCooldowns) do
		if part:IsDescendantOf(character) then
			impactCooldowns[part] = nil
		end
	end

	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end

function RagdollModule:IsRagdolled(character)
	return character:GetAttribute("Ragdolled") == true
end

-- [EVENTO] Ouve o pedido de Dash Cancel do cliente
DashCancelEvent.OnServerEvent:Connect(function(player)
	local char = player.Character
	if char and RagdollModule:IsRagdolled(char) then
		if char:GetAttribute("CanDashCancel") == true then
			VFX.Highlight(char,Color3.fromRGB(255, 255, 255),0.6)
			RagdollModule:Unragdoll(char)
		end
	end
end)

return RagdollModule