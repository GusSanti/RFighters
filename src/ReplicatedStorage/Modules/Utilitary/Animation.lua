-- Module to play animations

local ContentProvider = game:GetService("ContentProvider")
local Replicated = game:GetService("ReplicatedStorage")

local AnimsCache = Replicated.Files.Animations

local Animation = {}
local Cache = {}

function Animation.Preload()
	local toLoad = {}
	
	for _,AnimObject in pairs(AnimsCache:GetDescendants()) do
		if AnimObject:IsA("Animation") and AnimObject.AnimationId ~= "" then
			table.insert(toLoad, AnimObject)
		end
	end
	
	task.spawn(function()
		ContentProvider:PreloadAsync(toLoad)
	end)
end

function Animation.Get(Character:Model, AnimObject:Animation)
	local Animator:Animator = Character.Humanoid.Animator
	
	if Cache[Character] then
		if Cache[Character][AnimObject] then
			return Cache[Character][AnimObject]
		end
	else
		Cache[Character] = {}
	end
	
	Cache[Character][AnimObject] = Animator:LoadAnimation(AnimObject)
	
	return Cache[Character][AnimObject]
end

function Animation.Play(Character:Model, AnimObject:Animation, playData)
	local track:AnimationTrack = Animation.Get(Character, AnimObject)
	track.Priority = playData and playData.Priority or track.Priority
	if track then
		track:Play()
	end
	
	return track
end

function Animation.Stop(Character:Model, AnimObject:Animation)
	local track:AnimationTrack = Animation.Get(Character, AnimObject)
	if track then
		track:Stop()
	end
end

function Animation.StopName(Character:Model, Name)
	local Animator:Animator = Character.Humanoid.Animator
	local playingTracks = Animator:GetPlayingAnimationTracks()
	
	for _,track:AnimationTrack in pairs(playingTracks) do
		if typeof(Name) == "string" then
			if track.Animation.Name:find(Name) then
				track:Stop()
			end
		elseif typeof(Name) == "table" then
			for _,names in pairs(Name) do
				if track.Animation.Name:find(names) then
					track:Stop()
				end
			end
		end
	end
end

function Animation.StopAll(Character:Model)
	local Animator:Animator = Character.Humanoid.Animator
	local playingTracks = Animator:GetPlayingAnimationTracks()

	for _,track:AnimationTrack in pairs(playingTracks) do
		track:Stop()
	end
end

function Animation.Clear(Character:Model, clearCache:boolean?)
	local Animator:Animator = Character.Humanoid.Animator
	local playingTracks = Animator:GetPlayingAnimationTracks()

	for _,track:AnimationTrack in pairs(playingTracks) do
		track:Stop()
	end
	
	if clearCache then
		Cache[Character] = nil
	end
end

return Animation