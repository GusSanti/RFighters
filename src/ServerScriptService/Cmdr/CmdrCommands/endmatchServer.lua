-- Run implementation (server).
-- Fires the same ShowWinnerScreen payload as a real match end, then stops the
-- match so it can be re-tested. Useful to verify the WinnerScreen character card.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerState        = require(ReplicatedStorage.PlayerState.PlayerStateServer)
local MatchModule        = require(ReplicatedStorage.MatchSystem.MatchModule)
local MatchRemoteEvent   = ReplicatedStorage.Events.Match.MatchRemoteEvent
local GetCharacterPoolData = ReplicatedStorage.Events.GetCharacterPoolData

local PLACEHOLDER_STATS = { damageDealt = 0, damageTaken = 0, roundsWon = 0 }

local function charNameFor(player: Player): string
	local id = PlayerState.Get(player, "ActiveCharacter")
	return id or "Shiro"
end

return function(context, target: Player, result: string?)
	local targetWins = (result or "win"):lower() ~= "lose"

	local opponent = MatchModule.GetPlayer1v1Opponent(target)

	local winner = targetWins and target or (opponent or target)
	local loser  = targetWins and (opponent or target) or target

	local payload = {
		PlayerWinner = winner,
		PlayerLoser  = loser,
		WinnerStats  = PLACEHOLDER_STATS,
		LoserStats   = PLACEHOLDER_STATS,
		WinnerChar   = charNameFor(winner),
		LoserChar    = charNameFor(loser),
	}

	MatchRemoteEvent:FireClient(target, "ShowWinnerScreen", payload)
	if opponent then
		MatchRemoteEvent:FireClient(opponent, "ShowWinnerScreen", payload)
	end

	-- Free the arena after the screen shows, mirroring the real end flow.
	task.delay(2.2, function()
		MatchModule.StopMatchByPlayer(target)
	end)

	return ("Ended %s's match. %s shown as winner (char: %s)."):format(
		target.Name, winner.Name, payload.WinnerChar)
end
