local ACCURACY = 200

local function offset(rng, r)
	return Vector3.new(
		rng:NextNumber(-r, r),
		rng:NextNumber(-r, r),
		rng:NextNumber(-r, r)
	)
end

local function eval(pts, t, c, b, jagCount, jagRange, a, arcSpace)
	local n = #pts
	if n < 2 then return pts[1] end

	if arcSpace then
		a = math.clamp(a or 0, 0, 1)

		local cumulative = {0}
		local total = 0
		local prev = eval(pts, t, c, b, jagCount, jagRange, 0)

		for i = 1, ACCURACY do
			local tt = i / ACCURACY
			local p = eval(pts, t, c, b, jagCount, jagRange, tt)
			total += (p - prev).Magnitude
			cumulative[i + 1] = total
			prev = p
		end

		if total > 0 then
			for i = 1, #cumulative do
				cumulative[i] /= total
			end
		end

		local low, high = 1, ACCURACY + 1
		while low < high do
			local mid = math.floor((low + high) / 2)
			if cumulative[mid] < a then
				low = mid + 1
			else
				high = mid
			end
		end

		local idx = math.max(low - 1, 1)
		local l0 = cumulative[idx]
		local l1 = cumulative[idx + 1] or 1
		local segT = (l1 > l0) and ((a - l0) / (l1 - l0)) or 0

		a = ((idx - 1) + segT) / ACCURACY
	end

	if n == 2 then
		return pts[1]:Lerp(pts[2], math.clamp(a, 0, 1))
	end

	a = (a or 0) * (n - 1)

	local i = math.clamp(math.floor(a) + 1, 1, n - 1)
	local u = math.clamp(a - (i - 1), 0, 1)

	local T, C, B = t or 0, c or 0, b or 0
	local s = (1 - T) * 0.5

	local function tan(p0, p1, p2, out)
		local d0 = p1 - p0
		local d1 = p2 - p1
		if out then
			return s * ((1 + B)*(1 + C)*d0 + (1 - B)*(1 - C)*d1)
		else
			return s * ((1 + B)*(1 - C)*d0 + (1 - B)*(1 + C)*d1)
		end
	end

	local p0, p1 = pts[i], pts[i + 1]
	local m0 = (i == 1) and (p1 - p0) or tan(pts[i - 1], p0, p1, true)
	local m1 = (i + 1 == n) and (p1 - p0) or tan(p0, p1, pts[i + 2], false)

	local u2, u3 = u*u, u*u*u
	local pt =
		(2*u3 - 3*u2 + 1) * p0 +
		(u3 - 2*u2 + u) * m0 +
		(-2*u3 + 3*u2) * p1 +
		(u3 - u2) * m1

	if jagCount > 0 then
		local jt = a / (n - 1) * jagCount
		local k = math.floor(jt)
		local rng = Random.new(k)
		local o0 = (k <= 0 or k >= jagCount) and Vector3.zero or offset(rng, jagRange)
		local o1 = (k+1 <= 0 or k+1 >= jagCount) and Vector3.zero or offset(rng, jagRange)
		pt += o0:Lerp(o1, jt - k)
	end

	return pt
end

return eval