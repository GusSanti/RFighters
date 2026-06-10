local module = {}
local TS = game:GetService("TweenService")
local RunS = game:GetService("RunService")
local IsClient = RunS:IsClient()

local function multiply(input, factor, a)
	local type1, type2 = typeof(input), typeof(factor)
	if not a and type1 == type2 then return input end
	factor = type2 == "NumberRange" and math.lerp(factor.Min, factor.Max, math.random()) or factor

	if type1 == "number" then
		return input
	elseif type1 == "NumberSequence" then
		local kps = {}
		for i, kp in input.Keypoints do
			kps[i] = NumberSequenceKeypoint.new(kp.Time, kp.Value*factor, kp.Envelope)
		end

		return NumberSequence.new(kps)
	elseif type1 == "NumberRange" then
		return NumberRange.new(input.Min*factor, input.Max*factor)
	else
		return input*factor
	end
end

function module.reverse(tbl, d)
	local r, l = d and tbl or {}, #tbl
	for i=1,l do r[i] = tbl[l-i] end
	return r
end

function module.prettyCF(cf)
	return `CFrame[{cf.Position:Floor()} | {(vector.create(cf:ToEulerAnglesXYZ())*math.deg(1)):Floor()}]`
end

function module.spread(dir, spread, rng)
	local mag = dir.Magnitude
	if mag == 0 then return dir end

	local dir = dir.Unit
	local azimuth = math.rad(((rng and rng:NextNumber() or math.random()) * 2 - 1) * spread.Y)
	local elevation = math.rad(((rng and rng:NextNumber() or math.random()) * 2 - 1) * spread.X)

	local worldUp = Vector3.new(0, 1, 0)
	local right = dir:Cross(worldUp)
	if right.Magnitude == 0 then
		right = Vector3.new(1, 0, 0)
	else
		right = right.Unit
	end
	local up = right:Cross(dir).Unit

	local horiz = dir * math.cos(azimuth) + right * math.sin(azimuth)
	local finalDir = horiz * math.cos(elevation) + up * math.sin(elevation)

	return finalDir.Unit * mag
end

