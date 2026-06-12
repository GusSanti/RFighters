local api = shared.fx
local tag = "SplineVFX"
local tcb = require(script.TCB)

local defaults = {
	Duration = NumberRange.new(1),
	DestroyDelay = 0,
	FinishOnDisable = false,
	FacePath = true,
	ArcSpace = false,
	Easing = NumberSequence.new(0, 1),
	MirrorPath = false,
	Reverse = false,

	PoolObject = true,
	SyncPosition = true,
	SpreadAngle = Vector2.zero,
	EmissionDirection = Enum.NormalId.Top,
	DisableTrailsOnFinish = true,

	Shape = Enum.ParticleEmitterShape.Box,
	ShapePartial = 1,
	SharedEndThreshold = NumberRange.new(1),
	ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,

	Tension = NumberRange.new(0),
	Continuity = NumberRange.new(0),
	Bias = NumberRange.new(0),
	Jaggedness = NumberRange.new(0),
	JaggedRange = NumberRange.new(0, 5),
	Variance = Vector3.one,

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
	ExcludeTempVFX = true
}

if not api.ui then
	for k, v in defaults do
		if type(v) == "table" then
			defaults[k] = v[1]
		end
	end
end

local function is(vfx)
	return vfx:HasTag(tag)
end

local DIR_NORMALS = {
	[0] = vector.create(1, 0, 0),
	[3] = vector.create(-1, 0, 0),
	[1] = vector.create(0, 1, 0),
	[4] = vector.create(0, -1, 0),
	[5] = vector.create(0, 0, -1),
	[2] = vector.create(0, 0, 1)
}

local function pointIn(shape, surface, inout, partial, size, rng, attrs)
	surface = surface == "Surface"
	local dir = attrs.EmissionDirection.Value
	
	if shape == "Sphere" then
		local yAxis = DIR_NORMALS[dir]

		local xAxis = Vector3.yAxis:Cross(yAxis)
		xAxis = (xAxis.Magnitude > 0 and xAxis.Unit) or Vector3.xAxis
		local zAxis = yAxis:Cross(xAxis)

		local rx, ry, rz = size.X/2, size.Y/2, size.Z/2

		local ang = rng:NextNumber() * math.pi * 2
		local u, v = rng:NextNumber(), rng:NextNumber()

		local cosTheta = 1 - 2*u
		local sinTheta = math.sqrt(1 - cosTheta*cosTheta)

		local r = surface and 1 or v^(1/3)

		cosTheta = (1 - partial) + partial * cosTheta
		sinTheta = math.sqrt(math.max(0, 1 - cosTheta*cosTheta))

		local lx = math.cos(ang) * sinTheta * r
		local ly = cosTheta * r
		local lz = math.sin(ang) * sinTheta * r

		return
			xAxis * (lx * rx) +
			yAxis * (ly * ry) +
			zAxis * (lz * rz)
	elseif shape == "Cylinder" then
		local axis, sign = nil, 1
		if dir == 0 then axis, sign = "Z", 1 
		elseif dir == 1 then axis, sign = "X", 1
		elseif dir == 2 then axis, sign = "X", -1
		elseif dir == 3 then axis, sign = "Z", -1
		else
			axis, sign = "X", 1
		end

		local h = (axis == "X" and size.X or size.Z)/2
		local r1 = (axis == "X" and size.Y or size.X)/2
		local r2 = (axis == "X" and size.Z or size.Y)/2

		local offsetFront = -h * sign
		local offsetBack  = h * sign

		local offset, radiusScale
		local s = rng:NextNumber()
		offset = offsetFront + (offsetBack - offsetFront) * s
		radiusScale = (surface and 1 or math.sqrt(rng:NextNumber())) * (1 + (partial - 1) * s)

		local theta = rng:NextNumber() * math.pi * 2
		local y = math.cos(theta) * r1 * radiusScale
		local z = math.sin(theta) * r2 * radiusScale

		local pos = axis == "X" and vector.create(offset, y, z) or
			axis == "Z" and vector.create(y, z, offset) or vector.create(y, offset, z)

		return pos
	elseif shape == "Disc" then
		local rOuter, rInner = 1, 1-partial
		local offset = surface and ((dir==1 or dir==0 or dir==2) and 1 or 0) or rng:NextNumber()
		local r = math.sqrt(rInner^2 + rng:NextNumber()*(rOuter^2 - rInner^2))
		local theta = rng:NextNumber() * math.pi*2
		local rx, ry, rz = r*math.cos(theta), offset-0.5, r*math.sin(theta)

		if dir == 0 or dir == 3 then
			return vector.create(ry*size.X, rx*size.Y/2, rz*size.Z/2)
		elseif dir == 2 or dir == 5 then
			return vector.create(rx*size.X/2, rz*size.Y/2, ry*size.Z)
		else
			return vector.create(rx*size.X/2, ry*size.Y, rz*size.Z/2)
		end
	else
		local x = rng:NextNumber()*2-1
		local y = rng:NextNumber()*2-1
		local z = rng:NextNumber()*2-1

		if type(attrs) == "table" then
			partial = math.max(partial, 0.01)
			if surface then
				if dir == 1 or dir == 4 then
					y = (dir == 1) and 1 or -1
					x, z = x * partial, z * partial
				elseif dir == 0 or dir == 3 then
					x = (dir == 0) and 1 or -1
					y, z = y * partial, z * partial
				else
					z = (dir == 2) and 1 or -1
					x, y = x * partial, y * partial
				end
			else
				local t, s
				if dir == 1 or dir == 4 then
					t = (y + 1) / 2
					if dir == 4 then t = 1 - t end
					s = 1 + (partial - 1) * t
					x, z = x * s, z * s
				elseif dir == 0 or dir == 3 then
					t = (x + 1) / 2
					if dir == 3 then t = 1 - t end
					s = 1 + (partial - 1) * t
					y, z = y * s, z * s
				else
					t = (z + 1) / 2
					if dir == 5 then t = 1 - t end
					s = 1 + (partial - 1) * t
					x, y = x * s, y * s
				end
			end
		elseif surface then
			if dir == 1 or dir == 4 then
				y = (dir == 1) and 1 or -1
			elseif dir == 0 or dir == 3 then
				x = (dir == 0) and 1 or -1
			else
				z = (dir == 2) and 1 or -1
			end
		end

		return vector.create(x * size.X/2, y * size.Y/2, z * size.Z/2)
	end
