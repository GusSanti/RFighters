local FightingHUD = {}

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local FightingFrame   -- injetado via Init
local ShakeConnections = {}
local cooldownTimers = {}
local Player1UIHealthBarConnection = nil
local Player2UIHealthBarConnection = nil

local COOLDOWN_COLOR = Color3.fromRGB(255, 115, 34)
local DEFAULT_COLOR  = Color3.fromRGB(255, 255, 255)

-- ── helpers ──────────────────────────────────────────────────────────────────

local function tweenGradientOffset(gradient, offset)
	TweenService:Create(gradient,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Offset = Vector2.new(offset, 0) }):Play()
end

local function shakeGui(guiObject, duration, magnitude)
	if ShakeConnections[guiObject.Name] then return end
	local originalPos = guiObject.Position
	local start = tick()
	ShakeConnections[guiObject.Name] = RunService.RenderStepped:Connect(function()
		if tick() - start > duration then
			guiObject.Position = originalPos
			ShakeConnections[guiObject.Name]:Disconnect()
			ShakeConnections[guiObject.Name] = nil
			return
		end
		guiObject.Position = originalPos + UDim2.fromOffset(
			(math.random() - 0.5) * magnitude,
			(math.random() - 0.5) * magnitude)
	end)
end

-- ── barras individuais ────────────────────────────────────────────────────────

local function updateHealthBar(frame, percentage, invertOffset)
	percentage = math.clamp(percentage, 0, 100)
	local offset = invertOffset and (-1 + percentage / 100) or (1 - percentage / 100)
	local hb = frame.HealthBar
	tweenGradientOffset(hb.Fill.UIGradient, offset)
	task.delay(0.5, function() tweenGradientOffset(hb.FillDelay.UIGradient, offset) end)
	shakeGui(hb, 0.15, 8)
end

local function updateGradientBar(barInstance, percentage, invertOffset, magnitude)
	percentage = math.clamp(percentage, 0, 100)
	local offset = invertOffset and (-1 + percentage / 100) or (1 - percentage / 100)
	tweenGradientOffset(barInstance.Fill.UIGradient, offset)
	shakeGui(barInstance, 0.15, magnitude or 6)
end

-- ── API pública ───────────────────────────────────────────────────────────────

function FightingHUD.Init(fightingFrame)
	FightingFrame = fightingFrame
end

function FightingHUD.ResetAll()
	if Player1UIHealthBarConnection then Player1UIHealthBarConnection:Disconnect() end
	if Player2UIHealthBarConnection then Player2UIHealthBarConnection:Disconnect() end

	local P1 = FightingFrame.Top.Player1
	local P2 = FightingFrame.Top.Player2

	updateHealthBar(P1, 100, false)
	updateHealthBar(P2, 100, true)
	updateGradientBar(P1.BurstBar,  0, false)
	updateGradientBar(P2.BurstBar,  0, true)
	updateGradientBar(P1.UltBar,    0, false)
	updateGradientBar(P2.UltBar,    0, true)
	updateGradientBar(P1.StaminaBar,100, false)
	updateGradientBar(P2.StaminaBar,100, true)

	P1.Profile.PlayerHead.Image  = "rbxassetid://102854401718271"
	P2.Profile.PlayerHead.Image  = "rbxassetid://102854401718271"
	P1.Profile.PlayerName.Text   = "None"
	P1.Profile.PlayerName.SecondText.Text = "None"
	P2.Profile.PlayerName.Text   = "None"
	P2.Profile.PlayerName.SecondText.Text = "None"
	FightingFrame.Top.Timer.Text3D.Text = "999"
	FightingFrame.Top.Timer.Text3D.SecondText.Text = "999"

	for _, p in {P1, P2} do
		p.Round1Win.ImageColor3 = Color3.fromRGB(0,0,0)
		p.Round2Win.ImageColor3 = Color3.fromRGB(0,0,0)
		p.UltBar.FullBarIndicator.Visible = false
	end