local lerp do
	local mergeTimes = function(aKps, bKps)
		local times, i, j, last = {}, 1, 1, -1
		local na, nb = #aKps, #bKps
		while i <= na or j <= nb do
			local ta = (i <= na) and aKps[i].Time or 2
			local tb = (j <= nb) and bKps[j].Time or 2
			local t
			if ta <= tb then
				t, i = ta, i + 1
			else
				t, j = tb, j + 1
			end
			if t - last > 1e-6 then
				times[#times+1], last = t, t
			end
		end
		if times[1] ~= 0 then table.insert(times, 1, 0) end
		if times[#times] ~= 1 then times[#times+1] = 1 end
		return times
	end

	local function sampleColor(kps, t)
		for i=1,#kps-1 do
			local a, b = kps[i], kps[i+1]
			if t <= b.Time then
				local alpha = (t - a.Time) / (b.Time - a.Time)
				return a.Value:Lerp(b.Value, alpha)
			end
		end
	end

	local function sample(kps, t, seed)
		t = math.clamp(t, 0,1)
		local typ = typeof(kps)
		if typ == "ColorSequence" then
			return sampleColor(kps.Keypoints, t)
		elseif typ == "NumberSequence" then
			kps = kps.Keypoints
		elseif typ == "table" then
			local z = typeof(kps[1])
			if z == "ColorSequenceKeypoint" then
				return sampleColor(kps, t)
			elseif z ~= "NumberSequenceKeypoint" then
				return kps
			end
		end
		
		seed = seed and 2*seed%1-1 or 0
		
		for i=1,#kps-1 do
			local a, b = kps[i], kps[i+1]
			
			if t <= b.Time then
				local av, u, ae = a.Value, (t-a.Time)/(b.Time-a.Time), a.Envelope
				local v, e = av+(b.Value-av)*u, (ae+(b.Envelope-ae)*u)*seed
				return v+math.min(math.abs(e), v)*math.sign(e)
			end
		end
	end module.sample, module.sampleColor = sample, sampleColor

	lerp = function(a, b, alpha, typ)
		typ = typ or typeof(a)
		if typ == "NumberRange" then
			return NumberRange.new(
				math.lerp(a.Min, b.Min, alpha),
				math.lerp(a.Max, b.Max, alpha)
			)
		elseif typ == "NumberSequence" then
			a, b = a.Keypoints, b.Keypoints
			local times = mergeTimes(a, b)
			for i, t in times do
				local va, ea = sample(a, t)
				local vb, eb = sample(b, t)
				times[i] = NumberSequenceKeypoint.new(t, math.lerp(va, vb, alpha), math.lerp(ea, eb, alpha))
			end
			return NumberSequence.new(times)
		elseif typ == "ColorSequence" then
			a, b = a.Keypoints, b.Keypoints
			local times = mergeTimes(a, b)
			for i, t in times do
				times[i] = ColorSequenceKeypoint.new(t, sampleColor(a, t):Lerp(sampleColor(b, t), alpha))
			end
			return ColorSequence.new(times)
		elseif typ == "Color3" then
			return a:Lerp(b, alpha)
		elseif typ == "number" then
			return math.lerp(a, b, alpha)
		end

		error("Unsupported type: " .. tostring(typ))
	end
end

local Tweening = {}
module.tween = function(Object, Info, Goals, Attributes, yield)
	if Tweening[Object] then Tweening[Object]() end

	local ServiceSupported = {}
	local Starts, RealGoals = {}, {}

	for Prop, Goal in Goals do
		local Start = if Attributes and Attributes[Prop] then Object:GetAttribute(Prop) else Object[Prop]
		Starts[Prop] = Start

		local startype = typeof(Start)
		if not (Attributes and Attributes[Prop]) and not startype:find("Sequence", 5, true) then
			ServiceSupported[Prop] = Goal continue
		end

		if typeof(Goal) == "number" and startype ~= "number" then
			RealGoals[Prop] = multiply(Start, Goal, true)
		else
			RealGoals[Prop] = Goal
		end
	end

	local Cancel
	local Conn, Tween, TConn if next(ServiceSupported) then
		Tween = TS:Create(Object,Info,ServiceSupported)
		Tween:Play(); TConn = Tween.Completed:Once(function(...)
			if Tweening[Object] ~= Cancel then return end
			Tweening[Object] = nil if yield then
				coroutine.resume(yield, ...)
			end
		end)
	end

	local Time, Style, Dir = Info.Time, Info.EasingStyle, Info.EasingDirection

	if next(RealGoals) then
		local Alpha = 0
		Conn = RunS.Heartbeat:Connect(function(delta)
			if Tweening[Object] ~= Cancel then return end

			Alpha += delta / Time
			for Prop, Goal in RealGoals do
				if Attributes and Attributes[Prop] then
					Object:SetAttribute(lerp(Starts[Prop], Goal, TS:GetValue(Alpha, Style, Dir)))
				else
					Object[Prop] = lerp(Starts[Prop], Goal, TS:GetValue(Alpha, Style, Dir))
				end
			end

			if Alpha >= 1 then
				Tweening[Object] = nil
				Conn:Disconnect() if yield then
					coroutine.resume(yield)
				end
			end
		end)
	end

	Cancel = function()
		if Conn then Conn:Disconnect() end
		if yield then coroutine.resume(yield) end
		if Tween then TConn:Disconnect() Tween:Cancel() end

		if Tweening[Object] == Cancel then
			Tweening[Object] = nil
		end
	end

	Tweening[Object] = Cancel

	if yield then
		yield = coroutine.running()
		return coroutine.yield()
	end

	return Cancel
end

module.lerp = lerp
module.tweening = Tweening
module.multiply = multiply
function module.num(n, d, rng)
	if type(n) == "userdata" then
		return rng and rng:NextNumber(n.Min, n.Max) or math.lerp(n.Min, n.Max, math.random())
	end return tonumber(n) or d
end

module.max = function(n, d)
	if type(n) == "userdata" then
		return n.Max
	end return tonumber(n) or d
end

module.defaultTo = function(t, d)
	return setmetatable(table.clone(t), {__index = d})
end

local round = math.round
module.convert = function(a, decode, typ, enum)
	typ = typ == "table" and "string" or typ

	if decode then
		if type(a) ~= "string" then return a end

		if enum then
			return enum[a]
		elseif typ == "number" then
			return tonumber(a) or a
		elseif typ == "Color3" then
			return Color3.fromRGB(unpack(a:split(":")))
		elseif typ == "Vector3" then
			return vector.create(unpack(a:split(";")))
		elseif typ == "boolean" then
			return (if a == "t" then true else (a ~= "f" and a))
		elseif typ == "Vector2" then
			return Vector2.new(unpack(a:split(";")))
		elseif typ == "NumberRange" then
			a = a:split("~")
			local m, mx = a[1], a[2]
			return NumberRange.new(tonumber(m), tonumber(mx))
		elseif typ == "EnumItem" then
			a = a:split(".")
			return Enum[a[1]][a[2]]
		end

		return a
	else
		if enum then
			return a.Name
		elseif typ == "boolean" then
			return a == true and "t" or "f"
		elseif typ == "number" then
			return string.gsub(tostring(round(a*100)/100), "^(0%.)", "."), nil
		elseif typ == "Color3" then
			return `{a.R*255//1}:{a.G*255//1}:{a.B*255//1}`
		elseif typ == "Vector3" then
			return string.gsub(`;{round(a.X*100)/100};{round(a.Y*100)/100};{round(a.Z*100)/100}`,";(0%.)", ";."):sub(2)
		elseif typ == "Vector2" then
			return string.gsub(`;{round(a.X*100)/100};{round(a.Y*100)/100}`,";(0%.)", ";."):sub(2)
		elseif typ == "NumberRange" then
			return string.gsub(`~{a.Min}~{a.Max}`,";(0%.)", ";."):sub(2)
		elseif typ == "EnumItem" then
			return a:gsub("^Enum%.", "")
		end

		return a
	end
end

local function NOP(...)return...end

function module.toHSV(c, hdr) -- because :ToHSV() doesnt support 255+ values
	if not hdr then return c:ToHSV() end
	
	local r, g, b = c.R, c.G, c.B
	local maxv = math.max(r, g, b)
	local minv = math.min(r, g, b)
	local delta = maxv - minv

	local h, s, v = 0, 0, maxv

	if delta > 0 then
		s = delta / maxv
		if maxv == r then
			h = (g - b) / delta
		elseif maxv == g then
			h = 2 + (b - r) / delta
		else
			h = 4 + (r - g) / delta
		end
		h = (h / 6) % 1
	end

	return h, s, v
end

function module.HSVtoHSL(h, s, v)
	local l = v * (1 - s/2)
	local s_l = (l == 0 or l == 1) and 0 or (v - l) / math.min(l, 1 - l)
	return h, s_l, l
end

function module.HSLtoHSV(h, s, l)
	local v = l + s * math.min(l, 1 - l)
	local s_v = (v == 0) and 0 or 2 * (1 - l/v)
	return h, s_v, v
end

function module.matchRaycastResult(x, rr)
	local parts = x:QueryDescendants("BasePart")
	if x:IsA("BasePart") then table.insert(parts, x) end

	for _, v in parts do
		local target, material = rr.Instance, rr.Material

		local color = target.Color
		if target:IsA("BasePart") then
			x.Reflectance, x.Transparency = target.Reflectance, target.Transparency
			for _, v in target:QueryDescendants(">Texture,>Decal") do v:Clone().Parent = x end
		elseif target:IsA("Terrain") then
			color = workspace.Terrain:GetMaterialColor(material)
		end x.Color, x.Material = color, material
	end
end

local pool = {} do
	pool.__index = pool
	local Collection = game:GetService("CollectionService")
	local Terrain, nowhere, z = workspace.Terrain, CFrame.new(0xFFFFFFFFFFFF, 0, 0)
	local temp = Terrain:FindFirstChild("TempVFX") or Terrain:FindFirstChildOfClass("Folder") or Terrain
	
	local noSync = {
		CFrame = true,
		Position = true
	}

	function pool.new(obj, expansion)
		local busy, free, self = {}, table.create(expansion or 3)
		
		local t, data = task.defer(function()
			while task.wait(10) do
				self.cleaning = true
				for v in free do
					v:Destroy()
				end table.clear(free)
				self.cleaning = nil
			end
		end), {}
		
		if obj:IsA("PVInstance") then
			local x = obj:Clone()
			local n = x:GetFullName()
			for _, v in x:QueryDescendants("BasePart") do
				data[v:GetFullName():gsub(n, "", 1)] = v.Anchored
			end if x:IsA("BasePart") then data.Anchored = x.Anchored end
		end
		
		local function sync(k, a)
			if a then
				local v = obj:GetAttribute(k)
				for x in busy do
					if not x:HasTag("DisabledVFX") then
						x:SetAttribute(k, v)
					end
				end
				for x in free do x:SetAttribute(k, v) end
			else
				local v = obj[k]
				for x in busy do
					if not x:HasTag("DisabledVFX") then
						x[k] = v
					end
				end
				for x in free do x[k] = v end
			end
		end
		
		obj.Changed:Connect(function(k)
			if not noSync[k] then pcall(sync, k) end
		end) obj.AttributeChanged:Connect(function(k)
			pcall(sync, k, true)
		end)
		
		self = setmetatable({
			obj = obj,
			busy = busy,
			data = data,
			free = free,
			expansion = expansion,
			model = obj:IsA("Model"),
			pv = obj:IsA("PVInstance"),
			instance = typeof(obj) == "Instance"
		}, pool) return self
	end

	function pool:expand(n)
		local obj, inst, busy, free, x = self.obj, self.instance, self.busy, self.free, nil
		
		for i=1,n or self.expansion or 3 do
			x = obj:Clone() if inst then
				x.Destroying:Once(function()
					if self.cleaning then return end
					if busy[x] then busy[x] = nil else free[x] = nil end
				end) x.DescendantAdded:Connect(function(c)
					local b = busy[x] if b then table.insert(b, c) end
				end) x.Parent = temp
			end self:give(x)
		end
		
		return self, x
	end

	function pool:give(x)
		local busy = self.busy
		local b = busy[x] if b then
			for _, v in b do
				v:Destroy()
			end busy[x] = nil
		end
		
		if self.instance then
			x:AddTag("PooledVFX")
			
			if self.pv then
				if self.model then
					for _, v in x:QueryDescendants("BasePart") do
						v.Anchored = true
					end
				end
				
				if self.data.Anchored == false then x.Anchored = true end
				x:PivotTo(nowhere)
			elseif x:IsA("Adornment") then
				x.Visible = false
			end
		else
			x._PooledVFX = true
		end
		
		self.free[x] = true
	end

	function pool:take()
		local free = self.free
		local x = free[1] if x == nil then
			_, x = self:expand()
		end
		
		self.busy[x], free[x] = {}, nil
		
		if self.instance then
			x:RemoveTag("PooledVFX")
			
			if self.pv then
				local d = self.data
				if self.model then
					local n = x:GetFullName()
					for _, v in x:QueryDescendants("BasePart") do
						v.Anchored = d[v:GetFullName():gsub(n, "", 1)]
					end
				end
				
				local anc = d.Anchored
				if anc ~= nil then x.Anchored = d.Anchored end
			end
		else
			x._PooledVFX = false
		end
		
		return x
	end

	function pool:clear(d)
		local free, busy = self.free, self.busy
		
		self.cleaning = true
		for v in busy do v:Destroy() end
		for v in free do v:Destroy() end
		table.clear(free) table.clear(busy)
		self.cleaning = nil
		
		if d then
			task.cancel(self.cleaner)
			table.clear(self) setmetatable(self)
		end
	end
end module.pool, module.NOP = pool, NOP

return module