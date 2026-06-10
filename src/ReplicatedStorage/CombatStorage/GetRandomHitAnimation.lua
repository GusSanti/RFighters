local module = {}

local AnimationFolder = script.Parent.GlobalAnimations

local HitAnims = {
	AnimationFolder.high,
	AnimationFolder.low,
	AnimationFolder.mid,
	AnimationFolder.extramid,
	AnimationFolder.extrahigh,
	AnimationFolder.extramid2
}

function module.GetRandom()
	return HitAnims[math.random(1, #HitAnims)]
end

return module
