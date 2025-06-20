local PATH = string.sub(..., 1, string.len(...) - #(".state"))

---@type Cartethyia.Interpolator.M
local Interpolator = require(PATH..".interpolate")

---@type Cartethyia.Util.M
local Util = require(PATH..".util")

---@type Cartethyia.Variables.M
local Variables = require(PATH..".variables")

---@class Cartethyia.State
local State = {}

---@class Cartethyia.State._Command
---@field public command Cartethyia.Parser.Command
---@field public data integer[]

---@class Cartethyia.State._CMakeFunction
---@field public code Cartethyia.State._Command[]
---@field public filename string
---@field public line integer
---@field public argnames string[]
---@field public macro boolean

---@class Cartethyia.State._Block
---@field public execIndex integer
---@field public position integer

---@class Cartethyia.State._BlockBlock: Cartethyia.State._Block
---@field public type "block"
---@field public propagate string[]|nil if this is nil, variable scope is not performed

---@class Cartethyia.State._IfBlock: Cartethyia.State._Block
---@field public type "if"
---@field public success boolean if true and elseif/else encountered, jump straight to endif.

---@class Cartethyia.State._WhileBlock: Cartethyia.State._Block
---@field public type "while"
---@field public success boolean if true and elseif/else encountered, jump straight to endif.

---@class Cartethyia.State._FunctionBlock: Cartethyia.State._Block, Cartethyia.State._CMakeFunction
---@field public type "function"|"macro"

---@class Cartethyia.State._ForBlock: Cartethyia.State._Block
---@field public type "for"
---@field public breakloop boolean
---@field public current integer

---@class Cartethyia.State._ForRangeBlock: Cartethyia.State._ForBlock
---@field public subtype "range"
---@field public stop integer
---@field public step integer
---@field public destvar string

---@class Cartethyia.State._ForeachBlock: Cartethyia.State._ForBlock
---@field public subtype "each"
---@field public items string[]
---@field public destvar string

---@class Cartethyia.State._ForeachZipBlock: Cartethyia.State._ForBlock
---@field public subtype "zip"
---@field public items string[][]
---@field public destvar string[]

---@alias Cartethyia.State._LuaFunction fun(state:Cartethyia.State,args:string[],isUnquoted:boolean[])
---@alias Cartethyia.State._ControlBlock
---| Cartethyia.State._BlockBlock
---| Cartethyia.State._IfBlock
---| Cartethyia.State._WhileBlock
---| Cartethyia.State._ForRangeBlock
---| Cartethyia.State._ForeachBlock
---| Cartethyia.State._ForeachZipBlock

---@class Cartethyia.State._ExecStack
---@field public code Cartethyia.State._Command[]
---@field public pc integer
---@field public filename string
---@field public shadowVariables table<string, string> Read-only variables that's included in arg expansion **only**.
---@field public macro boolean If true, don't pop variables.

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
	-- Note: Functions names casted to uppercase.
	---@type table<string, Cartethyia.State._Function>
	self.functions = {}
	---@type Cartethyia.State._ControlBlock[]
	self.controlStack = {} -- this stores the control block stack
	---@type Cartethyia.State._ExecStack[]
	self.execStack = {} -- this controls the (function) execution stack

	self.variables = Variables()
	self.shadowVariables = Variables()
	self.interpolator = Interpolator(function(name)
		-- Note: We can't just pass it to self.variables
		-- because current stack may have shadow variables.
		if self.shadowVariables:has(name) then
			return self.shadowVariables:get(name)
		end

		return self:getVariable(name)
	end)

	self.currentError = nil

	self:setPrintToStdout(print)
	self:setPrintToStderr(printStderr)
	self.variables:set("CARTETHYIA", "1", 1)
	-- TODO: Finalize setup
end

---@param commands Cartethyia.Parser.Command[]
---@param filename string?
function State:execute(commands, filename)
	filename = filename or "<UNKNOWN>"

	local codelist, err, line = self:compile(commands)
	if not codelist then
		assert(err)
		return nil, err.." at "..filename..":"..(line or 0)
	end

	self.execStack[#self.execStack+1] = {
		code = codelist,
		pc = 1,
		filename = filename,
		shadowVariables = {},
		macro = true
	}
end

---@param commands Cartethyia.Parser.Command[]
function State:compile(commands)
	---@type Cartethyia.State._Command[]
	local result = {}

	---@type [string, integer, integer][]
	local stack = {}

	for pc, command in ipairs(commands) do
		local cmd = command.name:lower()
		local obj = {info = Util.copyTable(command, true), data = {}}

		local cmdblockinfo = CONTROL_BLOCK[cmd]
		if cmdblockinfo then
			if type(cmdblockinfo) == "string" then
				-- If it's string, it means check latest without popping.
				local top = stack[#stack]
				if not top then
					return nil, "missing '"..cmdblockinfo.."' for '"..cmd.."'", command.line
				end

				if top[1] ~= cmdblockinfo then
					return nil, "missing preceding '"..cmdblockinfo.."' for '"..cmd.."'", command.line
				end

				-- Specialization
				if cmdblockinfo == "if" then
					-- elseif or else
					local ifcmd = assert(result[top[2]])

					if cmd == "elseif" or cmd == "else" then
						-- elseif data is {endif_pc[, next elseif/else pc]}
						-- else data is {endif_pc}
						obj.data[1] = 0

						if #ifcmd.data > 1 then
							local lastIf = result[ifcmd.data[#ifcmd.data]]
							lastIf.data[2] = pc
						end

						ifcmd.data[#ifcmd.data+1] = pc
					end
				end
			else
				-- If it's boolean, it means push
				stack[#stack+1] = {cmd, pc, command.line}

				-- Specialization
				if cmd == "if" then
					-- if data is {endif_pc, [elseif pc[, elseif pc[, else pc]]]}
					obj.data[1] = 0
				end
			end
		elseif cmd:sub(1, 3) == "end" and CONTROL_BLOCK[cmd:sub(4)] == true then
			-- Pop control block
			local top = stack[#stack]
			local cmdname = cmd:sub(4)
			if not top then
				return nil, "unexpected '"..cmd.."' no preceding '"..cmdname.."'", command.line
			end

			if top[1] ~= cmdname then
				return nil, "unexpected '"..cmd.."' for terminating '"..top[1].."'", command.line
			end

			-- Mark loop
			local prevcmd = assert(result[top[2]])
			prevcmd.data[1] = pc
			obj.data[1] = top[2]

			-- If specialization
			if prevcmd.command.name:lower() == "if" then
				-- Overwrite PC info
				for i = 2, #prevcmd.data do
					local elseIfOrElse = assert(result[prevcmd.data[i]])
					elseIfOrElse.data[1] = pc
				end
			end

			stack[#stack] = nil
		end

		result[#result+1] = obj
	end

	if #stack > 0 then
		local top = stack[#stack]
		return nil, "unterminated '"..top[1].."'", top[3]
	end

	return result
end

function State:step()
	if self.currentError then
		return nil, self.currentError
	end

	while true do
		local currentExec = self.execStack[#self.execStack]
		if not currentExec then
			return false
		end

		-- Get current command at current PC
		local currentPC = currentExec.pc
		local cmdinfo = currentExec.code[currentPC]
		if cmdinfo then
			local command = cmdinfo.command
			-- Execute command
			local func = self.functions[command.name:upper()]
			local args, isUnquoted = self:expandArguments(command.arguments)

			if type(func) == "function" then
				-- Lua function
				func(self, args, isUnquoted)

				if self.currentError then
					return nil, self.currentError
				end

				if currentExec.pc == currentPC then
					-- Function does not alter the PC. Increment PC by 1
					currentExec.pc = currentPC + 1
				end
			else
				-- CMake function.
				if #args < #func.argnames then
					self:fatalError("Function invoked with incorrect arguments for function named: "..command.name)
					return nil, self.currentError
				end

				local shadowvar = {}
				local argn = {}
				Util.tableMove(args, #func.argnames, #args, 1, argn)
				local varstore = func.macro and self.shadowVariables or self.variables

				-- Push variable stack.
				varstore:beginScope()

				-- Populate true variables
				varstore:set("ARGC", tostring(#args))

				for i, arg in ipairs(args) do
					local argname = func.argnames[i]
					if argname then
						varstore:set(argname, arg)
					end

					varstore:set("ARG"..(i - 1), arg)
				end

				varstore:set("ARGN", table.concat(argn, ";"))

				-- Create new function call stack
				self.execStack[#self.execStack+1] = {
					code = func.code,
					pc = 1,
					filename = func.filename,
					shadowVariables = shadowvar,
					macro = func.macro
				}
			end

			-- Break out of while loop
			break
		else
			assert(currentPC > #currentExec.code)
			self:popLastExecStack()
		end
	end
end

function State:run()
	while true do
		local res, err = self:step()

		if res == nil then
			return nil, err
		elseif res == false then
			break
		end
	end

	return true
end

---Most recent call first
---@return [string, integer][]
function State:traceback()
	local result = {}

	for i = #self.execStack, 1, -1 do
		local execInfo = self.execStack[i]
		local code = execInfo.code[execInfo.pc]

		if code then
			result[#result+1] = {execInfo.filename, code.command.line}
		end
	end

	return result
end

---@param message string
function State:messageStdout(message)
	return self.printStdout(message)
end

---@param message string
function State:messageStderr(message)
	return self.printStderr(message)
end

---@param message string
function State:sendError(message)
	return self.printStderr("Error: "..message)
end

---@param message string
function State:fatalError(message)
	self:sendError(message)
	self.currentError = message
end

---@param message string
---@param continue boolean?
function State:error(message, continue)
	if continue then
		return self:sendError(message)
	else
		return self:fatalError(message)
	end
end

---@param message string
function State:warning(message)
	return self.printStderr("Warning: "..message)
end

---@param message string
function State:warningDev(message)
	return self.printStderr("Warning (Dev): "..message)
end

---@param message string
function State:deprecated(message)
	if self:getVariableBool("CMAKE_ERROR_DEPRECATED") then
		self.printStderr("Deprecation Error: "..message)
		self.currentError = message
	elseif self:getVariableBool("CMAKE_WARN_DEPRECATED", true) then
		self.printStderr("Deprecation Warning: "..message)
	end
end

---@param func fun(message:string)
function State:setPrintToStdout(func)
	self.printStdout = func
end

---@param func fun(message:string)
function State:setPrintToStderr(func)
	self.printStderr = func
end

---@param name string
---@param default string?
---@return string
function State:getVariable(name, default)
	if not self.variables:has(name) then
		return default or ""
	end

	return self.variables:get(name)
end

---@param name string
---@param default boolean?
function State:getVariableBoolStrict(name, default)
	if not self:hasVariable(name) then
		return not not default
	end

	local value = self:getVariable(name)
	return Util.evaluateBoolStrict(value)
end

---@param name string
---@param default boolean?
function State:getVariableBool(name, default)
	local r = self:getVariableBoolStrict(name, default)
	if r == nil then
		return true
	end

	return r
end

---@param name string
---@param parentScope boolean?
---@return boolean
function State:hasVariable(name, parentScope)
	return self.variables:has(name, parentScope and -1 or 0)
end

---@param name string
---@param value boolean|number|string
---@param parentScope boolean?
function State:setVariable(name, value, parentScope)
	return self.variables:set(name, tostring(value), parentScope and -1 or 0)
end

---@param name string
---@param parentScope boolean?
function State:unsetVariable(name, parentScope)
	return self.variables:unset(name, parentScope and -1 or 0)
end

-- Internal functions --

---@param uargs Cartethyia.Parser.Argument[]
---@return string[], boolean[]
function State:expandArguments(uargs)
	local result = {}
	local unquoted = {}

	for _, arg in ipairs(uargs) do
		if arg.type == "bracket" then
			-- Pass as-is
			result[#result+1] = arg.argument
			unquoted[#unquoted+1] = false
		elseif arg.type == "quoted" then
			-- Perform variable expansion
			result[#result+1] = self.interpolator:interpolate(arg.argument)
			unquoted[#unquoted+1] = false
		elseif arg.type == "unquoted" then
			-- Perform variable expansion
			local expanded = self.interpolator:interpolate(arg.argument)
			for _, value in ipairs(Util.splitArgs(expanded)) do
				result[#result+1] = value
				unquoted[#unquoted+1] = true
			end
		end
	end

	return result, unquoted
end

---@param cblock Cartethyia.State._ControlBlock
function State:insertControlBlock(cblock)
	self.controlStack[#self.controlStack+1] = cblock
end

function State:removeCurrentControlBlock()
	table.remove(self.controlStack)
end

---@return Cartethyia.State._ControlBlock|nil
function State:getCurrentControlBlock()
	return self.controlStack[#self.controlStack]
end

---@param blocktype string
function State:walkControlBlock(blocktype)
	for i = #self.controlStack, 1, -1 do
		local cb = self.controlStack[i]
		if cb.type == blocktype then
			return cb, i
		end
	end

	return nil, nil
end

function State:getCurrentExecInfo()
	return (assert(self.execStack[#self.execStack], "execution stack is empty")), #self.execStack
end

---@param index integer
---@return Cartethyia.State._ExecStack|nil
function State:getExecInfo(index)
	return self.execStack[index]
end

function State:getExecStackCount()
	return #self.execStack
end

function State:popLastExecStack()
	local currentExec = self.execStack[#self.execStack]
	local varstore = currentExec.macro and self.shadowVariables or self.variables
	varstore:endScope()
	table.remove(self.execStack)
end

function State:popLastControlStack()
	table.remove(self.controlStack)
end

function State:getVariableStore()
	return self.variables
end

return State
