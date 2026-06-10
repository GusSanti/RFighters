local module = {}

module.Size = Vector3.new(3,5,1)
module.Offset = CFrame.new(0,-0.5,0)
module.Name = "Goko"
module.Speed = 12.5
module.Jump = 38
module.Health = 120

module.moderninput = {
	One = "L236",
	Two = "L214",
	Three = "M623",
	Four = "S2",
	G = "S214"
}

module.exinput = {
	One = "H236",
	Two = "H214",
	Three = "H623",
	Four = "S236",
	G = "S214"
}

module.movenames = {
	"Laser Beam",
	"Straight Combo",
	"Dragon Spirit",
	"Power UP"
}

module.exmovenames = {
	"EX Beam",
	"EX Straight",
	"Dragon Power",
	"Energy Bomb"
}

do 
	module.othermovenames = {
		"Twin Pistons",
		"Side Vanish",
		"Up Vanish",
		"Power Down"
	}

	module.otherexmovenames = {
		"EX Pistons",
		"EX Vanish",
		"EX Vanish",
		"Energy Bomb"
	}
end

function module.dash(angle,mode,char)
	local stance = char.vals.stance
	local movetype = "selfback"
	local cold = 0
	
	local speed,anim,dist,check
	
	if mode == "front" then
		if stance.Value == 1 then
			speed = .3
			dist = char.HumanoidRootPart.CFrame.lookVector*35
			anim = game.ReplicatedStorage.Chars.Goko.dash
		else
			speed = 11
			anim = game.ReplicatedStorage.Chars.Goko.run
		end
		
		if game["Run Service"]:IsServer() then
			speed = .2
			dist = CFrame.new(0,0,-6)
			movetype = "knockback"
		else
			check = "dash"
		end

	elseif mode == "back" then
		speed = 0.3
		anim = game.ReplicatedStorage.Chars.Goko.backdash
		dist = char.HumanoidRootPart.CFrame.lookVector*-38
		if game["Run Service"]:IsServer() then
			speed = .5
			dist = CFrame.new(0,0,5.5)
			movetype = "knockback"
		else
			check = "dash"
		end
	elseif mode == "airfront" then
		speed = 0.2
		dist = char.HumanoidRootPart.CFrame.lookVector*25
		anim = game.ReplicatedStorage.Chars.Goko.airdash
		cold = 0.3
		if game["Run Service"]:IsServer() then
			dist = CFrame.new(0,0,-7)
			speed = 0.25
			movetype = "knockback"
		end
	elseif mode == "airback" then
		speed = 0.2
		dist = char.HumanoidRootPart.CFrame.lookVector*-25
		anim = game.ReplicatedStorage.Chars.Goko.airbackdash
		cold = 0.3
		if game["Run Service"]:IsServer() then
			speed = 0.25
			dist = CFrame.new(0,0,7)
			movetype = "knockback"
		end
	end
	return speed,dist,anim,movetype,cold,check
end


function module.handle(char,numpal,mode)
	--reduces meter gain to 90%
	char.vals.meter:SetAttribute("n",0.9)
end

return module