local module = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

local RedeemCodeRF = ReplicatedStorage.Events:WaitForChild("RedemCodeRemoteFunction")

local UI = PlayerGui:WaitForChild("UI")
local Codes = UI:WaitForChild("Codes")
local button = Codes.MAIN.Redem
local textBox = Codes.MAIN.CodesMain:WaitForChild("TextBox") 

textBox:GetPropertyChangedSignal("Text"):Connect(function()
	textBox.Text = string.upper(textBox.Text)
end)

button.MouseButton1Click:Connect(function()
	local codeText = textBox.Text

	if codeText == "" or codeText:match("^%s*$") then return end

	local success, result = RedeemCodeRF:InvokeServer(codeText)

	if success then
		local rewardsGained = {}

		for statName, amount in pairs(result) do
			table.insert(rewardsGained, amount .. " " .. statName)
		end

		local notificationText = "Você ganhou: " .. table.concat(rewardsGained, ", ")

		StarterGui:SetCore("SendNotification", {
			Title = "Código Resgatado!",
			Text = notificationText,
			Duration = 5,
		})

		textBox.Text = ""
	else
		StarterGui:SetCore("SendNotification", {
			Title = "Erro",
			Text = result,
			Duration = 3,
		})
		
		textBox.TextColor3 = Color3.fromRGB(255, 0, 0)
		textBox.Text = "Error"
		

		print("Erro ao resgatar: " .. result)


		task.delay(2,function()
			textBox.Text = ""
			textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
		end)

	end
end)

return module