end

local function emissionCF(cf, size, attrs, rng)
	local shape, partial = attrs.Shape.Name, attrs.ShapePartial
	local shapeOffset = pointIn(shape, attrs.ShapeStyle.Name, attrs.ShapeInOut.Name, partial, size, rng, attrs)
	local worldPos = cf:PointToWorldSpace(shapeOffset)

	local dirVal = attrs.EmissionDirection.Value
	local normal = -Vector3.FromNormalId((dirVal + 3) % 6)
	local rotBasis = CFrame.lookAt(vector.zero, normal).Rotation
	local face, cylinder = attrs.ShapeInOut.Name or "", shape == "Cylinder"

	if shape == "Box" and type(attrs) == "table" then
		local horizontal = shapeOffset-normal*shapeOffset:Dot(normal)
		if horizontal.Magnitude > 1e-4 then horizontal = horizontal.Unit end

		rotBasis = CFrame.lookAt(
			vector.zero,
			(normal+horizontal*(1-partial)*horizontal.Magnitude).Unit,
			math.abs(normal.Y) > 0.999 and Vector3.zAxis or Vector3.yAxis
		).Rotation
	elseif cylinder or shape == "Sphere" then
		local radialNormal = shapeOffset.Unit

		if face == "Inward" then
			radialNormal = -radialNormal
		elseif face == "InAndOut" and rng:NextInteger(0,1) == 1 then
			radialNormal = -radialNormal
		end

		if cylinder then
			local flat = vector.create(0, radialNormal.Y, radialNormal.Z)
			rotBasis = CFrame.lookAt(vector.zero, flat.Magnitude < 1e-4 and Vector3.zAxis or flat.Unit, Vector3.yAxis)
		else
			local up = math.abs(radialNormal.Y) > 0.999 and Vector3.zAxis or Vector3.yAxis
			rotBasis = CFrame.lookAt(vector.zero, radialNormal, up)
		end
	elseif face:find("Inward") or (face:find("InAndOut") and rng:NextInteger(0,1) == 1) then
		rotBasis = rotBasis * CFrame.Angles(math.pi,0,0)
	end

	local finalCF = CFrame.new(worldPos) * cf.Rotation * rotBasis
	local spreadRotation, spread = CFrame.identity, attrs.SpreadAngle
	
	if spread and spread ~= Vector2.zero then
		local spreadDir = api.spread(finalCF.LookVector, spread, rng)
		spreadRotation = finalCF.Rotation:Inverse() * CFrame.lookAt(vector.zero, spreadDir).Rotation
	end

	return finalCF*spreadRotation, shapeOffset
end

local function mirror(points)
	local n = #points
	if n < 2 then return points end
	local startPos = points[1]
	local endPos = points[n]
	local axis = endPos - startPos
	if axis.Magnitude < 0.001 then
		local rev = {}
		for i = n, 1, -1 do table.insert(rev, points[i]) end
		return rev
	end

	local axisUnit = axis.Unit
	local mirrored = {}
	for i = n, 1, -1 do
		local p = points[i]
		local op = p - startPos
		local proj = op:Dot(axisUnit) * axisUnit
		local rej = op - proj
		table.insert(mirrored, startPos + proj - rej)
	end

	return mirrored
