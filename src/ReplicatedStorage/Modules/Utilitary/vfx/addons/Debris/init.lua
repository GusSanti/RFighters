local api = shared.fx
local RunS = game:GetService("RunService")
local tag, modes = "DebrisVFX", require(script.Modes)

local defaults = {
	Mode = {"Physics", "Orbit", "Wave", "Tornado"},
	Lifetime = NumberRange.new(4, 6),
	DestroyDelay = 1,
	GroundDistance = 0,
	MatchGround = true,
	SyncPosition = true,
	Easing = NumberSequence.new(0, 1),

	Velocity = NumberRange.new(40, 80),
	WorldVelocity = vector.create(0, 50),
	AngularVelocity = vector.zero,
	
	Radius = NumberRange.new(4, 5),
	Height = NumberRange.new(10),
	
	Axis = vector.zero,
	SpinSpeed = NumberRange.new(5),
	HoverHeight = NumberRange.new(5),
	Cycles = NumberRange.new(4, 6),
	
	FacePath = 0,
	ObjectSpace = false,

	PoolObject = true,
	SpreadAngle = Vector2.zero,
	EmissionDirection = Enum.NormalId.Top,
	DisableTrailsOnFinish = true,

	Shape = Enum.ParticleEmitterShape.Sphere,
	ShapePartial = 0.5,
	ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,

	HitboxEnabled = false,
	DestroyOnHit = true,
	CastType = {"Ray", "Block", "Sphere", "Shape"},
	FilterTag = "",
	ForceExclude = "",
	ForceInclude = "",
	IgnoreWater = true,
	FilterType = {"Exclude", "Include"},
	CollisionGroup = "",
	RespectCanCollide = true,
	ExcludeTempVFX = true,

	["Toggle Physics"] = (api.toggleTag or api.NOP)("PhysicsVFX", true),
}

if not api.ui then
	for k, v in defaults do
		if type(v) == "table" then
			defaults[k] = v[1]
		end
	end
else
	task.wait()
end

local function is(vfx)
	return vfx:HasTag(tag)
end

local pools, Modes, splines = {}, require(script.Modes)
local simulate, num, HB = api.ui ~= nil, api.num, RunS.Heartbeat

repeat
	splines = api.Splines
	if not splines then task.wait(0.2) end
until splines

local getTemplate, getRaycastParams, trigger = splines.getTemplate, splines.getRaycastParams, splines.trigger

if simulate then
	local parts, stops = {}, {}
	
	function simulate(x)
		local all = x:QueryDescendants("BasePart")
		if x:IsA("BasePart") then table.insert(all, x) end
		for _, v in all do table.insert(parts, v) end

		local function stop(_, b)
			if b and workspace:IsAncestorOf(x) then return end
			
			for _, v in all do
				table.remove(parts, table.find(parts, v))
			end stops[x] = nil
		end stops[x] = stop

		x.AncestryChanged:Connect(stop) return stop
	end
	
	game:GetService("CollectionService"):GetInstanceRemovedSignal("UnPooledVFX"):Connect(function(x)
		local stop = stops[x]; if stop then stop() end
	end)

	local i, data = 0, api.settings.data HB:Connect(function(dt)
		i += 1 if i%3 ~= 0 and #parts > 0 then
			workspace:StepPhysics(dt*1.7*data.PhysicsTimeScale, parts)
		end
	end)

	api.onTag("PhysicsVFX", simulate)
else
	task.delay(1, function()
		local v = script.Debris
		v.Size = v:GetAttribute("Size_Value")*(api.Sequencer and 0.01 or 1)
	end)
	
end

local function spin(t, s, a)
	return s > 0 and CFrame.fromAxisAngle(a, t*math.rad(s)) or CFrame.identity
end

