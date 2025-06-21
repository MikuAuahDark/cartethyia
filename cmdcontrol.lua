local PATH = string.sub(..., 1, string.len(...) - #(".cmdcontrol"))

---@type Cartethyia.Util.M
local Util = require(PATH..".util")

---@alias Cartethyia.CMDControl.M table<string, Cartethyia.State._LuaFunction>
---@type Cartethyia.CMDControl.M
local ControlCommands = {}

---This defines the CMake `block()` command.
---@param state Cartethyia.State
---@param args string[]
function ControlCommands.BLOCK(state, args)
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
				state:warning("Cartethyia does not support 'POLICIES' scope and will be ignored")
			else
				break
			end
		end
	end

	if args[1] == "PROPAGATE" then
		table.remove(args, 1)
		propagate = true
	end

	local execInfo, execPos = state:getCurrentExecInfo()
	-- Send "block" command info to control stack
	---@type Cartethyia.State._BlockBlock
	local result = {
		type = "block",
		execIndex = execPos,
		position = execInfo.pc,
		propagate = nil
	}
	if variableScope then
		state:getVariableStore():beginScope()

		if propagate then
			result.propagate = args
		else
			result.propagate = {}
		end
	end

	state:insertControlBlock(result)
end

---@param state Cartethyia.State
function ControlCommands.ENDBLOCK(state)
	local block = state.controlStack[#state.controlStack]
	assert(block and block.type == "block")

	if block.propagate then
		local varstore = state:getVariableStore()
		varstore:endScope(block.propagate)
	end

	state:popLastControlBlock()
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

	local execInfo, execPos = state:getCurrentExecInfo()
	state.controlStack[#state.controlStack+1] = {
		type = "if",
		execIndex = execPos,
		position = execInfo.pc,
		success = eval
	}

	if not eval then
		-- Jump to elseif/else/endif
		local ifcmd = execInfo.code[execInfo.pc]
		execInfo.pc = ifcmd.data[2] or ifcmd.data[1]
	end
end

---@param state Cartethyia.State
---@param args string[]
function ControlCommands.ELSEIF(state, args)
	local ifcontrol = state.controlStack[#state.controlStack]
	assert(ifcontrol and ifcontrol.type == "if")

	local execInfo = state:getCurrentExecInfo()
	local elseifcmd = execInfo.code[execInfo.pc]

	if ifcontrol.success then
		-- Jump to endif()
		execInfo.pc = elseifcmd.data[1]
	else
		local eval = _evaluateIf(state, args)
		-- TODO: Check if there's error

		ifcontrol.success = eval

		if not eval then
			-- Jump to elseif/else/endif
			execInfo.pc = elseifcmd.data[2] or elseifcmd.data[1]
		end
	end
end

---@param state Cartethyia.State
function ControlCommands.ELSE(state)
	local ifcontrol = state.controlStack[#state.controlStack]
	assert(ifcontrol and ifcontrol.type == "if")

	local execInfo = state:getCurrentExecInfo()
	local elsecmd = execInfo.code[execInfo.pc]

	if ifcontrol.success then
		-- Jump to endif()
		execInfo.pc = elsecmd.data[1]
	end
end

---@param state Cartethyia.State
function ControlCommands.ENDIF(state)
	local ifcontrol = state.controlStack[#state.controlStack]
	assert(ifcontrol.type == "if")

	state:popLastControlBlock()
end

---@param state Cartethyia.State
---@param args string[]
function ControlCommands.WHILE(state, args)
	local eval = _evaluateIf(state, args)
	-- TODO: Check if there's error

	local execInfo, execPos = state:getCurrentExecInfo()
	local currentControl = state:getCurrentControlBlock()
	if
		currentControl and
		currentControl.type == "while" and
		currentControl.execIndex == execPos and
		currentControl.position == execInfo.pc
	then
		-- Looping back from endwhile
		currentControl.success = eval
	else
		-- New while loop
		state.controlStack[#state.controlStack+1] = {
			type = "while",
			success = eval,
			execIndex = execPos,
			position = execInfo.pc
		}
	end

	if not eval then
		-- Jump straight to endwhile()
		local whileinfo = execInfo.code[execInfo.pc]
		execInfo.pc = assert(whileinfo.data[1])
	end
end

---@param state Cartethyia.State
function ControlCommands.ENDWHILE(state)
	local whileblock = state:getCurrentControlBlock()
	assert(whileblock and whileblock.type == "while")

	if whileblock.success then
		-- Jump back to while()
		local execInfo = state:getCurrentExecInfo()
		execInfo.pc = whileblock.position
	else
		state:popLastControlBlock()
	end
end

---@param state Cartethyia.State
local function stepLoop(state)
	local forblock = state:walkControlBlock("for")
	assert(forblock and forblock.type == "for")
	local execInfo = state:getCurrentExecInfo()
	local forInst = execInfo.code[forblock.position]

	if forblock.subtype == "range" then
		forblock.current = forblock.current + forblock.step
		local done = false
		if forblock.step > 0 then
			done = forblock.current > forblock.step
		else
			done = forblock.current < forblock.step
		end

		if done then
			-- Loop done
			forblock.breakloop = true
			execInfo.pc = assert(forInst.data[1])
			return
		end

		state:setVariable(forblock.destvar, forblock.current)
	elseif forblock.subtype == "each" then
		forblock.current = forblock.current + 1
		if not forblock.items[forblock.current] then
			-- Loop done
			forblock.breakloop = true
			execInfo.pc = assert(forInst.data[1])
			return
		end

		state:setVariable(forblock.destvar, forblock.items[forblock.current])
	elseif forblock.subtype == "zip" then
		forblock.current = forblock.current + 1
		local items = forblock.items[forblock.current]
		if not items then
			-- Loop done
			forblock.breakloop = true
			execInfo.pc = assert(forInst.data[1])
			return
		end

		for i, var in ipairs(forblock.destvar) do
			if items[i] then
				state:setVariable(var, items[i])
			else
				state:unsetVariable(var)
			end
		end
	end

	execInfo.pc = forblock.position + 1 -- Next instruction to be executed
end

---@param state Cartethyia.State
---@param args string[]
function ControlCommands.FOREACH(state, args)
	---@type string[]
	local destvars = {}
	local pushed = false
	local execInfo, execPos = state:getCurrentExecInfo()
	local varstore = state:getVariableStore()

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

				-- Note: https://cmake.org/cmake/help/v4.0/command/foreach.html
				-- CMake specifically mentions that if start is larger than stop
				-- (for reverse loop), the result is undocumented behavior.
				-- that means we can do whatever we want.
				state:insertControlBlock {
					type = "for",
					subtype = "range",
					execIndex = execPos,
					position = execInfo.pc,
					current = start - step, -- stepLoop() will increment it
					stop = stop,
					step = step,
					destvar = destvar,
				}
				varstore:beginSoftScope(destvars)
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

				if kind == "ZIP_LISTS" then
					state:insertControlBlock {
						type = "for",
						subtype = "zip",
						execIndex = execPos,
						position = execInfo.pc,
						current = 0, -- stepLoop() will increment it
						items = items,
						destvar = destvars,
					}
				else
					state:insertControlBlock {
						type = "for",
						subtype = "each",
						execIndex = execPos,
						position = execInfo.pc,
						current = 0, -- stepLoop() will increment it
						items = items,
						destvar = destvars[1],
					}
				end
				varstore:beginSoftScope(destvars)
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
		state:insertControlBlock {
			type = "for",
			subtype = "each",
			execIndex = execPos,
			position = execInfo.pc,
			current = 0, -- stepLoop() will increment it
			items = destvars,
			destvar = destvar,
		}
		varstore:beginSoftScope(destvars)
	end

	return stepLoop(state)
end

---@param state Cartethyia.State
---@param targetControl string
---@param index integer
local function restoreControlAndExecStack(state, targetControl, index)
	local varstore = state:getVariableStore()
	local lastIndex = nil

	while true do
		local cb = state.controlStack[#state.controlStack]

		if lastIndex == nil then
			lastIndex = cb.execIndex
		elseif cb.execIndex ~= lastIndex then
			-- Pop out execution stack
			for _ = state:getExecStackCount(), lastIndex, -1 do
				state:popLastExecStack()
			end
		end

		if not cb or (cb.type == targetControl and cb.execIndex == index) then
			break
		end

		-- Some special case for certain control block
		if cb.type == "for" then
			-- Need to pop the variable soft scope
			varstore:endSoftScope()
		elseif cb.type == "block" then
			-- Need to pop the variable scope
			if cb.propagate then
				varstore:endScope(cb.propagate)
			end
		end

		state:popLastControlBlock()
	end
end

---@param state Cartethyia.State
---@param dobreak boolean?
local function continueOrBreak(state, dobreak)
	local whileblock, whileblockIndex = state:walkControlBlock("while")
	local forblock, forblockIndex = state:walkControlBlock("for")

	-- Note: Both might be present, so pick one with higher control block position.
	local targetblock = nil
	if whileblock and forblock then
		if whileblockIndex > forblockIndex then
			targetblock = whileblock
		else
			targetblock = forblock
		end
	end

	if not targetblock then
		return false
	end

	if targetblock.type == "while" then
		-- Jump to endwhile so it re-evaluate the loop
		local targetExecInfo = assert(state:getExecInfo(targetblock.execIndex))

		-- Note: We can't just set the PC. This may be called through a macro which is on another exec stack.
		restoreControlAndExecStack(state, "while", targetblock.execIndex)
		local whileInst = targetExecInfo.code[targetblock.position]
		targetExecInfo.pc = assert(whileInst.data[1])

		if dobreak then
			targetblock.success = false
		end
	elseif targetblock.type == "for" then
		-- Jump to endfor so it re-evaluate the loop
		-- Again, we can't just set the PC for same reason.
		local targetExecInfo = assert(state:getExecInfo(targetblock.execIndex))
		restoreControlAndExecStack(state, "for", targetblock.execIndex)
		local forInst = targetExecInfo.code[targetblock.position]
		targetExecInfo.pc = assert(forInst.data[1])

		if dobreak then
			targetblock.breakloop = true
		end
	else
		error("uh oh")
	end

	return true
end

---@param state Cartethyia.State
function ControlCommands.CONTINUE(state)
	if not continueOrBreak(state, false) then
		state:error("A CONTINUE command was found outside of a proper FOREACH or WHILE loop scope.")
	end
end

---@param state Cartethyia.State
function ControlCommands.BREAK(state)
	if not continueOrBreak(state, true) then
		state:error("A BREAK command was found outside of a proper FOREACH or WHILE loop scope.")
	end
end

---@param state Cartethyia.State
function ControlCommands.ENDFOREACH(state)
	local forblock = state:getCurrentControlBlock()
	assert(forblock and forblock.type == "for")

	state:getVariableStore():endSoftScope()
	state:popLastControlBlock()
end

---@param state Cartethyia.State
---@param args string[]
---@param macro boolean
local function defineFunctionOrMacro(state, args, macro)
	local execInfo = state:getCurrentExecInfo()
	local funcinst = execInfo.code[execInfo.pc]

	if #args < 1 then
		state:error(funcinst.command.name:upper().." called with incorrect number of arguments.")
		return
	end

	---@type string
	local funcname = table.remove(args)
	local endfuncpc = assert(funcinst.data[1])

	-- Copy function codes
	---@type Cartethyia.State._Command[]
	local code = {}
	Util.tableMove(execInfo.code, execInfo.pc + 1, endfuncpc - 1, 1, code)
	state.functions[funcname:upper()] = {
		code = code,
		filename = execInfo.filename,
		argnames = args,
		line = funcinst.command.line,
		macro = macro
	}

	-- Jump straight to next instruction after endfunction()/endmacro()
	execInfo.pc = endfuncpc + 1
end

---@param state Cartethyia.State
---@param args string[]
function ControlCommands.FUNCTION(state, args)
	return defineFunctionOrMacro(state, args, false)
end

---@param state Cartethyia.State
function ControlCommands.ENDFUNCTION(state)
	-- Note: We only hit this if we SOMEHOW put inapproproate endfunction()
	state:error("Flow control statements are not properly nested.")
end

---@param state Cartethyia.State
---@param args string[]
function ControlCommands:MACRO(state, args)
	return defineFunctionOrMacro(state, args, true)
end

---@param state Cartethyia.State
function ControlCommands.ENDMACRO(state)
	-- Note: We only hit this if we SOMEHOW put inapproproate endmacro()
	state:error("Flow control statements are not properly nested.")
end

---@param state Cartethyia.State
function ControlCommands.RETURN(state)
	while true do
		local execInfo, execPos = state:getCurrentExecInfo()
		local varstore = state:getVariableStore()
		local shadowVarstore = state:getShadowVariableStore()

		-- Pop as many control block as possible
		while true do
			local controlBlock = state:getCurrentControlBlock()
			if not controlBlock then
				break
			end

			if controlBlock.execIndex >= execPos then
				-- Handle special case
				if controlBlock.type == "block" then
					-- Pop variable scope?
					if controlBlock.propagate then
						varstore:endScope(controlBlock.propagate)
					end
				elseif controlBlock.type == "for" then
					-- Pop soft captures
					varstore:endSoftScope()
				end

				state:popLastControlBlock()
			else
				break
			end
		end

		-- If it's macro, pop shadow variable store.
		-- If it's function, pop variable store then break.
		-- In either case, pop the last exec stack too.
		if execInfo.macro then
			shadowVarstore:endScope()
			state:popLastExecStack()
		else
			varstore:endScope()
			state:popLastExecStack()
			break
		end
	end
end

return ControlCommands
