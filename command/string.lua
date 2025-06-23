---@class Cartethyia.Command.String.SubCommand
local StringSubCommands = {}


---@param state Cartethyia.State
---@param args string[]
function StringSubCommands.FIND(state, args)
	local str = args[1]
	local substr = args[2]
	local outvar = args[3]
	local reverse = args[4] == "REVERSE"

	if str and substr and outvar then
		local s = nil
		if reverse then
			local _, e = str:reverse():find(substr:reverse(), 1, true)
			if e then
				s = #str - e + 1
			end
		else
			s = str:find(substr, 1, true)
		end

		state:setVariable(outvar, (s or 0) - 1)
		return
	end

	state:error("STRING sub-command FIND requires 3 or 4 arguments.")
end

---@param state Cartethyia.State
---@param args string[]
function StringSubCommands.REPLACE(state, args)
	if #args < 4 then
		state:error("STRING sub-command REPLACE requires at least 4 arguments.")
		return
	end

	local from = args[1]
	local to = args[2]
	local outvar = args[3]
	local input = table.concat(args, "", 4)

	local escapedFrom = from:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
	local result = input:gsub(escapedFrom, to)
	state:setVariable(outvar, result)
end

-- FIXME: Use CMake regex
StringSubCommands.REGEX = {}

---@param state Cartethyia.State
---@param args string[]
function StringSubCommands.REGEX.MATCH(state, args)
	if #args < 3 then
		state:error("STRING sub-command REGEX MATCH requires at least 3 arguments.")
		return
	end

	state:warning("Cartethyia currently uses Lua pattern for matching and is not compatible with CMake!")
	local pattern = args[1]
	local output = args[2]
	local input = table.concat(args, "", 3)

	local matches = {string.find(input, pattern)}
	if #matches > 0 then
		local match0 = input:sub(matches[1], matches[2])
		state:setVariable("CMAKE_MATCH_COUNT", tostring(#matches - 2)) -- accomodate start and end sequence
		state:setVariable("CMAKE_MATCH_0", input:sub(matches[1], matches[2]))

		for i = 3, #matches do
			state:setVariable("CMAKE_MATCH_"..(i - 2), matches[i])
		end

		state:setVariable(output, match0)
	else
		state:setVariable("CMAKE_MATCH_COUNT", "0")
		state:setVariable(output, "")
	end
end

---@param state Cartethyia.State
---@param args string[]
function StringSubCommands.APPEND(state, args)
	if #args < 1 then
		state:error("STRING sub-command APPEND requires at least 1 argument.")
		return
	end

	local output = args[1]
	local input = table.concat(args, "", 2)
	state:setVariable(output, state:getVariable(output)..input)
end

---@param state Cartethyia.State
---@param args string[]
function StringSubCommands.PREPEND(state, args)
	if #args < 1 then
		state:error("STRING sub-command PREPEND requires at least 1 argument.")
		return
	end

	local output = args[1]
	local input = table.concat(args, "", 2)
	state:setVariable(output, input..state:getVariable(output))
end

---@param state Cartethyia.State
---@param args string[]
function StringSubCommands.CONCAT(state, args)
	if #args < 1 then
		state:error("STRING sub-command CONCAT requires at least 1 argument.")
		return
	end

	state:setVariable(args[1], table.concat(args, "", 2))
end

---@param state Cartethyia.State
---@param args string[]
function StringSubCommands.JOIN(state, args)
	if #args < 2 then
		state:error("STRING sub-command JOIN requires at least 2 arguments.")
		return
	end

	state:setVariable(args[2], table.concat(args, args[1], 3))
end

---@param state Cartethyia.State
---@param args string[]
function StringSubCommands.TOLOWER(state, args)
	if #args < 2 then
		state:error("STRING sub-command TOLOWER requires 2 arguments.")
		return
	end

	state:setVariable(args[2], args[1]:lower())
end

---@param state Cartethyia.State
---@param args string[]
function StringSubCommands.TOUPPER(state, args)
	if #args < 2 then
		state:error("STRING sub-command TOUPPER requires 2 arguments.")
		return
	end

	state:setVariable(args[2], args[1]:upper())
end

---@param state Cartethyia.State
---@param args string[]
function StringSubCommands.LENGTH(state, args)
	if #args < 2 then
		state:error("STRING sub-command LENGTH requires 2 arguments.")
		return
	end

	state:setVariable(args[2], #args[1])
end

---@param state Cartethyia.State
---@param args string[]
function StringSubCommands.SUBSTRING(state, args)
	if #args < 4 then
		state:error("STRING sub-command SUBSTRING requires 4 arguments.")
		return
	end

	local input = args[1]
	local begin = math.max(tonumber(args[2]) or 0, 0)
	local length = math.max(tonumber(args[3]) or 0, -1)
	if length <= -1 then
		length = #input
	end
	state:setVariable(args[4], input:sub(1 + begin, begin + length))
end

-- TODO: STRIP sub-command

---@param state Cartethyia.State
---@param args string[]
function StringSubCommands.REPEAT(state, args)
	if #args < 3 then
		state:error("STRING sub-command REPEAT requires 3 arguments.")
		return
	end

	local input = args[1]
	local count = math.max(tonumber(args[2]) or 0, 0)
	local output = args[3]
	local sep = ""

	-- Cartethyia extension
	if args[4] == "SEPARATOR" then
		sep = args[5] or ""
	end

	state:setVariable(args[3], input:rep(count, sep))
end

local function defineHashStub(name)
	---@param state Cartethyia.State
	---@param args string[]
	return function(state, args)
		state:error("Missing implementation for hash "..name)
	end
end

StringSubCommands.MD5 = defineHashStub("MD5")
StringSubCommands.SHA1 = defineHashStub("SHA1")
StringSubCommands.SHA224 = defineHashStub("SHA224")
StringSubCommands.SHA256 = defineHashStub("SHA256")
StringSubCommands.SHA384 = defineHashStub("SHA384")
StringSubCommands.SHA512 = defineHashStub("SHA512")
StringSubCommands.SHA3_224 = defineHashStub("SHA3_224")
StringSubCommands.SHA3_256 = defineHashStub("SHA3_256")
StringSubCommands.SHA3_384 = defineHashStub("SHA3_384")
StringSubCommands.SHA3_512 = defineHashStub("SHA3_512")

return StringSubCommands
