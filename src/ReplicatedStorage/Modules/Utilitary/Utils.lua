local Utils = {}

Utils.Particle_Setup = function(Data)
	local Holder = Data.Holder
	local Type = Data.Type or "Emit"

	local function Emit()
		for _, v in ipairs(Holder:GetDescendants()) do
			if v:IsA("ParticleEmitter") then
				local Duration = v:GetAttribute("EmitDuration") -- tempo em segundos
				local EmitAmount = v:GetAttribute("EmitCount") -- quantidade por acionamento

				if Duration and Duration > 0 then
					v.Enabled = false
					task.defer(function()
						v.Enabled = true
						task.delay(Duration, function()
							if v and v.Parent then
								v.Enabled = false
							end
						end)
					end)
				else
					v:Emit(EmitAmount)
				end
			end
		end
	end

	local function Enable()
		local ClassNames = {
			Beam = true,
			ParticleEmitter = true,
			Trail = true,
		}
		for _, v in ipairs(Holder:GetDescendants()) do
			if ClassNames[v.ClassName] then
				v.Enabled = Data.Bool
			end
		end
	end

	local Funcs = {
		Emit = Emit,
		Enable = Enable,
	}

	coroutine.wrap(Funcs[Type])()
end

return Utils
