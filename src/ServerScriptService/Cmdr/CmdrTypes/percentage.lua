-- Example custom type. A type module returns function(registry) and calls
-- registry:RegisterType(name, definition). Cmdr moves it to the replicated
-- root so the client gets it for parsing/autocomplete.
-- Copy this to make new types.
return function(registry)
	registry:RegisterType("percentage", {
		Transform = function(text: string)
			return tonumber(text)
		end,
		Validate = function(value: number?)
			if value == nil then
				return false, "Must be a number."
			end
			return value >= 0 and value <= 100, "Percentage must be between 0 and 100."
		end,
		Parse = function(value: number)
			return value
		end,
	})
end
