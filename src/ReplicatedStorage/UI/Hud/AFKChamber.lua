local module = {}

function module.ButtonAction(button, action)
	if action == "Enter" then
		local TeleportService = game:GetService("TeleportService")
		local PLACE_ID = 110860579250923
		TeleportService:Teleport(PLACE_ID)
	end
end

return module
