-- LocalScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraModule = require(ReplicatedStorage.Modules.CameraModule)

local CutsceneCameraReplicate = ReplicatedStorage.Events.CutsceneCameraReplicate

CutsceneCameraReplicate.OnClientEvent:Connect(function(config)
	if config.Restore then
		CameraModule.RestoreCameraInstant()
		return
	end
	CameraModule.SetAnimatedCamera(config)
end)