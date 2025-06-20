---@alias Cartethyia.CMDCore.M table<string, Cartethyia.State._LuaFunction>
---@type Cartethyia.CMDCore.M
local CoreCommands = {}

---Only exists for backward compatibility with CMake
function CoreCommands.CMAKE_MINIMUM_REQUIRED()
end

---This defines the CMake `message()` command.
---@param state Cartethyia.State
---@param args string[]
function CoreCommands.MESSAGE(state, args)
	if #args < 1 then
		state:error("message() called with incorrect number of arguments")
		return
	end

	local cmd = args[1]
	if cmd == "FATAL_ERROR" then
		state:fatalError(table.concat(args, "", 2))
	elseif cmd == "SEND_ERROR" then
		state:sendError(table.concat(args, "", 2))
	elseif cmd == "WARNING" then
		state:warning(table.concat(args, "", 2))
	elseif cmd == "AUTHOR_WARNING" then
		state:warningDev(table.concat(args, "", 2))
	elseif cmd == "DEPRECATION" then
		state:deprecated(table.concat(args, "", 2))
	elseif cmd == "NOTICE" then
		state:messageStderr(table.concat(args, "", 2))
	elseif cmd == "STATUS" then
		state:messageStderr("-- "..table.concat(args, "", 2))
	elseif cmd == "VERBOSE" then
		-- TODO: Log level
		state:messageStderr("-- "..table.concat(args, "", 2))
	elseif cmd == "DEBUG" then
		-- TODO: Log level
		state:messageStderr("-- "..table.concat(args, "", 2))
	elseif cmd == "TRACE" then
		-- TODO: Log level
		state:messageStderr("-- "..table.concat(args, "", 2))
	else
		-- Same as NOTICE
		state:messageStderr(table.concat(args))
	end
end

---@param state Cartethyia.State
---@param args string[]
function CoreCommands.SET(state, args)
	if #args < 1 then
		state:error("SET called with incorrect number of arguments")
	end

	---@type string
	local varname = table.remove(args, 1)
	local parent = false

	if args[#args] == "PARENT_SCOPE" then
		if state:hasParentScope() then
			table.remove(args)
			parent = true
		else
			state:warningDev("Cannot set \""..varname.."\": current scope has no parent.")
			return
		end
	end

	state:setVariable(varname, table.concat(args, ";"), parent)
end

return CoreCommands