end

local Collection = game:GetService("CollectionService")

local function getRaycastParams(attrs, df)
	local p, ft, col = RaycastParams.new(), attrs.FilterType, attrs.CollisionGroup
	p.FilterType, p.RespectCanCollide = Enum.RaycastFilterType[ft], attrs.RespectCanCollide
	local f, exc, inc = attrs.FilterTag, Collection:GetTagged(attrs.ForceInclude), attrs.ForceExclude

	if col ~= "" then
		p.CollisionGroup = col
	end if f ~= "" then
		p.FilterDescendantsInstances = Collection:GetTagged(f)
	end if inc ~= "" then
		p.IncludeInstances = Collection:GetTagged(inc)
	end for _, v in df do table.insert(exc, v) end
	p.ExcludeInstances, attrs.IgnoreWater = exc, attrs.IgnoreWater
	return p
end

local function getTemplate(vfx)
	for _, v in vfx:GetChildren() do
		if v:IsA("PVInstance") and not v.Name:find("EmitOn") then
			return v
		end
	end

	local o = vfx:FindFirstChild("ObjectValue")
	if o then return o.Value end
end

local HB = game:GetService("RunService").Heartbeat
local num, pools, loops, sample = api.num, {}, {}, api.sample

local function lookAtNoRoll(p, t, ocf)
	local l = (t - p).Unit
	return CFrame.Angles(math.asin(l.Y), math.atan2(-l.X, -l.Z), select(3, ocf:ToEulerAnglesXYZ()))+p
end

local function trigger(v, cf, dd)
	local c = v.ClassName if c == "ObjectValue" then
		v = v.Value
		c = v.ClassName
	end

	local at = c == "Attachment"
	if v:IsA("PVInstance") or at then
		v = v:Clone()
		if at then
			v.WorldCFrame = cf
		else
			v:PivotTo(cf)
		end

		api.debris(v, v:GetAttribute("DestroyDelay") or api.maxLifetime(v)+dd)
	end

	api.emit(v)
end

