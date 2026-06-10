--[[

You can configure mostly everything here. Set things to true or false.
Or using numbers if that's listed.

--]]

local MainSettings = {
	
	LoadingScreen = { -- Settings to configurate the Loading Sequence / Custom Loading Gui

		AssetFolder = game:GetService("ReplicatedStorage"):WaitForChild("CombatStorage"); -- Change this if you have a custom folder.
		
		SkipButton = true; -- Enable/Disable a skip button which lets players skip loading.
		LoadingBar = true; -- Display the Loading Bar
		
		DefaultRobloxUI = false; -- Enable/Disable the Default Roblox UI when in the loading screen.
		
		-- UI Element Configuration
		
		TopText = ""; -- Top text to display. Leave nothing in the quotation marks if you don't want this.
		BottomText = "Loading"; -- Bottom text to display. Leave nothing in the quotation marks if you don't want this.
		BackgroundImage = "rbxassetid://"; -- Set a background image for the loading screen.

		RandomizedTextEnabled = false; -- Randomizes a list of words and displays them on a text label every 5 seconds.
	}
	
}

return MainSettings