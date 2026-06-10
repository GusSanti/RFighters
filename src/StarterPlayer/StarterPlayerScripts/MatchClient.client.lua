local MatchCameraConnectionRemote = game.ReplicatedStorage.Events.Match.MatchCameraConnection
local MatchMapsRemoteEvent = game.ReplicatedStorage.Events.Match.MatchMapsRemoteEvent
local MatchUIInteractions = game.ReplicatedStorage.Events.Match.MatchUIInteractions
local FightTextUI = game.Players.LocalPlayer:WaitForChild('PlayerGui'):WaitForChild('UI'):WaitForChild('CombatHUD').FIGHTText
local RoundTextUI = game.Players.LocalPlayer:WaitForChild('PlayerGui'):WaitForChild('UI'):WaitForChild('CombatHUD').ROUNDtext
local KOTextUI = game.Players.LocalPlayer:WaitForChild('PlayerGui'):WaitForChild('UI'):WaitForChild('CombatHUD').KOtext
local MiddleBeep = game.ReplicatedStorage.MatchSystem.Storage.Sounds.MiddleBeep
local FinalBeep = game.ReplicatedStorage.MatchSystem.Storage.Sounds.FinalBeep
local RoundBeep = game.ReplicatedStorage.MatchSystem.Storage.Sounds.RoundSound
local KOSound = game.ReplicatedStorage.MatchSystem.Storage.Sounds.KO

local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local SpectateEnabled = false
local HostEnabled = false
local lastSyncTime = 0
local SYNC_INTERVAL = 4 -- segundos

MapLightiningStorage = {} 
MapMaterialsStorage = {}
MapModel = nil

local function AlignModelPartToPart(model: Model, modelPart: BasePart, targetCFrame: CFrame)
	local modelPivot = model:GetPivot()

	-- offset do pivot do model em relação à part interna
	local offset = modelPart.CFrame:ToObjectSpace(modelPivot)

	-- aplica o offset na part alvo
	model:PivotTo(targetCFrame * offset + Vector3.new(0, -86.5, 0))
end

local function playCountdownElement(guiObject, timeActive)
	guiObject.Visible = true
	guiObject.Size = UDim2.fromScale(0.5, 0.5)

	local tweenInProps = {
		Size = UDim2.fromScale(1,1)
	}

	local tweenOutProps = {
		Size = UDim2.fromScale(1.2,1.2)
	}

	if guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton") then
		guiObject.ImageTransparency = 1
		tweenInProps.ImageTransparency = 0
		tweenOutProps.ImageTransparency = 1
	end

	local tweenIn = TweenService:Create(
		guiObject,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		tweenInProps
	)

	local tweenOut = TweenService:Create(
		guiObject,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		tweenOutProps
	)

	tweenIn:Play()
	tweenIn.Completed:Wait()

	task.wait(timeActive or 0.4)

	tweenOut:Play()
	tweenOut.Completed:Wait()

	guiObject.Visible = false
end

local function playSound(sound)
	task.spawn(function()
		local clone = sound:Clone()
		clone.Parent = sound.Parent
		clone:Play()
		clone.Ended:Wait()
		clone:Destroy()
	end)
end

local function PlayFightCountdown(Round)
	local round = Round
	if not round then round = 1 end

	local three = FightTextUI:FindFirstChild("3")
	local two = FightTextUI:FindFirstChild("2")
	local one = FightTextUI:FindFirstChild("1")
	local fight = FightTextUI:FindFirstChild("FIGHT")

	local round1 = RoundTextUI:FindFirstChild("Round1")
	local round2 = RoundTextUI:FindFirstChild("Round2")
	local round3 = RoundTextUI:FindFirstChild("Round3")

	if round == 1 then
		round3.Visible = false
		round2.Visible = false
		round1.Visible = true
	end

	if round == 2 then
		round3.Visible = false
		round2.Visible = true
		round1.Visible = false
	end

	if round == 3 then
		round3.Visible = true
		round2.Visible = false
		round1.Visible = false
	end

	playSound(RoundBeep)
	playCountdownElement(RoundTextUI)
	playSound(MiddleBeep)
	playCountdownElement(three)
	playSound(MiddleBeep)
	playCountdownElement(two)
	playSound(MiddleBeep)
	playCountdownElement(one)
	playSound(FinalBeep)
	playCountdownElement(fight)
end

MatchUIInteractions.OnClientEvent:Connect(function(action, args)
	if action == 'StartCountdown' then
		task.spawn(function() PlayFightCountdown(1) end)
	end

	if action == 'StartRoundCountdown' then
		task.spawn(function() PlayFightCountdown(args) end)
	end

	if action == 'KOEffect' then
		KOSound:Play()
		task.spawn(function() playCountdownElement(KOTextUI, 2) end)
	end
end)