local function destroyObj(p, o, dd, finish, dTrails)
	if dTrails then
		for _, v in o:QueryDescendants("Trail") do
			if p then v:SetAttribute("WasEnabled", v.Enabled) end
			v.Enabled = false
		end
	end
	
	for _, v in finish do trigger(v, o:GetPivot().Position, dd) end
	
	task.wait(dd)
	if not dTrails then
		for _, v in o:QueryDescendants("Trail") do
			v:SetAttribute("WasEnabled", v.Enabled)
			v.Enabled = false
		end
	end
	
	if p then p:give(o) else o:Destroy() end
end

local matchRaycastResult = api.matchRaycastResult

api.add {
	emit = function(vfx, attrs)
		if not (is(vfx) and workspace:IsAncestorOf(vfx)) then return end
		local template = getTemplate(vfx) or script.Debris

		attrs = api.defaultTo(attrs, defaults)
		local mode, part, easing, disableTrails = attrs.Mode, template:IsA("BasePart"), attrs.Easing, attrs.DisableTrailsOnFinish
		local cf, shapeSize, objSize, rng = api.getCFrame(vfx), api.getSize(vfx), api.getSize(template), Random.new()

		local castype, prms if attrs.HitboxEnabled then
			castype, prms = attrs.CastType, getRaycastParams(attrs, {vfx, attrs.ExcludeTempVFX and api.temp or nil})
		end

		local pool = attrs.PoolObject if pool then
			pool = pools[template] if not pool then
				pool = api.pool.new(template):expand(api.max(attrs.EmitCount)*3)
				
				pools[template] = pool
				task.delay(1, function(p)
					while task.wait(5) do
						if vfx:GetAttribute("PoolObject") == false then
							p:clear() pools[template], p = nil break
						end
					end
				end, pool)
			end
		end
		
		local lifetime, wlrd, vel, ang, destroyDelay = attrs.Lifetime, attrs.WorldVelocity, attrs.Velocity, attrs.AngularVelocity, attrs.DestroyDelay

		local OnHit, Finish = {}, {}
		for _, v in vfx:GetChildren() do
			local n = v.Name
			if not n:find("EmitOn") then continue end

			if n:find("Hit") then
				table.insert(OnHit, v)
			end if n:find("Finish") then
				table.insert(Finish, v)
			end
		end
		
		local rps, objs, face, grndDist = RaycastParams.new(), {}, attrs.FacePath, attrs.GroundDistance
		rps.IgnoreWater, rps.FilterDescendantsInstances, rps.RespectCanCollide = true, {api.temp, vfx}, true
		local rr, d = attrs.MatchGround, cf.YVector*(grndDist ~= 0 and math.abs(grndDist) or (shapeSize.Y+3)*5)
		
		if grndDist > 0 then
			local z = workspace:Raycast(cf.Position+d/3, -d, rps)
			if z then cf = cf.Rotation+z.Position end
		end
		
		if rr then
			local d = cf.YVector*(grndDist ~= 0 and math.abs(grndDist) or (shapeSize.Y+3)*5)
			rr = workspace:Raycast(cf.Position+d/3, -d, rps)
		end
		
		if not pool and rr then
			template = template:Clone()
			matchRaycastResult(template, rr)
		end 
		
		for i=1,num(attrs.EmitCount, 1) do
			local p, parts = splines.emissionCF(cf, shapeSize, attrs, rng), nil
			local obj, lt = pool and pool:take() or template:Clone(), num(lifetime, 0, rng)
			
			obj:AddTag("SubVFX")
			if pool and rr then matchRaycastResult(obj, rr) end
			
			objs[obj] = parts or false
			if mode == "Physics" then
				local lv, angX = p.LookVector, ang*rng:NextNumber(-1, 1)
				
				parts = obj:QueryDescendants("BasePart")
				if obj:IsA("BasePart") then table.insert(parts, obj) end
				
				local vlc = lv*num(vel, 0, rng)+wlrd
				obj:PivotTo(face > 0 and CFrame.lookAlong(p.Position, vlc) or p)
				
				api.debris(obj) api.emit(obj).EmitDuration = lt
				for _, v in parts do v.AssemblyLinearVelocity, v.AssemblyAngularVelocity = vlc, angX end
				
				task.delay(lt, destroyObj, pool, obj, destroyDelay, Finish, disableTrails)
				if simulate then simulate(obj) end
			else
				task.spawn(function()
					obj.Anchored = true
					local func, offset, rot = Modes[mode], p.Position-cf.Position, CFrame.identity
					local ax, o = attrs.Axis.Magnitude == 0 and rng:NextUnitVector() or attrs.Axis, attrs.ObjectSpace
					local s, sync, cpin, seed = p.Rotation+cf.Position, attrs.SyncPosition, num(attrs.SpinSpeed, 0, rng), math.random()
					local c, h, hh, r = num(attrs.Cycles, 0, rng), num(attrs.Height, 0, rng), num(attrs.HoverHeight, 0, rng), num(attrs.Radius, 0, rng)
					
					ax = ax == vector.zero and rng:NextUnitVector() or ax
					local t, ss, last = HB:Wait(), s, func(api.sample(easing, 0, seed), s, offset, c,h,hh,r,ax,o)
					
					api.debris(obj) api.emit(obj).EmitDuration = lt
					
					while t < lt do
						if sync then
							local new = api.getCFrame(vfx)
							s = new:ToWorldSpace(cf:ToObjectSpace(ss))
						end
						
						local c = func(api.sample(easing, t/lt, seed), s, offset, c,h,hh,r,ax,o)
						
						if t < face then
							c = CFrame.lookAlong(c, c-last)
							last, rot = c.Position, c.Rotation
						else
							c = rot*spin(t, cpin, ax)+c
						end
						
						if part then api.moveTo(obj, c) else obj:PivotTo(c) end
						if objs[obj] == nil then return end t += HB:Wait()
					end
					
					destroyObj(pool, obj, destroyDelay, Finish, disableTrails)
				end)
			end
		end
		
		local f = face > 0 and mode == "Physics"
		
		if castype or f then
			local function getDiagonal(s)
				return math.sqrt(s.X^2 + s.Y^2 + s.Z^2)
			end
			
			local lasts, t, lt = {}, HB:Wait(), api.max(lifetime)
			for obj in objs do lasts[obj] = obj:GetPivot().Position end
			
			while t < lt and ((f and t < face) or next(objs)) do
				t += HB:Wait()
				for obj in objs do
					local c, rr = obj:GetPivot()
					local nxt, last = c.Position, lasts[obj]
					local dir, size = nxt-last, api.getSize(obj)
					
					if dir.Magnitude < 0.01 then continue end
					if f and t < face then obj:PivotTo(CFrame.lookAlong(nxt, dir)) end
					
					if castype ~= "Ray" and dir.Magnitude > 1024 then
						dir = dir.Unit*1023.9 -- shapecast limits = distance:1024, size:512
					end if castype ~= "Shape" then dir += dir.Unit*size.Magnitude/2 end
					
					if castype == "Ray" then
						rr = workspace:Raycast(last, dir, prms)
					elseif castype == "Block" then
						rr = workspace:Blockcast(c, size:Min(vector.one*512), dir, prms)
					elseif castype == "Sphere" then
						rr = workspace:Spherecast(last, math.min(getDiagonal(size)/2, 256), dir, prms)
					elseif castype == "Shape" then
						rr = workspace:Shapecast(obj, dir, prms)
					end
					
					if rr then
						local hit, n = rr.Position, rr.Normal

						for _, v in OnHit do
							trigger(v, CFrame.lookAlong(hit, -Vector3.zAxis, n), destroyDelay)
						end if attrs.DestroyOnHit then
							task.delay(destroyObj, pool, obj, destroyDelay, Finish, disableTrails)
							objs[obj] = nil
						end
					end lasts[obj] = nxt
				end
			end
		end
	end,
	

	selector = `.{tag}` -- :QueryDescendants(selector)
} -- selector & all functions in this table are optional

return {
	is = is,
	tag = tag,
	modes = modes,
	defaults = defaults
} -- shared.fx.CoolAddon[]
-- just "return nil" if no api