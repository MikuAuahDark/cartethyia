local PATH = string.sub(..., 1, string.len(...) - #(".command.core"))

---@class Cartethyia.Command.Core.M
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

---@type Cartethyia.Command.String.SubCommand
local StringSubCommands = require(PATH..".command.string")

---@param state Cartethyia.State
---@param args string[]
---@param isUnquoted boolean[]
function CoreCommands.STRING(state, args, isUnquoted)
	local currentsub = StringSubCommands
	local subcmd
	local lastsubcmd

	while true do
		---@type string?
		subcmd = table.remove(args, 1)
		table.remove(isUnquoted, 1)

		if not subcmd then
			if lastsubcmd then
				state:error("STRING sub-command"..lastsubcmd.." requires a mode to be specified.")
			else
				state:error("STRING must be called with at least one argument.")
			end

			return
		end

		lastsubcmd = (lastsubcmd or "").." "..subcmd

		local target = currentsub[subcmd]
		if not target then
			state:error("STRING does not recognize sub-command"..lastsubcmd)
			return
		elseif type(target) == "table" then
			currentsub = target
		else
			return target(state, args, isUnquoted)
		end
	end
end

return CoreCommands