MatchMapsRemoteEvent.OnClientEvent:Connect(function(Action, Args)
	if Action == 'CloneMap' then
		-- LIGHTNING
		if Args.Map:FindFirstChild('Lightning') then
			for _, v in Args.Map.Lightning:GetChildren() do 
				if v:IsA('ModuleScript') and v.Name == 'Configs' then
					local mod = require(v :: ModuleScript)

					--game.Lighting.Ambient = mod.LightningConfigs.Ambient
					game.Lighting.Brightness = mod.LightningConfigs.Brightness
					game.Lighting.ColorShift_Bottom = mod.LightningConfigs.ColorShift_Bottom
					game.Lighting.ColorShift_Top = mod.LightningConfigs.ColorShift_Top
					game.Lighting.EnvironmentDiffuseScale = mod.LightningConfigs.EnvironmentDiffuseScale
					game.Lighting.EnvironmentSpecularScale = mod.LightningConfigs.EnvironmentSpecularScale
					game.Lighting.GlobalShadows = mod.LightningConfigs.GlobalShadows
					--game.Lighting.OutdoorAmbient = mod.LightningConfigs.OutdoorAmbient
					game.Lighting.ClockTime = mod.LightningConfigs.ClockTime
					game.Lighting.GeographicLatitude = mod.LightningConfigs.GeographicLatitude
				end

				local clone = v:Clone()
				clone.Parent = game.Lighting
				table.insert(MapLightiningStorage, clone)
			end
		end

		-- MATERIALS
		if Args.Map:FindFirstChild('Materials') then
			for _, v in Args.Map.Materials:GetChildren() do
				local clone = v:Clone()
				clone.Parent = game.MaterialService
				table.insert(MapMaterialsStorage, clone)
			end
		end

		-- MAP
		MapModel = Args.Map.Map.Model:Clone()

		for _, v in Args.Map.Map:GetDescendants() do
			if v:IsA('BasePart') then
				v.Anchored = true
				v.CanCollide = false
			end
		end

		local boundsSpawnPos = MapModel:FindFirstChild('MAP_BOUNDS_SPAWN_POS')
		MapModel.Parent = workspace

		AlignModelPartToPart(MapModel, boundsSpawnPos, Args.TargetCFrame)
	end

	if Action == 'Cleanup' then
		for _, v in MapLightiningStorage do
			v:Destroy()
		end
		for _, v in MapMaterialsStorage do
			v:Destroy()
		end
		if MapModel then MapModel:Destroy() end

		MapLightiningStorage = {}
		MapMaterialsStorage = {}
		MapModel = nil

		for _, v in game.ReplicatedStorage.MatchSystem.Storage.LobbyLightning:GetChildren() do 
			if v:IsA('ModuleScript') and v.Name == 'Configs' then
				local mod = require(v :: ModuleScript)

				--game.Lighting.Ambient = mod.LightningConfigs.Ambient
				game.Lighting.Brightness = mod.LightningConfigs.Brightness
				game.Lighting.ColorShift_Bottom = mod.LightningConfigs.ColorShift_Bottom
				game.Lighting.ColorShift_Top = mod.LightningConfigs.ColorShift_Top
				game.Lighting.EnvironmentDiffuseScale = mod.LightningConfigs.EnvironmentDiffuseScale
				game.Lighting.EnvironmentSpecularScale = mod.LightningConfigs.EnvironmentSpecularScale
				game.Lighting.GlobalShadows = mod.LightningConfigs.GlobalShadows
				--game.Lighting.OutdoorAmbient = mod.LightningConfigs.OutdoorAmbient
				game.Lighting.ClockTime = mod.LightningConfigs.ClockTime
				game.Lighting.GeographicLatitude = mod.LightningConfigs.GeographicLatitude
			end

			local clone = v:Clone()
			clone.Parent = game.Lighting
			table.insert(MapLightiningStorage, clone)
		end
	end
end)

MatchCameraConnectionRemote.OnClientEvent:Connect(function(action, args)
	if action == 'EnableSpectate' then
		workspace.Camera.CameraType = Enum.CameraType.Scriptable
		warn('SPECTATING PLAYER')
		SpectateEnabled = true
		lastSyncTime = 0
	elseif action == 'DisableSpectate' then
		workspace.Camera.CameraType = Enum.CameraType.Follow
		warn('SPECTATING DISABLED')
		SpectateEnabled = false
		lastSyncTime = 0
	end
	if action == 'EnableHost' then
		warn('HOSTING SPECTATOR ENABLED')
		HostEnabled = true
	elseif action == 'DisableHost' then
		warn('HOSTING SPECTATOR DISABLED')
		HostEnabled = false
	end
	if action == 'CameraConnection' and SpectateEnabled then
		local now = tick()
		if now - lastSyncTime >= SYNC_INTERVAL then
			local currentPosition = args.Position
			task.spawn(function()
				game.Players.LocalPlayer:RequestStreamAroundAsync(currentPosition)
			end)
			lastSyncTime = now
		end
		workspace.Camera.CFrame = args
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if HostEnabled then
		MatchCameraConnectionRemote:FireServer(workspace.Camera.CFrame)
	end
end)