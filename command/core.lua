local PATH = string.sub(..., 1, string.len(...) - #(".command.core"))

---@type Cartethyia.Util.M
local Util = require(PATH..".util")

---@class Cartethyia.Command.Core.M
local CoreCommands = {}

---Only exists for backward compatibility with CMake
function CoreCommands.CMAKE_MINIMUM_REQUIRED()
end

---This defines the CMake `cmake_parse_arguments()` call.
---https://cmake.org/cmake/help/v4.0/command/cmake_parse_arguments.html
---@param state Cartethyia.State
---@param args string[]
function CoreCommands.CMAKE_PARSE_ARGUMENTS(state, args)
	local destargs = {}
	local prefix
	local options
	local oneVK
	local multiVK

	if args[1] == "PARSE_ARGV" then
		-- cmake_parse_arguments(PARSE_ARGV <N> <prefix> <options> <one_value_keywords> <multi_value_keywords>)
		if #args < 6 then
			state:error("CMAKE_PARSE_ARGUMENTS PARSE_ARGV requires 5 arguments")
			return
		end

		local start = tonumber(args[2])
		if not start or start < 0 then
			state:error("CMAKE_PARSE_ARGUMENTS PARSE_ARGV start ARGV is invalid")
			return
		end

		prefix = args[3]
		options = Util.makeList(args[4])
		oneVK = Util.makeList(args[5])
		multiVK = Util.makeList(args[6])

		local i = start
		while true do
			local argname = "ARG"..i
			if state:hasVariable(argname) then
				destargs[#destargs+1] = state:getVariable(argname)
			else
				break
			end

			i = i + 1
		end
	else
		-- cmake_parse_arguments(<prefix> <options> <one_value_keywords> <multi_value_keywords> <args>...)
		if #args < 4 then
			state:error("CMAKE_PARSE_ARGUMENTS requires at least 4 arguments")
			return
		end

		prefix = args[1]
		options = Util.makeList(args[2])
		oneVK = Util.makeList(args[3])
		multiVK = Util.makeList(args[4])
		Util.tableMove(args, 5, #args, 1, destargs)
	end

	assert(prefix and options and oneVK and multiVK)
	local result = Util.parseArguments(destargs, options, oneVK, multiVK)

	for k, v in pairs(result.options) do
		local varname = prefix.."_"..k

		if v then
			state:setVariable(varname, 1)
		else
			state:unsetVariable(varname)
		end
	end

	for k, v in pairs(result.oneValueArgument) do
		local varname = prefix.."_"..k
		state:setVariable(varname, v)
	end

	for k, v in pairs(result.multiValueArgument) do
		local varname = prefix.."_"..k
		state:setVariable(varname, Util.toList(v))
	end

	if #result.missing > 0 then
		for _, k in ipairs(result.missing) do
			state:unsetVariable(k)
		end
		state:setVariable(prefix.."_KEYWORDS_MISSING_VALUES", Util.toList(result.missing))
	else
		state:unsetVariable(prefix.."_KEYWORDS_MISSING_VALUES")
	end

	if #result.unparsed > 0 then
		state:setVariable(prefix.."_unparsed", Util.toList(result.unparsed))
	else
		state:unsetVariable(prefix.."_unparsed")
	end
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

	if #args == 0 then
		state:unsetVariable(varname, parent)
	else
		state:setVariable(varname, Util.toList(args), parent)
	end
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

---@param state Cartethyia.State
---@param args string[]
function CoreCommands.UNSET(state, args)
	if #args < 1 then
		state:error("UNSET requires at least 1 argument.")
		return
	end

	state:unsetVariable(args[1], args[2] == "PARENT_SCOPE")
end

return CoreCommands