end

function FightingHUD.HandleEvent(action, args)
	local P1 = FightingFrame.Top.Player1
	local P2 = FightingFrame.Top.Player2

	if action == 'Init' then
		local chr1, chr2 = args.Character1, args.Character2
		local player1 = game.Players:GetPlayerFromCharacter(chr1)
		local player2 = game.Players:GetPlayerFromCharacter(chr2)

		FightingHUD.ResetAll()

		Player1UIHealthBarConnection = chr1.Humanoid.HealthChanged:Connect(function(hp)
			updateHealthBar(P1, math.round(hp / chr1.Humanoid.MaxHealth * 100), false)
		end)
		Player2UIHealthBarConnection = chr2.Humanoid.HealthChanged:Connect(function(hp)
			updateHealthBar(P2, math.round(hp / chr2.Humanoid.MaxHealth * 100), true)
		end)

		local function setName(frame, player, fallback)
			local name = player and player.Name or fallback
			frame.Profile.PlayerName.Text = name
			frame.Profile.PlayerName.SecondText.Text = name
		end
		setName(P1, player1, 'OfflineBot')
		setName(P2, player2, 'OfflineBot')

		if player1 then
			P1.Profile.PlayerHead.Image = game.Players:GetUserThumbnailAsync(
				player1.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end
		if player2 then
			P2.Profile.PlayerHead.Image = game.Players:GetUserThumbnailAsync(
				player2.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end

	elseif action == 'UpdateTimer' then
		FightingFrame.Top.Timer.Text3D.Text = args.Time
		FightingFrame.Top.Timer.Text3D.SecondText.Text = args.Time

	elseif action == 'UpdatePlayer1Health' then updateHealthBar(P1, args.Percentage, false)
	elseif action == 'UpdatePlayer2Health' then updateHealthBar(P2, args.Percentage, true)

	elseif action == 'UpdatePlayer1BurstBar' then updateGradientBar(P1.BurstBar, args.Percentage, false)
	elseif action == 'UpdatePlayer2BurstBar' then updateGradientBar(P2.BurstBar, args.Percentage, true)

	elseif action == 'UpdatePlayer1UltBar' then
		updateGradientBar(P1.UltBar, args.Percentage, false)
		P1.UltBar.FullBarIndicator.Visible = args.Percentage == 100

	elseif action == 'UpdatePlayer2UltBar' then
		updateGradientBar(P2.UltBar, args.Percentage, true)
		P2.UltBar.FullBarIndicator.Visible = args.Percentage == 100

	elseif action == 'UpdatePlayer1StaminaBar' then updateGradientBar(P1.StaminaBar, args.Percentage, false)
	elseif action == 'UpdatePlayer2StaminaBar' then updateGradientBar(P2.StaminaBar, args.Percentage, true)

	elseif action == 'UpdatePlayer1RoundWin' then
		local color = args.Won and Color3.fromRGB(255,0,0) or Color3.fromRGB(0,0,0)
		P1["Round"..args.Round.."Win"].ImageColor3 = color

	elseif action == 'UpdatePlayer2RoundWin' then
		local color = args.Won and Color3.fromRGB(255,0,0) or Color3.fromRGB(0,0,0)
		P2["Round"..args.Round.."Win"].ImageColor3 = color

	elseif action == 'SkillCooldownUpdate' then FightingHUD.UpdateAbilityUI(args.Key, args.Remaining)
	elseif action == 'SkillCooldownReady'  then FightingHUD.HideAbilityUI(args.Key)
	end
end

-- ── cooldown de ability ───────────────────────────────────────────────────────

local AbilityFrames -- mapa Key → frame, preenchido via SetAbilityFrames
function FightingHUD.SetAbilityFrames(frames)
	AbilityFrames = frames  -- { Skill1 = Ability1, Skill2 = Ability2, Ultimate = Ability3 }
end

local function setCooldownVisuals(frame, inCooldown)
	frame.Ability.BAR.ImageColor3  = inCooldown and COOLDOWN_COLOR or DEFAULT_COLOR
	frame.Ability.ImageColor3      = inCooldown and COOLDOWN_COLOR or DEFAULT_COLOR
	frame.Bind.ImageColor3         = inCooldown and COOLDOWN_COLOR or DEFAULT_COLOR
	frame.Bind.BAR.ImageColor3     = inCooldown and COOLDOWN_COLOR or DEFAULT_COLOR
	frame.Ability.Text.Cooldown.Enabled    = inCooldown
	frame.Bind.Text.Cooldown.Enabled       = inCooldown
	frame.Bind.Text.NoCooldown.Enabled     = not inCooldown
end

function FightingHUD.HideAbilityUI(Key)
	if cooldownTimers[Key] then cooldownTimers[Key]:Disconnect(); cooldownTimers[Key] = nil end
	local f = AbilityFrames and AbilityFrames[Key]
	if not f then return end
	setCooldownVisuals(f, false)
	f.Cooldown.Visible = false
end

function FightingHUD.UpdateAbilityUI(Key, Time)
	local f = AbilityFrames and AbilityFrames[Key]
	if not f then return end
	setCooldownVisuals(f, true)
	f.Cooldown.Visible = true
	if cooldownTimers[Key] then cooldownTimers[Key]:Disconnect(); cooldownTimers[Key] = nil end

	local timeRemaining = Time
	local lastShake = math.floor(timeRemaining)
	cooldownTimers[Key] = RunService.Heartbeat:Connect(function(dt)
		timeRemaining -= dt
		if timeRemaining <= 0 then
			cooldownTimers[Key]:Disconnect(); cooldownTimers[Key] = nil
			FightingHUD.HideAbilityUI(Key)
			return
		end
		f.Cooldown.Text = string.format("%.3f", timeRemaining)
		local floor = math.floor(timeRemaining)
		if floor < lastShake then
			lastShake = floor
			shakeGui(FightingFrame.Top.Player1.UltBar, 0.15, 6)
		end
	end)
end

local function setActionStateColor(frame, locked)
	if not frame then return end
	local cooldown = frame:FindFirstChild("Cooldown")
	local inCooldown = cooldown and cooldown.Visible
	local color = inCooldown and COOLDOWN_COLOR or (locked and Color3.fromRGB(115, 115, 115) or DEFAULT_COLOR)
	local ability = frame:FindFirstChild("Ability")
	local bind = frame:FindFirstChild("Bind")
	local function tint(instance)
		if instance and (instance:IsA("ImageLabel") or instance:IsA("ImageButton")) then
			instance.ImageColor3 = color
		end
	end
	tint(ability)
	tint(ability and ability:FindFirstChild("BAR"))
	tint(bind)
	tint(bind and bind:FindFirstChild("BAR"))
end

function FightingHUD.SetActionStates(states)
	if not states or not AbilityFrames then return end
	setActionStateColor(AbilityFrames.Skill1, states.SKILL1 == false)
	setActionStateColor(AbilityFrames.Skill2, states.SKILL2 == false)
	setActionStateColor(AbilityFrames.Ultimate, states.ULTIMATE == false)
end

function FightingHUD.PulseAbility(Key)
	local f = AbilityFrames and AbilityFrames[Key]
	if f then
		shakeGui(f, 0.12, 5)
	end
end

function FightingHUD.PulseStaminaDenied()
	if not FightingFrame then return end
	local top = FightingFrame:FindFirstChild("Top")
	local player1 = top and top:FindFirstChild("Player1")
	local staminaBar = player1 and player1:FindFirstChild("StaminaBar")
	if staminaBar then
		shakeGui(staminaBar, 0.18, 8)
	end
end

return FightingHUD