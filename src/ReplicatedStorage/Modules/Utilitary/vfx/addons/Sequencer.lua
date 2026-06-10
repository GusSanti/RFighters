local api = shared.fx
local tag = "SequencedVFX"
local crv = api.genCurve or api.NOP
local RunS = game:GetService("RunService")

local supported, HB = {
	number = true,
	Color3 = true,
	Vector2 = true,
	Vector3 = true,
	NumberRange = true,
	NumberSequence = true
}, RunS.Heartbeat

local function is(vfx)
	return vfx:HasTag(tag)
end

local defaults, sample, waiting, mult, enabled = {
	ResetOnFinish = false,
	UseEmitDuration = true,
	InTime = NumberRange.new(0.5),
	OutTime = NumberRange.new(0.5)
}, api.sample, {}, api.multiply, api.enabled

local custom, num = {}, api.num

local mapi = {
	is = is,
	tag = tag,
	custom = custom,
	defaults = defaults,
	supported = supported
}

local function add(k, f, c)
	c = c or crv(NumberSequence.new(1), 0,2)
	
	defaults[k], custom[k] = c, f
	local ui = mapi.ui if ui then
		ui:add(k, c, "Custom")
			.MouseButton2Click:Connect(function()
			ui:set(k, c)
		end)
	end
end

local function enable(vfx, attrs, _, n, emit)
	local q = vfx:IsA("ObjectValue") and vfx.Value or vfx
	if not is(vfx) or q:HasTag("AlteringVFX") then return end
	
	attrs = api.defaultTo(attrs, defaults)
	local seqs, seed, A = {}, math.random(), {}
	local use = attrs.UseEmitDuration and attrs._EmitDuration
	
	local inTime = attrs.InTime
	local dur, orig = use or num(inTime), {}

	for k, v in attrs do
		if custom[k] then
			seqs[k] = v
		else
			local f = k:find("_Sequence", 1, true)

			if f then
				local a = k:byte() == 95
				k = k:sub(a and 2 or 1, f-1)
				local o = `{a and "_" or ""}{k}_Value`
				local w = a and attrs[k] or q[k]
				
				local t = typeof(w)
				if t ~= "number" and t ~= "Color3"
					and not (attrs[o] or custom[k]) then
					vfx:SetAttribute(o, w)
				end

				a, orig[k] = a and " "..k or nil, w
				seqs[a or k], A[k] = v, a
			end
		end
	end
	
	task.spawn(xpcall, function()
		q:AddTag("AlteringVFX")
		local t, off = 0, 0 while true do
			t += HB:Wait()
			local e = enabled[vfx]
			if (e and e ~= n) then break end
			
			for k, v in seqs do
				local at = k:byte() == 95 and k:sub(2)
				local f, o, a, s = custom[k], vfx:GetAttribute(k.."_Value"), off+t/dur/(use and 1 or 2), seed*#k
				o = type(o) ~= "number" and o
				
				if f then
					f(q, sample(v, a, s), orig, 1)
				else
					local x = sample(v, a, s)
					if k == "Size" then x = math.clamp(x, 0.01, 9999) end
					x = o and mult(o, x, true) or x
					if at then vfx:SetAttribute(at, x) else q[k] = x end
				end
			end
			
			if ((not e and not emit) or (emit and t > dur)) and not use and off == 0 then
				local outTime = attrs.OutTime
				t, dur, off = 0, inTime == outTime and dur or api.num(outTime), 0.5
			end
			
			if t > dur then
				if use or off ~= 0 then
					if attrs.ResetOnFinish then
						for x, t in orig do
							if type(x) == "string" then
								if x:byte() == 95 then
									vfx:SetAttribute(x, t)
								else
									q[x] = t
								end
							else
								for k, v in t do x[k] = v end
							end
						end
					end break
				elseif not (use or emit) then
					waiting[vfx], t, dur, off = coroutine.running(), 0, num(attrs.OutTime), 0.5
					coroutine.yield() waiting[vfx] = nil
				else
					break
				end
			end
		end q:RemoveTag("AlteringVFX")
	end, function(err)
		warn(err:sub(err:find(":")+1))
		q:RemoveTag("AlteringVFX")
	end)
end

for _, v in game:GetService("CollectionService"):GetTagged("AlteringVFX") do
	v:RemoveTag("AlteringVFX") -- remove altering vfx tag from ones that are like edited in studio/on going
end

api.add {
	emit = function(vfx, attrs)
		if not attrs.EmitDuration then
			enable(vfx, attrs, nil, api.enabled[vfx], true)
		end
	end,
	enable = enable, -- make emitting work even with no emitdruation using intime and outtime
	disable = function(vfx, attrs)
		if is(vfx) then
			local w = waiting[vfx]
			if w then coroutine.resume(w) end
		end
	end,
	selector = `.{tag}`,
	pre = true
}

task.delay(0.1, function()
	add("Retime", api.retime)
	add("Rescale", api.rescale)
end)

return mapi