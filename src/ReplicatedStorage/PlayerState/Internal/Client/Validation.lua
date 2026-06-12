--!strict

local Validation = {}

-- Safety net so a slow/missing replica can't hang the boot forever.
-- Normal replica arrival is <2s; this only trips on genuine server failure.
local DEFAULT_TIMEOUT = 20

function Validation.ValidateReplica(replica: any?): boolean
	return replica ~= nil and replica:IsActive()
end

function Validation.WaitForData(dataReady: () -> boolean, validateReplica: (replica: any?) -> boolean, getReplica: () -> any?, timeout: number?): boolean
	local deadline = os.clock() + (timeout or DEFAULT_TIMEOUT)

	while not (dataReady() and validateReplica(getReplica())) do
		if os.clock() >= deadline then
			warn("[PlayerState] WaitForData timed out - player data never replicated")
			return false
		end
		task.wait(0.1)
	end

	return true
end

return Validation
