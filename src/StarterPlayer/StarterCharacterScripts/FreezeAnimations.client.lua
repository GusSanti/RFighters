local Players = game:GetService("Players")
local player  = Players.LocalPlayer

local remoteFolder = game.ReplicatedStorage.CombatSystem.Events
if not remoteFolder then
	error("[FreezeAnimations Client] Pasta de remotes não encontrada.")
end

local remoteFreeze   = remoteFolder:WaitForChild("AnimationFreeze", 10)
local remoteUnfreeze = remoteFolder:WaitForChild("AnimationUnfreeze", 10)

local RunService = game:GetService("RunService")

local REACTIVATION_DELAY = 0.1

local reactivationTimer   = nil
local reactivationPending = false
local isFrozen            = false

local snapshot = nil

local function getAnimator()
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	return humanoid:FindFirstChildOfClass("Animator")
end

local function doReactivate()
	local character = player.Character
	local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
	local animateScript = character and character:FindFirstChild("Animate")

	if animateScript then
		animateScript.Disabled = false

		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
			task.defer(function()
				if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Running) end
			end)
		end
	end
end

local function doFreeze()
	isFrozen = true

	local animator = getAnimator()
	if not animator then
		warn("[FreezeAnimations Client] Animator não encontrado.")
		return
	end

	task.wait()

	local tracks = animator:GetPlayingAnimationTracks()
	snapshot = {}

	for _, track in ipairs(tracks) do
		local originalSpeed = track.Speed
		local originalPos   = track.TimePosition

		track:AdjustSpeed(0)
		track.TimePosition = originalPos

		snapshot[#snapshot + 1] = {
			track     = track,
			speed     = originalSpeed ~= 0 and originalSpeed or 1,
			position  = originalPos,
			animation = track.Animation,
		}
	end
end

local function doUnfreeze()
	local animator = getAnimator()

	if snapshot and animator then
		for _, entry in ipairs(snapshot) do
			local track = entry.track
			pcall(function()
				if track and track.Animation then
					track:Play()
					track:AdjustWeight(1)
					track.TimePosition = entry.position
					track:AdjustSpeed(entry.speed)
				end
			end)
		end
	end

	snapshot = nil

	isFrozen            = false
	reactivationTimer   = REACTIVATION_DELAY
	reactivationPending = true
end

-- ✅ Removido o check de animação Action que causava o bug do frame congelado
RunService.Heartbeat:Connect(function(dt)
	if not reactivationPending then return end
	if isFrozen then return end

	reactivationTimer = reactivationTimer - dt

	if reactivationTimer <= 0 then
		reactivationPending = false
		reactivationTimer   = nil
		doReactivate()
	end
end)

remoteFreeze.OnClientEvent:Connect(function()
	doFreeze()
end)

remoteUnfreeze.OnClientEvent:Connect(function()
	doUnfreeze()
end)