---@class Cartethyia.State
local State = {}

---@class Cartethyia.State._CMakeFunction
---@field public code any
---@field public argnames string[]
---@field public macro boolean

---@alias Cartethyia.State._LuaFunction fun(state:Cartethyia.State,args:Cartethyia.Parser.Argument[])

---@alias Cartethyia.State._Function Cartethyia.State._LuaFunction|Cartethyia.State._CMakeFunction

local CONTROL_BLOCK = {
	block = true,
	["if"] = true,
	["else"] = "if",
	["elseif"] = "if",
	["while"] = true,
	foreach = true,
	["function"] = true,
	macro = true
}

---@param text string
local function printStderr(text)
	io.stderr:write(text, "\n")
end

function State:new()
	---@type table<string, Cartethyia.State._Function>
	self.functions = {
		BLOCK = State.COMMAND_BLOCK,
		MESSAGE = State.COMMAND_MESSAGE
	}
	self.controlStack = {}

	self.printStdout = print
	self.printStderr = printStderr

	-- TODO: Finalize setup
	self:setVariable("CARTETHYIA", "1")
end

---@param commands Cartethyia.Parser.Command[]
---@param filename string?
function State:execute(commands, filename)
	filename = filename or "<UNKNOWN>"

	local err, line = self:verify(commands)
	if err then
		return nil, err.." at "..filename..":"..(line or 0)
	end

	-- TODO: Execute
end

---@param commands Cartethyia.Parser.Command[]
function State:verify(commands)
	---@type [string, integer][]
	local stack = {}

	for _, command in ipairs(commands) do
		local cmd = command.name:lower()

		local cmdblockinfo = CONTROL_BLOCK[cmd]
		if cmdblockinfo then
			if type(cmdblockinfo) == "string" then
				-- If it's string, it means check latest without popping.
				local top = stack[#stack]
				if not top then
					return "missing '"..cmdblockinfo.."' for '"..cmd.."'", command.line
				end

				if top[1] ~= cmdblockinfo then
					return "missing preceding '"..cmdblockinfo.."' for '"..cmd.."'", command.line
				end
			else
				-- If it's boolean, it means push
				stack[#stack+1] = {cmd, command.line}
			end
		elseif cmd:sub(1, 3) == "end" and CONTROL_BLOCK[cmd:sub(4)] == true then
			-- Pop control block
			local top = stack[#stack]
			local cmdname = cmd:sub(4)
			if not top then
				return "unexpected '"..cmd.."' no preceding '"..cmdname.."'", command.line
			end

			if top[1] ~= cmdname then
				return "unexpected '"..cmd.."' for terminating '"..top[1].."'", command.line
			end

			stack[#stack] = nil
		end
	end

	if #stack > 0 then
		local top = stack[#stack]
		return "unterminated '"..top[1].."'", top[2]
	end

	return nil
end

function State:step()
end

---@param prefix string
---@param message string
---@param halt boolean?
function State:message(prefix, message, halt)
end

---@param message string
---@param continue boolean?
function State:error(message, continue)
	return self:message("Error", message, not continue)
end

---@param message string
function State:warning(message)
	return self:message("Warning", message)
end

---@param func fun(message:string)
function State:setPrintToStdout(func)
end

---@param name string
---@return string
function State:getVariable(name, default)
	-- TODO
	return default or ""
end

---@param name string
---@param default boolean?
---@return boolean
function State:getVariableBool(name, default)
	if not self:hasVariable(name) then
		return not not default
	end

	local value = self:getVariable(name)
	if
		value == "" or
		value == "0" or
		value == "OFF" or
		value == "NO" or
		value == "FALSE" or
		value == "N" or
		value == "IGNORE" or
		value == "NOTFOUND" or
		value:sub(-9) == "-NOTFOUND"
	then
		return false
	end

	return true
end

---@param name string
---@return boolean
function State:hasVariable(name)
	-- TODO
end

---@param uargs Cartethyia.Parser.Argument[]
---@return string[]
function State:expandArguments(uargs)
	return {}
end


--- Built-in commands ---

---This defines the CMake `block()` command.
---@param args string[]
function State:COMMAND_BLOCK(args)
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

	-- TODO: Send "block" command info to control stack
end

---This defines the CMake `message()` command.
---@param args string[]
function State:COMMAND_MESSAGE(args)
	if #args < 1 then
		self:error("message() called with incorrect number of arguments")
		return
	end

	local cmd = args[1]
	if cmd == "FATAL_ERROR" then
		self:error(table.concat(args, "", 2))
	elseif cmd == "SEND_ERROR" then
		self:error(table.concat(args, "", 2), true)
	elseif cmd == "WARNING" then
		self:warning(table.concat(args, "", 2))
	elseif cmd == "AUTHOR_WARNING" then
		self:message("Warning (dev)", table.concat(args, "", 2))
	elseif cmd == "DEPRECATION" then
		if self:getVariableBool("CMAKE_ERROR_DEPRECATED") then
			self:message("Deprecation Error", table.concat(args, "", 2), true)
		elseif self:getVariableBool("CMAKE_WARN_DEPRECATED", true) then
			self:message("Deprecation Warning", table.concat(args, "", 2))
		end
	elseif cmd == "NOTICE" then
		self.printStderr(table.concat(args, "", 2))
	elseif cmd == "STATUS" then
		self.printStdout("-- "..table.concat(args, "", 2))
	elseif cmd == "VERBOSE" then
		-- TODO: Log level
		self.printStdout("-- "..table.concat(args, "", 2))
	elseif cmd == "DEBUG" then
		-- TODO: Log level
		self.printStdout("-- "..table.concat(args, "", 2))
	elseif cmd == "TRACE" then
		-- TODO: Log level
		self.printStdout("-- "..table.concat(args, "", 2))
	else
		self.printStderr(table.concat(args))
	end
end

return State
