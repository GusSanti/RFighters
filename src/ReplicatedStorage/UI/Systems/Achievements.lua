local Achievements = {}
local localPlayer = game.Players.LocalPlayer
if not game:IsLoaded() then game.Loaded:Wait() end
local PlayerState = require(game.ReplicatedStorage.PlayerState.PlayerStateClient)
local playerGui = localPlayer:WaitForChild("PlayerGui")
local MainUI = playerGui:WaitForChild("UI")
local AchievementsUI = MainUI:WaitForChild("Achievements")
local Task1 = AchievementsUI.MAIN.Task1
local Task2 = AchievementsUI.MAIN.Task2
local Task3 = AchievementsUI.MAIN.Task3
local ClaimAchievement = game.ReplicatedStorage.QuestAchievementsSystem.Events.ClaimAchievement
local CompletedTasks = AchievementsUI.MAIN.CompletedTasks
local selectedMap = nil

-- ─── Utilitários ────────────────────────────────────────────────────────────

-- Atualiza o UIGradient da barra de progresso de uma Task
-- Estrutura: Task → BarBG → Bar → UIGradient
--   ratio 0 → Offset.X = -1 (barra vazia)
--   ratio 1 → Offset.X =  0 (barra cheia)
local function UpdateProgressBar(task, ratio)
	ratio = math.clamp(ratio, 0, 1)

	local barBG = task:FindFirstChild("BarBG")
	if not barBG then return end

	local bar = barBG:FindFirstChild("Bar")
	if not bar then return end

	local gradient = bar:FindFirstChildOfClass("UIGradient")
	if gradient then
		local offsetX = -1 + ratio  -- mapeia [0,1] → [-1,0]
		gradient.Offset = Vector2.new(offsetX, gradient.Offset.Y)
	end
end

-- ─── Init ───────────────────────────────────────────────────────────────────

function Achievements.Init()
	local PlayerAchievements = PlayerState.Get('Achievements')
	local MapTemplate = AchievementsUI.MAIN.ScrollingFrame.MapTemplate
	local firstMapButton = nil  -- ← adiciona isso

	for map, achievements in pairs(PlayerAchievements) do
		local TasksCompleted = 0
		local TotalTasks = 0
		for index, achievement in pairs(achievements) do
			TotalTasks = index
			if achievement.Completed then TasksCompleted += 1 end
		end
		local newMap = MapTemplate:Clone()
		newMap.Parent = AchievementsUI.MAIN.ScrollingFrame
		newMap.Name = map
		newMap.Visible = true
		newMap.MapName.Text = map
		newMap.CompletionPercentage.Text = (TasksCompleted / TotalTasks) * 100 .. '%'

		if not firstMapButton then  -- ← guarda o primeiro mapa criado
			firstMapButton = newMap
		end
	end

	-- Auto-select no primeiro mapa ao abrir
	if firstMapButton then
		Achievements.ButtonAction(firstMapButton, 'MapButtonClick')
	end
end
-- ─── ButtonAction ───────────────────────────────────────────────────────────

function Achievements.ButtonAction(button: GuiButton, action)
	if action == 'MapButtonClick' then
		local PlayerAchievements = PlayerState.Get('Achievements')

		local map = button.Name
		selectedMap = map

		for index, achievement in ipairs(PlayerAchievements[map]) do
			local CurrentTask = AchievementsUI.MAIN:FindFirstChild('Task' .. index)
			if not CurrentTask then continue end

			CurrentTask.Visible = true
			CurrentTask.TaskName.Text = achievement.Label
			CurrentTask.CompletionLabel.Text = achievement.CurrentTriggers .. '/' .. achievement.RequiredTriggers

			-- Barra de progresso
			local current  = achievement.CurrentTriggers or 0
			local required = achievement.RequiredTriggers or 0
			local ratio = 0
			if required > 0 then
				ratio = math.min(current / required, 1)
			elseif achievement.Completed then
				ratio = 1
			end
			UpdateProgressBar(CurrentTask, ratio)

			-- Recompensa
			if achievement.Reward.Type == 'PlayerStateIncrement' then
				CurrentTask.RewardQuantity.Text = achievement.Reward.IncrementValue .. 'x'

				if achievement.Reward.StateKey == 'Crystals' then
					CurrentTask.RewardImage.Image = "rbxassetid://124856269825747"
				end

				if achievement.Reward.StateKey == 'Diamonds' then
					CurrentTask.RewardImage.Image = "rbxassetid://91460785817697"
				end
			end
		end
	end

	if action == 'ClaimTask1' or action == 'ClaimTask2' or action == 'ClaimTask3' and selectedMap then
		ClaimAchievement:FireServer(action, selectedMap)
	end
end

return Achievements