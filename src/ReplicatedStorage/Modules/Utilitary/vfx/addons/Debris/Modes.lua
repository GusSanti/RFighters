local TS, num = game:GetService("TweenService"), shared.fx.num

return {
	Orbit = function(t, cf, offset, c,h,hh,r,ax,o)
		if o then
			ax = cf:VectorToWorldSpace(ax)
		else
			cf *= CFrame.Angles(-math.pi/2, 0, 0)
		end
		
		cf *= CFrame.Angles(-math.pi/2, 0, 0)
		
		local theta = t*c*math.pi*2
		return cf.Position+CFrame.fromAxisAngle(ax, theta)*offset+vector.create(0, math.sin(theta)*hh+h*t)
	end,
	Tornado = function(t, cf, offset, c,h,hh,r,ax,o)
		r *= t+0.2
		local p = CFrame.Angles(0, t*c*math.pi*2, 0)*(vector.create(r, h, r) * r) + vector.create(0, t*h, 0)
		if o then p = (cf*CFrame.Angles(-math.pi/2, 0, 0)):VectorToWorldSpace(p) end
		return cf.Position+offset+p
	end,
	Wave = function(t, cf, offset, c,h,hh,r,ax,o)
		cf *= CFrame.Angles(-math.pi/2, 0, 0)
		return cf.Position+offset+(o and cf.YVector or Vector3.yAxis)*math.sin(t*c)*c
	end
}