local function emit(vfx, attrs, enbling)
	if not (is(vfx) and workspace:IsAncestorOf(vfx)) then return end
	attrs, enbling = api.defaultTo(attrs, defaults), enbling == -1

	local template, rng = getTemplate(vfx), Random.new()
	if not template then api.log("You forgot to add a part/model in spline") return end

	local pts, endPt = {}, vfx:FindFirstChild("End")
	if endPt:IsA("ObjectValue") then endPt = endPt.Value end

	for _, pt in vfx:GetChildren() do
		local n = pt.Name
		if n:find("^%d+$") then table.insert(pts, pt) end
	end table.sort(pts, function(a, b) return a.Name < b.Name end)

	local att, face = vfx.ClassName == "Attachment", attrs.FacePath
	local t, c, b, jC, jR = attrs.Tension, attrs.Continuity, attrs.Bias, attrs.Jaggedness, attrs.JaggedRange

	local reverse = attrs.Reverse
	local castype, prms if attrs.HitboxEnabled then
		castype, prms = attrs.CastType, getRaycastParams(attrs, {vfx, attrs.ExcludeTempVFX and api.temp or nil})
	end

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

	local part, destroyDelay = template:IsA("BasePart"), attrs.DestroyDelay
	local arc, easing, variance = attrs.ArcSpace, attrs.Easing, attrs.Variance

	local finishDisable = attrs.FinishOnDisable
	local pool = attrs.PoolObject if pool then
		pool = pools[template] if not pool then
			pool = api.pool.new(template)
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

	local cf, shapeSize, objSize = api.getCFrame(vfx), api.getSize(vfx), api.getSize(template)

	local sync, n = attrs.SyncPosition, enbling and loops[vfx]
	local disableTrails, mirr = sync and attrs.DisableTrailsOnFinish, attrs.MirrorPath

	for i=1,api.num(attrs.EmitCount, 1) do
		task.spawn(function()
			local obj, lp = pool and pool:take() or template:Clone(), table.clone(pts)
			local e, dur, last = HB:Wait(), num(attrs.Duration), emissionCF(cf, shapeSize, attrs, rng)

			local size = objSize if part then
				obj:GetPropertyChangedSignal("Size"):Connect(function()
					size = obj.Size
				end)
			end

			for k, v in lp do
				lp[k] = last * (v.Position+v.CFrame:VectorToObjectSpace(variance*rng:NextNumber(-1,1)))
			end

			if endPt then
				table.insert(lp, last:PointToWorldSpace(endPt.Position):Lerp(endPt.WorldPosition, num(attrs.SharedEndThreshold, 0, rng)))
			end

			last = last.Position
			table.insert(lp, 1, last)
			local rot = obj:GetPivot().Rotation
			if reverse then last = lp[#lp] end
			obj:PivotTo(rot+last) api.debris(obj)

			if pool then
				task.wait()
				for _, v in obj:QueryDescendants("Trail") do
					local on = v:GetAttribute("WasEnabled")
					if on ~= nil then v.Enabled = on v:SetAttribute("WasEnabled") end
				end
			end

			local tt, c, b, jC, jR = num(attrs.Tension, 0, rng), num(attrs.Continuity, 0, rng), num(attrs.Bias, 0, rng), num(attrs.Jaggedness, 0, rng), num(attrs.JaggedRange, 0, rng)

			local lastCF, didHit = CFrame.identity, nil

			local function getDiagonal(s)
				return math.sqrt(s.X^2 + s.Y^2 + s.Z^2)
			end

			api.emit(obj) while true do
				local t = e/dur
				t = sample(easing, t)
				local llp = lp if sync then
					local new = att and vfx.WorldCFrame or vfx.CFrame

					llp = {} for i, p in lp do
						llp[i] = new:PointToWorldSpace(cf:PointToObjectSpace(p))
					end
				end

				local nxt = tcb(llp, tt-0.5, c, b, jC, jR, reverse and 1-t or t, arc)

				local s = face and lookAtNoRoll(last, nxt, lastCF) or rot+last
				if part then api.moveTo(obj, s) else obj:PivotTo(s) end
				lastCF = s

				if castype and e > 0.1 then
					local ir, rr = nxt-last, nil

					local dir = ir
					if castype ~= "Ray" and dir.Magnitude > 1024 then
						dir = dir.Unit*1023.9 -- shapecast limits = distance:1024, size:512
					end if castype ~= "Shape" then dir += dir.Unit*(size[face and "Z" or "Magnitude"]/2) end

					if castype == "Ray" then
						rr = workspace:Raycast(last-ir, dir, prms)
					elseif castype == "Block" then
						rr = workspace:Blockcast(s-ir, size:Min(vector.one*512), dir, prms)
					elseif castype == "Sphere" then
						rr = workspace:Spherecast(last-ir, math.min(getDiagonal(size)/2, 256), dir, prms)
					elseif castype == "Shape" then
						rr = workspace:Shapecast(obj, dir, prms)
					end

					if rr then
						local hit, n = rr.Position, rr.Normal

						for _, v in OnHit do
							trigger(v, CFrame.lookAlong(hit, -Vector3.zAxis, n), destroyDelay)
						end if attrs.DestroyOnHit then didHit = true e += HB:Wait() break end
					end
				end

				e += HB:Wait()
				if t >= 0.95 and (enbling or mirr) and loops[vfx] == n then
					e = 0 if mirr then
						lp, mirr = mirror(lp)
					else
						reverse = not reverse
					end HB:Wait()
				end

				if enbling then
					if loops[vfx] ~= n and (finishDisable or e > dur) then
						break
					end
				elseif e > dur then
					break
				end

				last = nxt
			end

			if disableTrails then
				for _, v in obj:QueryDescendants("Trail") do
					if pool then v:SetAttribute("WasEnabled", v.Enabled) end
					v.Enabled = false
				end
			end

			if not didHit then
				for _, v in Finish do
					trigger(v, last, destroyDelay)
				end
			elseif enbling then
				vfx:RemoveTag("EnabledVFX")
			end
			
			local Weld
			if part and sync and not att and destroyDelay > 0.07 then
				Weld = Instance.new("Weld")
				Weld.Part0, Weld.Part1 = vfx, obj
				Weld.C1 = obj.CFrame:Inverse()*vfx.CFrame
				obj.Massless, obj.Anchored = true, false
				Weld.Parent = obj
			end

			task.wait(destroyDelay)

			if pool then
				if Weld then Weld:Destroy() end
				
				if not disableTrails then
					for _, v in obj:QueryDescendants("Trail") do
						v:SetAttribute("WasEnabled", v.Enabled)
						v.Enabled = false
					end
				end pool:give(obj)
			else
				obj:Destroy()
			end
		end)
	end
end

api.add {
	emit = emit,
	enable = function(vfx, attrs)
		if is(vfx) then
			loops[vfx] = (loops[vfx] or 0)+1
			emit(vfx, attrs, -1)
		end
	end,
	disable = function(vfx, attrs)
		if is(vfx) then
			local n = loops[vfx] or 1
			loops[vfx] = n ~= 1 and n-1 or nil
		end
	end,
	selector = `.{tag}` -- :QueryDescendants(selector)
}

return {
	is = is,
	tag = tag,
	tcb = tcb,
	mirror = mirror,
	trigger = trigger,
	pointIn = pointIn,
	defaults = defaults,
	emissionCF = emissionCF,
	getTemplate = getTemplate,
	getRaycastParams = getRaycastParams
}