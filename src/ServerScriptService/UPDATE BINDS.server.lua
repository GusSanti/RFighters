game.Players.PlayerAdded:Connect(function(plr)
	local PlayerState = require(game.ReplicatedStorage.PlayerState.PlayerStateServer)
	
	--PlayerState.Set(plr, 'ActiveCharacter', 'Grimm')

	PlayerState.Set(plr, 'Inputs', {
		RIGHT = {Enum.KeyCode.D.Name, Enum.KeyCode.Right.Name},
		LEFT = {Enum.KeyCode.A.Name, Enum.KeyCode.Left.Name},
		JUMP = {Enum.KeyCode.W.Name, Enum.KeyCode.Up.Name},
		CROUCH = {Enum.KeyCode.S.Name, Enum.KeyCode.Down.Name},

		LIGHTATK = {Enum.KeyCode.U.Name, Enum.UserInputType.MouseButton1.Name},
		HARDATK = {Enum.KeyCode.I.Name, Enum.UserInputType.MouseButton2.Name},
		CHARGEATK = {Enum.KeyCode.O.Name, Enum.KeyCode.Q.Name},
		GRAB = {Enum.KeyCode.P.Name, Enum.KeyCode.E.Name},

		ULTIMATE = {Enum.KeyCode.G.Name},

		EMOTE = {Enum.KeyCode.B.Name},

		SKILL1 = {Enum.KeyCode.One.Name},
		SKILL2 = {Enum.KeyCode.Two.Name},
		SKILL3 = {Enum.KeyCode.Three.Name},
		SKILL4 = {Enum.KeyCode.Four.Name}
	})
end)