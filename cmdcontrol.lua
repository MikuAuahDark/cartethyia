local PATH = string.sub(..., 1, string.len(...) - #(".cmdcontrol"))

---@type Cartethyia.Util.M
local Util = require(PATH..".util")

---@alias Cartethyia.CMDControl.M table<string, Cartethyia.State._LuaFunction>
---@type Cartethyia.CMDControl.M
local ControlCommands = {}

---This defines the CMake `block()` command.
---@param self Cartethyia.State
---@param args string[]
function ControlCommands.BLOCK(self, args)
	local variableScope = true
	local propagate = false

	if args[1] == "SCOPE_FOR" then
		table.remove(args, 1)
		variableScope = false

		while true do
			if args[1] == "VARIABLES" then
				table.remove(args, 1)
				variableScope = true
			elseif args[1] == "POLICIES" then
				table.remove(args, 1)
				self:warning("Cartethyia does not support 'POLICIES' scope and will be ignored")
			else
				break
			end
		end
	end

	if args[1] == "PROPAGATE" then
		table.remove(args, 1)
		propagate = true
	end

	-- Send "block" command info to control stack
	local result = {
		type = "block"
	}
	if variableScope then
		if propagate then
			result.propagate = args
		else
			result.propagate = {}
		end
	end

	self.controlStack[#self.controlStack+1] = result
end

---@param self Cartethyia.State
---@param args string[]
function ControlCommands.ENDBLOCK(self, args)
	local block = self.controlStack[#self.controlStack]
	assert(block and block.type == "block")

	if block.propagate then
		for _, var in ipairs(block.propagate) do
			-- TODO: Propagate variable changes
		end
	end

	table.remove(self.controlStack)
end

local _evaluateIf

---@param state Cartethyia.State
---@param args string[]
local function _evaluateOne(state, args)
	local evaluated = false
	local flip = false
	local arg = args[1]

	if arg == "NOT" then
		table.remove(args, 1)
		flip = true
		arg = args[1]
	end

	if arg == "(" then
		-- Parenthesis, evaluate it first
		-- Find matching ")"
		local subparencount = 0
		local newargs = {}

		for _ = 1, #args do
			local next = table.remove(args, 1)
			if next == ")" then
				if subparencount == 0 then
					break
				end

				subparencount = subparencount - 1
			elseif next == "(" then
				subparencount = subparencount + 1
			end

			newargs[#newargs+1] = next
		end

		-- Evaluate
		evaluated = _evaluateIf(state, newargs)
	elseif arg == "COMMAND" then
		table.remove(args, 1)
		local name = table.remove(args, 1)
		-- TODO: Use standarized functions
		evaluated = not not state.functions[name:upper()]
	elseif arg == "POLICY" or arg == "TARGET" or arg == "TEST" then
		state:warning("Cartethyia does not support if("..arg..") and will be evaluated to false")
		table.remove(args, 1)
		table.remove(args, 1)
		evaluated = false
	elseif arg == "DEFINED" then
		table.remove(args, 1)
		local name = table.remove(args, 1)
		-- TODO: Test for something like ENV{name} or CACHE{name}
		evaluated = state:hasVariable(name)
	elseif
		arg == "EXISTS" or
		arg == "IS_READABLE" or
		arg == "IS_WRITABLE" or
		arg == "IS_EXECUTABLE" or
		arg == "IS_DIRECTORY" or
		arg == "IS_SYMLINK" or
		arg == "IS_ABSOLUTE"
	then
		-- TODO: Support these?
		state:warning("Cartethyia does not support filesystem-related if("..arg..") and will be evaluated to false")
		table.remove(args, 1)
		table.remove(args, 1)
		evaluated = false
	else
		-- See if it's one of those binary comparison
		local binaryfunc = args[2]
		local matchBinaryFunc = true

		if binaryfunc == "LESS" then
			local second = args[3]
			local fn, sn = tonumber(arg), tonumber(second)
			evaluated = not not (fn and sn and fn < sn)
		elseif binaryfunc == "GREATER" then
			local second = args[3]
			local fn, sn = tonumber(arg), tonumber(second)
			evaluated = not not (fn and sn and fn > sn)
		elseif binaryfunc == "EQUAL" then
			local second = args[3]
			local fn, sn = tonumber(arg), tonumber(second)
			evaluated = not not (fn and sn and fn == sn)
		elseif binaryfunc == "LESS_EQUAL" then
			local second = args[3]
			local fn, sn = tonumber(arg), tonumber(second)
			evaluated = not not (fn and sn and fn <= sn)
		elseif binaryfunc == "GREATER_EQUAL" then
			local second = args[3]
			local fn, sn = tonumber(arg), tonumber(second)
			evaluated = not not (fn and sn and fn >= sn)
		elseif binaryfunc == "STRLESS" then
			local second = args[3] or ""
			evaluated = arg < second
		elseif binaryfunc == "STRGREATER" then
			local second = args[3] or ""
			evaluated = arg > second
		elseif binaryfunc == "STREQUAL" then
			local second = args[3] or ""
			evaluated = arg == second
		elseif binaryfunc == "STRLESS_EQUAL" then
			local second = args[3] or ""
			evaluated = arg <= second
		elseif binaryfunc == "STRGREATER_EQUAL" then
			local second = args[3] or ""
			evaluated = arg >= second
		elseif binaryfunc == "VERSION_LESS" then
			local second = args[3] or ""
			evaluated = Util.compareVersion(arg, second) < 0
		elseif binaryfunc == "VERSION_GREATER" then
			local second = args[3] or ""
			evaluated = Util.compareVersion(arg, second) > 0
		elseif binaryfunc == "VERSION_EQUAL" then
			local second = args[3] or ""
			evaluated = Util.compareVersion(arg, second) == 0
		elseif binaryfunc == "VERSION_LESS_EQUAL" then
			local second = args[3] or ""
			evaluated = Util.compareVersion(arg, second) <= 0
		elseif binaryfunc == "VERSION_GREATER_EQUAL" then
			local second = args[3] or ""
			evaluated = Util.compareVersion(arg, second) >= 0
		elseif binaryfunc == "PATH_EQUAL" then
			local second = args[3] or ""
			evaluated = Util.pathEqual(arg, second)
		elseif binaryfunc == "MATCHES" then
			-- FIXME: Use CMake regex
			state:warning("Cartethyia currently uses Lua pattern for matching and is not compatible with CMake!")

			local second = args[3] or ""
			local matches = {string.find(arg, second)}
			evaluated = #matches > 0
			if evaluated then
				state:setVariable("CMAKE_MATCH_COUNT", tostring(#matches - 2)) -- accomodate start and end sequence
				state:setVariable("CMAKE_MATCH_0", arg:sub(matches[1], matches[2]))

				for i = 3, #matches do
					state:setVariable("CMAKE_MATCH_"..(i - 2), matches[i])
				end
			else
				state:setVariable("CMAKE_MATCH_COUNT", "0")
			end
		elseif binaryfunc == "IN_LIST" then
			local second = Util.makeList(state:getVariable(args[3] or "", ""))
			evaluated = false
			for _, v in ipairs(second) do
				if v == arg then
					evaluated = true
					break
				end
			end
		else
			matchBinaryFunc = false
			local constant = Util.evaluateBoolStrict(arg)

			if constant == nil then
				constant = Util.evaluateBoolStrict(state:getVariable(arg))

				if constant == nil then
					-- It means string with non-zero length
					constant = true
				end
			end

			evaluated = constant
		end

		if matchBinaryFunc then
			-- Pop 3 elements
			table.remove(args, 1)
			table.remove(args, 1)
			table.remove(args, 1)
		end
	end

	if flip then
		evaluated = not evaluated
	end

	return evaluated, args
end

---@param state Cartethyia.State
---@param args string[]
function _evaluateIf(state, args)
	local result = false
	local lastLogic = nil

	while #args > 0 do
		local first
		first, args = _evaluateOne(state, args)

		if lastLogic == nil then
			result = first
		elseif lastLogic == "and" then
			result = result and first
		elseif lastLogic == "or" then
			result = result or first
		end

		if #args > 0 then
			-- Has predicate
			local pred = args[1]

			if pred == "AND" or pred == "OR" then
				lastLogic = pred:lower()
				table.remove(args, 1)
			end
		end
	end

	return result
end

---@param state Cartethyia.State
---@param args string[]
function ControlCommands.IF(state, args)
	local eval = _evaluateIf(state, args)
	-- TODO: Check if there's error

	state.controlStack[#state.controlStack+1] = {
		type = "if",
		success = eval
	}

	if not eval then
		-- TODO: Jump to next elseif(), else(), or endif()
	end
end

---@param state Cartethyia.State
---@param args string[]
function ControlCommands.ELSEIF(state, args)
	local ifcontrol = state.controlStack[#state.controlStack]
	assert(ifcontrol and ifcontrol.type == "if")

	if ifcontrol.success then
		-- TODO: Jump to endif()
	else
		local eval = _evaluateIf(state, args)
		-- TODO: Check if there's error

		ifcontrol.success = eval

		if not eval then
			-- TODO: Jump to next elseif(), else(), or endif()
		end
	end
end

---@param state Cartethyia.State
function ControlCommands.ELSE(state)
	local ifcontrol = state.controlStack[#state.controlStack]
	assert(ifcontrol and ifcontrol.type == "if")
	-- Do nothing
	if ifcontrol.success then
		-- TODO: Jump to endif()
	end
end

---@param state Cartethyia.State
function ControlCommands.ENDIF(state)
	local ifcontrol = state.controlStack[#state.controlStack]
	assert(ifcontrol.type == "if")

	table.remove(state.controlStack)
end

---@param state Cartethyia.State
---@param args string[]
function ControlCommands.WHILE(state, args)
	local eval = _evaluateIf(state, args)
	-- TODO: Check if there's error

	state.controlStack[#state.controlStack+1] = {
		type = "while",
		success = eval
	}

	if not eval then
		-- TODO: Jump straight to endwhile()
	end
end

---@param state Cartethyia.State
function ControlCommands.ENDWHILE(state)
	local whileblock = state.controlStack[#state.controlStack]
	assert(whileblock.type == "while")

	if whileblock.success then
		-- TODO: Jump back to while()
	else
		table.remove(state.controlStack)
	end
end

---@param state Cartethyia.State
local function stepLoop(state)
end

---@param state Cartethyia.State
---@param args string[]
function ControlCommands.FOREACH(state, args)
	---@type string[]
	local destvars = {}
	local pushed = false

	while #args > 0 do
		---@type string
		local arg = table.remove(args, 1)

		if #destvars > 0 then
			if arg == "RANGE" then
				local start, stop, step

				if #args >= 2 then
					start = tonumber(args[1] or 0)
					if not start then
						state:fatalError("foreach Invalid start integer: '"..args[1].."'")
						return
					end

					stop = tonumber(args[2] or 0)
					if not stop then
						state:fatalError("foreach Invalid stop integer: '"..args[2].."'")
						return
					end

					step = tonumber(args[3] or 1)
					if not step then
						state:fatalError("foreach Invalid step integer: '"..args[1].."'")
						return
					elseif step == 0 then
						step = 1
					end
				else
					stop = tonumber(args[2] or 0)
					if not stop then
						state:fatalError("foreach Invalid stop integer: '"..args[2].."'")
						return
					end

					start = 0
					if start > stop then
						step = -1
					else
						step = 1
					end
				end

				local destvar = destvars[1]
				local captureInfo = {}
				if state:hasVariable(destvar) then
					captureInfo[destvar] = {value = state:getVariable(destvar)}
				else
					captureInfo[destvar] = {value = nil}
				end

				-- Note: https://cmake.org/cmake/help/v4.0/command/foreach.html
				-- CMake specifically mentions that if start is larger than stop
				-- (for reverse loop), the result is undocumented behavior.
				state:insertControlBlock {
					type = "for",
					subtype = "range",
					current = start,
					stop = stop,
					step = step,
					destvar = destvar,
					capture = captureInfo
				}
				pushed = true
				break
			elseif arg == "IN" then
				local kind = args[1]
				local items = {}

				if kind == "LISTS" then
					for i = 2, #args do
						items[#items+1] = state:getVariable(args[i])
					end
					destvars = {destvars[1]}
				elseif kind == "ZIP_LISTS" then
					if #destvars ~= 1 and #destvars ~= #args - 1 then
						state:fatalError("Expected "..(#args - 1).." list variables, but given "..#destvars)
						return
					end

					-- If there's only 1 destination variables, expand
					if #destvars == 1 then
						local newdestvars = {}
						for i, v in ipairs(destvars) do
							newdestvars[#newdestvars+1] = v.."_"..i
						end
						destvars = newdestvars
					end
				elseif kind == "ITEMS" then
					Util.tableMove(args, 2, #args, 1, items)
					destvars = {destvars[1]}
				else
					state:fatalError("Expected LISTS, ZIP_LISTS, or ITEMS, got "..tostring(kind or "end-of-arguments"))
					return
				end

				local captureInfo = {}
				for _, destvar in ipairs(destvars) do
					if state:hasVariable(destvar) then
						captureInfo[destvar] = {value = state:getVariable(destvar)}
					else
						captureInfo[destvar] = {value = nil}
					end
				end
				if kind == "ZIP_LISTS" then
					state:insertControlBlock {
						type = "for",
						subtype = "zip",
						current = 1,
						items = items,
						destvar = destvars,
						capture = captureInfo
					}
				else
					state:insertControlBlock {
						type = "for",
						subtype = "each",
						current = 1,
						items = items,
						destvar = destvars[1],
						capture = captureInfo
					}
				end
				pushed = true
			else
				-- Maybe legacy foreach(out_var items...)
				destvars[#destvars+1] = arg
			end
		else
			destvars[#destvars+1] = arg
		end
	end

	if not pushed then
		if #destvars < 2 then
			state:fatalError("foreach() called with incorrect number of arguments")
			return
		end

		-- Legacy foreach(out_var items...)
		---@type string
		local destvar = table.remove(destvars, 1)
		local captureInfo = {}
		if state:hasVariable(destvar) then
			captureInfo[destvar] = {value = state:getVariable(destvar)}
		else
			captureInfo[destvar] = {value = nil}
		end
		state:insertControlBlock {
			type = "for",
			subtype = "each",
			current = 1,
			items = destvars,
			destvar = destvar,
			capture = captureInfo
		}
	end

	return stepLoop(state)
end

---@param state Cartethyia.State
function ControlCommands.CONTINUE(state)
	local control = state.controlStack[#state.controlStack]
	if control then
		if control.type == "while" then
			-- TODO: Jump back to while()
			return
		elseif control.type == "for" then
			-- TODO: Jump to endforeach()
			return
		end
	end

	state:error("A CONTINUE command was found outside of a proper FOREACH or WHILE loop scope.")
end

---@param state Cartethyia.State
function ControlCommands.BREAK(state)
	local control = state.controlStack[#state.controlStack]
	if control then
		if control.type == "while" then
			control.success = false
			-- TODO: Jump to endwhile()
			return
		elseif control.type == "for" then
			control.breakloop = true
			-- TODO: Jump to endforeach()
			return
		end
	end

	state:error("A BREAK command was found outside of a proper FOREACH or WHILE loop scope.")
end

return ControlCommands
