local _ = [=[
v1.0

Preamble.

This is the license of the VFX Module of the plugin.

  - You are allowed to use the module commercially in your games.

  - You can modify and distribute your version as long as the license is retained.

  - If you violate the license you are required to stop use and distribution of
  the module and any Derivative Work and you may be terminated from using the plugin.

End of Preamble.

1. Definitions
  - "We" or "Us" refers to the copyright holder.
  - "You" means any individual exercising the rights of this license.
  - "Module" means the source code that is used to play vfx in-game and any compiled form of it.
  - "Derivative Work" means any work based on, derived from, or incorporating the Module.
  - "Plugin" the plugin that is used to create VFX to emit using this Module. (https://vfxer.pages.dev/plugin)

2. Grant of Rights
  - You may distribute the Module or Derivative Works **only** if you include an unaltered copy of this license.
  - You may use the Module **only** in Roblox game context (including roblox studio playtest) and not through plugins.
  - Derivative Works must **not** be branded or presented as the original and must give credit to the copyright holder.

3. Conditions
  - You must comply with and accept the terms of any add-ons you install or use.
  - Every copy, version, and Derivative Work must include an unaltered copy of this license and must **only**
  run in the context mentioned in Section 2, any other context like plugin or other developer tools are not allowed.

4. Warranty
  The Module is provided **"as is"**, without any warranty, express or implied,
  including merchantability, fitness for a particular purpose, or non-infringement.

5. Liability
  The copyright holder is not responsible for damages, losses, or legal claims,
  but will make reasonable efforts to correct reported problems when possible.

6. Termination
  This license ends automatically if you break any of its rules.
  Upon termination, you must stop all use and distribution of the Module and any Derivative Works.
  The copyright holder may also revoke your access to other tools (Plugin) or services they provide.
  We may also revoke or terminate your license at any time, for any reason.

7. Versioning
  The copyright holder may update the license with notice.
  Continuing to use any version of the Module or any Derivative Works after notice means
  you accept the new version of the license and must update the license in your version/copy.
]=]

--[===[--
	plugin: https://vfxer.pages.dev/plugin
	discord: https://discord.gg/XdZHsU9dNw
	license: https://github.com/fnuuy/vfx-plugin/LICENSE
	
	This module is not open-source and requires explicit permission to-
	use except to play VFX made with the plugin above in games (read license)
	though some add-ons can be open-source if they state that in their module.
	
	you are NOT allowed to edit/remove this comment or take anything from the module.

	read the documentation: https://vfxer.gitbook.io/plugin

	by: @fnuuy (discord)
--]===]--

local API = {}
local Terrain = workspace.Terrain
local RunS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local temp = Terrain:FindFirstChild("TempVFX")
local Collection = game:GetService("CollectionService")
if not RunS:IsClient() then error(`[vfx]: this module should be used on client side`) end

if temp then
	temp:ClearAllChildren()
else
	temp = Instance.new("Folder")
	temp.Name, temp.Parent = "TempVFX", Terrain
end

local util = require(script.util)
local emitters, enablers, disablers, spc, maid = {}, {}, {}, {}, {}
local NOP, num, max, multiply = util.NOP, util.num, util.max, util.multiply

API.temp = temp
local function stash(c) table.insert(maid, c) return c end

stash(temp.AncestryChanged:Connect(function(_, parent)
	if parent == Terrain then return end
	temp.Parent = Terrain
end))

local VFXClasses = {
	Beam = true,
	Decal = true,
	Trail = true,
	SpotLight = true,
	PointLight = true,
	SurfaceLight = true,
	ParticleEmitter = true
}
local ContainerClasses = {
	Part = true,
	Model = true,
	Folder = true,
	MeshPart = true,
	Attachment = true
}
local OtherClasses = {
	Sound = true,
	Highlight = true,
	ObjectValue = true,
	ModuleScript = true
}

local AllClasses = {}
for k, v in VFXClasses do
	AllClasses[k] = v
end for k, v in ContainerClasses do
	AllClasses[k] = v
end for k, v in OtherClasses do
	AllClasses[k] = v
end

local getCFrame
local emit, enable, disable
local enabled, looping = {}, {}

local function emit1(vfx, attrs, repeating, n)
	if not game:IsAncestorOf(vfx) then return end
	
	for _, f in emitters do
		task.spawn(f, vfx, attrs, repeating)
	end

	local class = vfx.ClassName
	local Duration = attrs.EmitDuration
	if ContainerClasses[class] and not attrs.EmitBreak then
		local children = vfx:GetChildren()
		local RandomPicks = attrs.EmitRandom

		if RandomPicks then
			local len = #children
			local max = attrs.MaxPicks
			local picked = max and {}
			for i=1,num(RandomPicks, 1, true) do
				local v = children[math.random(len)]
				while picked and picked[v] >= max do
					v = children[math.random(len)]
				end

				emit(v, nil, repeating)
			end
		else
			for _, v in children do
				if v.Name:sub(1, 6) ~= "EmitOn" then
					emit(v, nil, repeating)
				end
			end
		end
		
		if Duration == nil then return end
	end

	if class == "ModuleScript" then
		task.spawn(function()
			local f = require(vfx)
			if f and type(f) == "function" then
				task.spawn(f, attrs, repeating)
			elseif repeating then
				warn(`A script that emits more than once ({vfx:GetFullName()}) must return a function`)
			end return
		end)
	end

	if class == "ParticleEmitter" then
		local count = num(attrs.EmitCount, 0)
		if count >= 0.5 then vfx:Emit(count) end
		attrs._EmitCount = count
	elseif class == "Sound" and not Duration then
		if attrs.Clone then
			local clone = vfx:Clone()
			clone.Parent = vfx.Parent
			vfx = clone

			task.delay(vfx.TimeLength/vfx.PlaybackSpeed, vfx.Destroy, vfx)
		end

		vfx:Play() return
	elseif class == "ObjectValue" then
		local obj = vfx.Value if obj and obj:IsAncestorOf(vfx) and obj.ClassName ~= "ObjectValue" then
			local r = obj:GetAttributes() for k, v in attrs do
				if k:sub(1, 10) == "EmitRepeat" then continue end
				r[k] = v
			end

			r._ObjectValue = vfx
			emit(obj, r, repeating)
		end return
	end

	if Duration and not looping[vfx] then
		Duration = num(Duration, 0)
		
		if Duration == -1 then
			enable(vfx, attrs, repeating, n)
			return
		end
		
		local Sub = vfx:HasTag("SubVFX");
		(Sub and task.defer or task.spawn)(function()
			if Sub then
				Duration = attrs.EmitDuration or Duration
			end attrs._EmitDuration = Duration
			
			if attrs.Clone == true then
				attrs.Clone = 1
				local clone = vfx:Clone()
				clone:SetAttribute("Clone", 1)
				clone.Parent = vfx.Parent
				enable(clone, attrs, repeating)
				task.wait(Duration)
				disable(clone, attrs, repeating)
				clone:Destroy()
			else
				enable(vfx, attrs, repeating, n)
				task.wait(Duration)
				disable(vfx, attrs, repeating, n)
			end
		end)
	end
end

local Repeating = {}
function emit(vfx, attrs, repeating, n, nn)
	if vfx == API then -- to make :emit() work
		vfx, attrs, repeating, n = attrs, repeating, n, nn
	end
	
	local nodelay = attrs == 0
	attrs = not nodelay and attrs or vfx:GetAttributes()
	local DELAY = nodelay and 0 or num(attrs.EmitDelay, 0)
	local Repeat = num(attrs.EmitRepeat, 0, true)+1

	if Repeat > 1 then
		local RepeatDelay = attrs.EmitRepeatDelay or 0.1

		task.delay(DELAY, function()
			local s = (Repeating[vfx] or 0)+1
			Repeating[vfx] = s

			for i=1,Repeat do
				if Repeating[vfx] ~= s or vfx.Parent == nil then return end
				if not game:IsAncestorOf(vfx) then break end

				emit1(vfx, attrs, i < Repeat)
				local dly = num(RepeatDelay, 0.5)
				if dly >= 0.02 then task.wait(num(dly)) end
			end

			Repeating[vfx] = nil
		end) return attrs
	end

	if DELAY < 0.02 then
		emit1(vfx, attrs, repeating, n)
	else
		task.delay(DELAY, emit1, vfx, attrs, repeating, n)
	end
	
	return attrs
end

local Enableable = table.clone(VFXClasses)
Enableable.Decal, Enableable.Highlight = nil, true

local function enable1(vfx, attrs, repeating, n)
	if not game:IsAncestorOf(vfx) then return end
	n = n or (enabled[vfx] or 0)+1
	enabled[vfx] = n

	for _, f in enablers do f(vfx, attrs, repeating, n) end

	local class = vfx.ClassName
	if ContainerClasses[class] and not attrs.EmitBreak then
		local children = vfx:GetChildren()
		local RandomPicks = attrs.EmitRandom

		if RandomPicks then
			local len = #children
			local max = attrs.MaxPicks
			local picked = max and {}
			for i=1,num(RandomPicks, 1, true) do
				local v = children[math.random(len)]
				while picked and picked[v] >= max do
					v = children[math.random(len)]
				end

				enable(v, nil, repeating)
			end return
		end

		for _, v in children do
			if v.Name:sub(1, 6) ~= "EmitOn" then
				enable(v, nil, repeating)
			end
		end return
	elseif class == "ObjectValue" then
		local obj = vfx.Value if obj and obj:IsAncestorOf(vfx) and obj.ClassName ~= "ObjectValue" then
			local r = obj:GetAttributes() for k, v in attrs do
				if k:sub(1,10) == "EmitRepeat" then continue end
				r[k] = v
			end

			enable(obj, r, repeating)
		end return
	end

	if Enableable[class] then
		vfx.Enabled = true
	elseif class == "Sound" then
		vfx.TimePosition, vfx.Looped, vfx.Playing = attrs.StartTime or 0, true, true
	end
end

local function disable1(vfx, attrs, repeating, n)
	do
		local c = enabled[vfx]
		if not c or (n and n ~= c) then return end
		n = n or c
	end
	
	local class = vfx.ClassName
	local edd = vfx:HasTag("SequencedVFX") and max(attrs.OutTime, 0.5)
	enabled[vfx] = nil
	
	if edd then
		for _, f in disablers do
			if spc[f] then
				f(vfx, attrs, repeating, n)
			end
		end task.wait(num(edd))
	end
	
	for _, f in disablers do
		if not (edd and spc[f]) then
			f(vfx, attrs, repeating, n)
		end
	end

	if ContainerClasses[class] and not attrs.EmitBreak then
		for _, v in vfx:GetChildren() do
			task.spawn(disable, v, nil, repeating)
		end return
	elseif class == "ObjectValue" then
		local obj = vfx.Value if obj and obj:IsAncestorOf(vfx) and obj.ClassName ~= "ObjectValue" then
			local r = obj:GetAttributes() for k, v in attrs do
				if k:sub(1,10) == "EmitRepeat" then continue end
				r[k] = v
			end

			disable(obj, r, repeating)
		end return
	end

	local IsSound = class == "Sound"
	local IsClone = attrs.Clone == 1
	
	if Enableable[class] then
		vfx.Enabled = false
	elseif IsSound then
		vfx.Playing = false
	end

	if vfx:HasTag("OneTimeVFX") then
		vfx:AddTag("DisabledVFX")
	end
end

function enable(vfx, attrs, repeating, n)
	if enabled[vfx] or looping[vfx] then return end
	vfx:AddTag("EnabledVFX")
	
	attrs = attrs or vfx:GetAttributes()
	if attrs.EmitRepeat == -1 and attrs.Clone ~= 1 then
		if looping[vfx] then return end
		stash(task.spawn(function()
			local i = 0
			looping[vfx] = true
			attrs = nil --<| remove attributes cache to get new

			repeat
				i += 1
				if vfx.Parent == nil then return end
				if looping[vfx] == nil or not vfx.Parent or vfx:GetAttribute("EmitRepeat") ~= -1 then
					break
				end

				local dly = num(vfx:GetAttribute("EmitRepeatDelay"), 0.1)
				task.spawn(emit1, vfx, attrs or vfx:GetAttributes(), dly) task.wait(dly)
			until nil

			looping[vfx] = nil
		end)) return
	end
	
	enable1(vfx, attrs, repeating, n) return attrs
end

function disable(vfx, attrs, repeating, n)
	vfx:RemoveTag("EnabledVFX")
	attrs = attrs or vfx:GetAttributes()
	
	if looping[vfx] then
		looping[vfx] = nil
		return
	end

	local toEmit = vfx:FindFirstChild("EmitOnDisable")
	if toEmit then emit(toEmit) end

	disable1(vfx, attrs, repeating, n) return attrs
end

local function getDefault(d, f, k,...)
	local v = f and f(k,...)
	return (if v == nil then d[k] else v)
end

local conv = util.convert
-- CSV is Comma Seperated Values attributes (like impact frames)
local function get1CSV(t, s, map, d, f, enums, ...)
	if not t then return end t = t:split(",")

	local v, dflt = t[table.find(map, s)], getDefault(d, f, s, t, ...)
	return (if v == "" or v == nil then dflt else conv(v, true, typeof(dflt), enums and enums[s]))
end

local function getCSV(t, map, d, f, enums, ...)
	if not t then return end t = t:split(",")

	for k, s in map do
		local v, dflt = t[k], getDefault(d, f, s, t, ...)
		t[k] = if v == "" or v == nil then dflt else conv(v, true, typeof(dflt), enums and enums[s])
	end

	return t
end

local EffectSelector = ".VFX"

for k in VFXClasses do
	EffectSelector ..= ","..k
end for k in OtherClasses do
	EffectSelector ..= ","..k
end

local function getEffects(a, t)
	t = t or {}
	if type(a) == "table" then
		for _, v in a do
			local class = v.ClassName
			if VFXClasses[class] or OtherClasses[class] or v:HasTag("VFX") then
				table.insert(t, v)
			end

			for _, x in v:QueryDescendants(EffectSelector) do
				table.insert(t, x)
			end
		end

		return t
	end

	do
		local class = a.ClassName
		if VFXClasses[class] or OtherClasses[class] or a:HasTag("VFX") then
			table.insert(t, a)
		end
	end

	for _, v in a:QueryDescendants(EffectSelector) do
		table.insert(t, v)
	end

	return t
end

function getCFrame(obj, class)
	class = class or obj.ClassName

	if class == "Beam" then
		local att = obj.Attachment0 or obj.Attachment1
		return att and att.WorldCFrame
	elseif class == "Folder" or not ContainerClasses[class] then
		local p = obj:FindFirstAncestorOfClass("Attachment")
		local att = p ~= nil
		p = p or obj:FindFirstAncestorWhichIsA("PVInstance")

		if not p then return end
		if p:IsA("Model") then return p:GetPivot() end
		return p[att and "WorldCFrame" or "CFrame"]
	end

	return obj[class == "Attachment" and "WorldCFrame" or "CFrame"]
end

function API.getSize(obj)
	return obj:IsA("Model") and obj:GetExtentsSize() or obj:IsA("Attachment") and vector.zero or obj.Size
end

local HSLtoHSV, HSVtoHSL = util.HSLtoHSV, util.HSVtoHSL

local function adjCntrst(c, f, clamp)
	return clamp((c - 0.5) * (f+1) + 0.5, 0, 1)
end

local function adjustColor(Color, H,S,L,C, HDR)
	if typeof(Color) == "ColorSequence" then
		local k = Color.Keypoints
		for i, v in k do k[i] = ColorSequenceKeypoint.new(v.Time, adjustColor(v.Value, H,S,L,C, HDR)) end
		return ColorSequence.new(k)
	end

	H, S, L, C = H or 0, (S or 0)/100, (L or 0)/100, (C or 0)/100
	local hdr = HDR and math.max(1, Color.R, Color.G, Color.B) or 1
	
	local h, s, v, l = util.toHSV(Color, HDR) -- HDR = support >255 values

	h, s, l = HSVtoHSL(h, s, v)
	local clmp = HDR and NOP or math.clamp
	s, l = clmp(s + S, 0, 1), clmp(l + L, 0, 1)
	h, s, v = HSLtoHSV((h + H/360) % 1, s, l)

	local r = Color3.fromHSV(h, s, v)
	HDR = HDR and NOP or math.clamp
	
	return Color3.new(
		adjCntrst(r.R*hdr, C, HDR),
		adjCntrst(r.G*hdr, C, HDR),
		adjCntrst(r.B*hdr, C, HDR)
	)
end

local function maxLifetime(a, noAttributes)
	local LongestLifetime = 0
	for _, v in a:GetDescendants() do
		local class = v.ClassName
		local IsPE = class == "ParticleEmitter"

		if IsPE or class == "Trail" then
			local lt = v.Lifetime
			lt = IsPE and lt.Max or lt

			if not noAttributes then
				lt += max(v:GetAttribute("EmitDelay"), 0)
				local dur = max(v:GetAttribute("EmitDuration"), 0)
				if dur == -1 then return nil end
				lt += dur
			end

			LongestLifetime = lt > LongestLifetime and lt or LongestLifetime
		end
	end

	return LongestLifetime
end

local function _destroy(a, cb)
	if cb(a) == true then return end
	a:Destroy()
end

local function destroy(a) a:Destroy() end

local function destroyAfter(a, dly, cb)
	dly = dly or maxLifetime(a)

	if dly >= 0.02 then
		task.delay(dly, cb and _destroy or destroy, a, cb)
	else
		if cb and cb(a) == true then return true end
		a:Destroy()
	end
end

API.destroyAfter = destroyAfter
function API.debris(a, b, ...)
	if a:IsA("BasePart") then a.Locked = true end
	a.Archivable, a.Parent = false, temp
	for _, v in a:GetDescendants() do v.Archivable = false end
	return b and destroyAfter(a, b, ...)
end

-- // Shifters \\ --
local PropertyClasses = {
	Width0 = "Beam",
	Width1 = "Beam",
	CurveSize0 = "Beam",
	CurveSize1 = "Beam",
	WidthScale = "Trail",
	TextureSpeed = "Beam",

	Volume = "Sound",
	PlaybackSpeed = "Sound",
	EmitCount = "ParticleEmitter",

	Size = "ParticleEmitter",
	Speed = "ParticleEmitter",
	RotSpeed = "ParticleEmitter",
	Acceleration = "ParticleEmitter",

	Drag = "ParticleEmitter",
	Rate = "ParticleEmitter",

	Lifetime = "ParticleEmitter",
	FlipbookFramerate = "ParticleEmitter"
}

local AttrNames = {
	EmitCount = true,
	EmitDelay = true,
	EmitRepeat = true,
	EmitDuration = true,
	EmitRepeatDelay = true
}

local function GETSET(a, b, c)
	if AttrNames[b] then
		if c ~= nil then
			a:SetAttribute(b, c)
		else
			return a:GetAttribute(b)
		end
	end

	if c ~= nil then
		pcall(function(t, k, v) t[k] = v end, a, b, c)
	else
		return a[b]
	end
end

local function ReDo(vfx, scale, origins, t, ers)
	scale = math.max(0.01, scale)
	
	if ers then
		for selector, funcs in ers do
			if origins then
				local o = origins[vfx]
				for _, f in funcs do o = f(vfx, scale, o) or o end
				origins[vfx] = o
			else
				for _, f in funcs do f(vfx, scale, false) end
			end

			for _, v in vfx:QueryDescendants(selector) do
				if origins then
					local o = origins[v]
					for _, f in funcs do o = f(v, scale, o) or o end
					origins[v] = o
				else
					for _, f in funcs do f(v, scale, false) end
				end
			end
		end
	end

	local effects = vfx:GetDescendants()
	table.insert(effects, vfx)

	for _, V in effects do
		local class = V.ClassName
		if AllClasses[class] == nil then continue end
		local Origins = origins and origins[V]

		for Property, var in t do
			local PC = PropertyClasses[Property]
			if PC and PC ~= class then continue end

			local ok, Origin if Origins then
				Origin = Origins[Property] if not Origin then
					ok, Origin = pcall(GETSET, V, Property)
					if not ok then continue end
					Origins[Property] = Origin
				end
			else
				ok, Origin = pcall(GETSET, V, Property)
				if not ok then continue end
				
				if origins then
					Origins = {[Property] = Origin}
					origins[V] = Origins
				end
			end
			
			if Origin == nil then continue end

			local t = typeof(Origin)
			local x = var and scale or 1/scale
			x = Property == "Acceleration" and x^2 or x

			if t == "NumberSequence" then
				local KPs = Origin.Keypoints

				for K, KP in KPs do
					KPs[K] = NumberSequenceKeypoint.new(KP.Time, KP.Value*x, KP.Envelope)
				end GETSET(V, Property, NumberSequence.new(KPs))
			elseif t == "NumberRange" then
				GETSET(V, Property, NumberRange.new(Origin.Min*x, Origin.Max*x))
			else
				GETSET(V, Property, Origin*x)
			end
		end
	end
end

local Retimes, Rescales = {
	EmitDelay = false,
	EmitDuration = false,
	EmitRepeatDelay = false,

	Drag = true,
	Rate = true,
	Speed = true,
	RotSpeed = true,
	Lifetime = false,
	Acceleration = true,
	FlipbookFramerate = true,

	TextureSpeed = true,
	PlaybackSpeed = true
}, {
	Size = true,
	Speed = true,
	Volume = true,
	Width0 = true,
	Width1 = true,
	WidthScale = true,
	Acceleration = true
}

local retimers = {}
function API.retime(vfx, scale, origins, x)
	local r = Retimes if x == 1 then
		r = table.clone(r)
		r.EmitDuration = nil
	end ReDo(vfx, scale, origins, r, retimers)
end

local rescalers = {}
API.rescale, API.redo = function(vfx, scale, origins)
	ReDo(vfx, scale, origins, Rescales, rescalers)
end, ReDo

local recolorers = {}
local function gset(t,k,v) if v == nil then return t[k] end t[k] = v end

local function recolor1(v, p, h,s,l,c, Origins, origins, hdr)
	local ok, Origin if Origins then
		Origin = Origins[p] if not Origin then
			ok, Origin = pcall(gset, v, p)
			if not ok then return end
			Origins[p] = Origin
		end
	else
		ok, Origin = pcall(gset, v, p)
		if not ok then return end

		if origins then
			origins[v] = {[p] = Origin}
		end
	end

	v[p] = adjustColor(Origin, h,s,l,c, hdr)
end

function API.recolor(vfx, h,s,l,c, origins)
	for selector, funcs in recolorers do
		if origins then
			local o = origins[vfx]
			for _, f in funcs do o = f(vfx, h,s,l,c, o) or o end
			origins[vfx] = o
		else
			for _, f in funcs do f(vfx, h,s,l,c, false) end
		end

		for _, v in vfx:QueryDescendants(selector) do
			if origins then
				local o = origins[v]
				for _, f in funcs do o = f(v, h,s,l,c, o) or o end
				origins[v] = o
			else
				for _, f in funcs do f(v, h,s,l,c, false) end
			end
		end
	end

	for _, v in getEffects(vfx) do
		local class = v.ClassName
		local hdr = class == "Decal"
		local Origins = origins and origins[v] -- instance origins

		local ColorAttr = Origins and Origins._Color or v:GetAttribute("Color")
		if ColorAttr then v:SetAttribute("Color", adjustColor(ColorAttr, h,s,l,c)) end

		if class == "Decal" then
			recolor1(v, "Color3", h,s,l,c, Origins, origins, true)
		elseif class == "Highlight" then
			recolor1(v, "FillColor", h,s,l,c, Origins, origins)
			recolor1(v, "OutlineColor", h,s,l,c, Origins, origins)
		else
			recolor1(v, "Color", h,s,l,c, Origins, origins)
		end
	end
end

local adders, noSelector = {
	emit = emitters,
	enable = enablers,
	disable = disablers,
	recolor = recolorers,
	rescale = rescalers,
	retime = retimers
}, {
	emit = true,
	enable = true,
	disable = true
}

function API.add(t, selector, pre)
	selector, pre = selector or t.selector or "Instance", pre or t.pre

	for k, f in t do
		local adder = adders[k]
		if not adder then continue end
		if pre then spc[f] = pre end
		
		if noSelector[k] then
			table.insert(adder, f)
			continue
		end

		local g = adder[selector]
		if g == nil then g = {} adder[selector] = g end
		table.insert(g, f)
	end
end

local function OnTag(tag, add, remove)
	local conns = {}
	stash(Collection:GetInstanceRemovedSignal(tag):Connect(function(v)
		local c = conns[v]
		local t = typeof(c)
		conns[v] = nil if remove then remove(v) end
		if t == "RBXScriptConnection" then c:Disconnect() elseif t == "function" then c() end
	end)) stash(Collection:GetInstanceAddedSignal(tag):Connect(function(v) conns[v] = add(v) end))
	task.defer(function() for _, v in Collection:GetTagged(tag) do conns[v] = add(v) end end)
end

API.classes, API.getset = {
	all = AllClasses,
	vfx = VFXClasses,
	other = OtherClasses,
	container = ContainerClasses
}, GETSET

API.util, API.onTag = util, OnTag
API.enabled, API.looping = enabled, looping

API.getCFrame = getCFrame
API.getEffects = getEffects
API.adjustColor = adjustColor
API.maxLifetime = maxLifetime
API.csv, API.csv1 = getCSV, get1CSV
API.emit, API.enable, API.disable = emit, enable, disable

local bulkParts, bulkCFrames = {}, {}
function API.moveTo(part, cf, override)
	
	local k = not override and table.find(bulkParts, part)
	
	if k then
		bulkCFrames[k] *= part.CFrame:Inverse()*cf
	else
		table.insert(bulkParts, part)
		table.insert(bulkCFrames, cf)
	end
end

stash(RunS.Heartbeat:Connect(function()
	if #bulkParts > 0 then
		workspace:BulkMoveTo(bulkParts, bulkCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(bulkParts) table.clear(bulkCFrames)
	end
end))

setmetatable(API, { __index = util })
if shared.vfx == nil then shared.vfx = API end shared.fx = API

for _, v in script.addons:GetChildren() do
	task.spawn(function(m) API[m.Name] = require(m) end, v)
end

function API.log(m, t)
	(t == 2 and warn or t == 3 and error or print)("[vfx]:", m)
end

task.delay(3, OnTag, "EnabledVFX", enable, disable)

OnTag("ScaleVFX", function(part)
	if not part:IsA("BasePart") then return end
	local last, sizing = part.Size.Magnitude, nil
	return stash(part:GetPropertyChangedSignal("Size"):Connect(function()
		sizing = true
		local mag = part.Size.Magnitude
		API.rescale(part, mag/last)
		last, sizing = mag, nil
	end))
end)

OnTag("ColorVFX", function(part)
	if not part:IsA("BasePart") then return end
	local H, S, L, Coloring = HSVtoHSL(part.Color:ToHSV())
	return stash(part:GetPropertyChangedSignal("Color"):Connect(function()
		Coloring = true
		local h, s, l = HSVtoHSL(part.Color:ToHSV())
		API.recolor(part, ((h - H + 0.5) % 1 - 0.5) * 360, (s - S) * 100, (l - L) * 100)
		H, S, L, Coloring = h, s, l, nil
	end))
end)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	for _, v in Collection:GetTagged("CurrentCamera") do
		if v:IsA("ObjectValue") then v.Value = workspace.CurrentCamera end
	end
end)

OnTag("CurrentCamera", function(obj)
	if obj:IsA("ObjectValue") then
		obj.Value = workspace.CurrentCamera
	end
end)

OnTag("PooledVFX", function(v) v:RemoveTag("UnPooledVFX") end, function(v) v:AddTag("PooledVFX") end)
return API