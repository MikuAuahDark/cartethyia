local PATH = string.sub(..., 1, string.len(...) - #(".command.list"))

---@type Cartethyia.Util.M
local Util = require(PATH..".util")

---@class Cartethyia.Command.List.SubCommand
local ListSubCommands = {}

---@param state Cartethyia.State
---@param args string[]
---@param isunq boolean[]
function ListSubCommands.LENGTH(state, args, isunq)
	if #args < 2 then
		state:error("LIST sub-command LENGTH requires 2 arguments.")
		return
	end

	local input = args[1]
	if isunq[1] then
		input = state:getVariable(input)
	end

	local list = Util.makeList(input)
	state:setVariable(args[2], #list)
end

---@param state Cartethyia.State
---@param args string[]
---@param isunq boolean[]
function ListSubCommands.GET(state, args, isunq)
	if #args < 3 then
		state:error("LIST sub-command LENGTH requires at least 3 arguments.")
		return
	end

	local input = table.remove(args, 1)
	local output = table.remove(args)
	table.remove(isunq)
	if table.remove(isunq, 1) then
		if state:hasVariable(input) then
			input = state:getVariable(input)
		else
			state:setVariable(output, "NOTFOUND")
			return
		end
	end

	local list = Util.makeList(input)
	local listlen = #list
	local result = {}
	for _, v in ipairs(args) do
		local n = tonumber(v)
		if not n then
			state:error("LIST index: "..v.." is not a valid index")
			return
		end

		if n < -listlen or n >= listlen then
			state:error("LIST index: "..n.." out of range ("..-listlen..", "..(listlen - 1)")")
			return
		end

		if n < 0 then
			result[#result+1] = list[listlen + n + 1]
		else
			result[#result+1] = list[n + 1]
		end
	end

	state:setVariable(output, Util.toList(result))
end


---@param state Cartethyia.State
---@param args string[]
---@param isunq boolean[]
function ListSubCommands.JOIN(state, args, isunq)
	if #args < 3 then
		state:error("LIST sub-command JOIN requires 3 arguments.")
		return
	end

	local input = args[1]
	if isunq[1] then
		input = state:getVariable(input, input)
	end

	local list = Util.makeList(input)
	state:setVariable(args[3], table.concat(list, args[2]))
end

---@param state Cartethyia.State
---@param args string[]
---@param isunq boolean[]
function ListSubCommands.SUBLIST(state, args, isunq)
	if #args < 4 then
		state:error("LIST sub-command SUBLIST requires 4 arguments.")
		return
	end

	local input = args[1]
	if isunq[1] then
		input = state:getVariable(input, "")
	end

	local list = Util.makeList(input)
	local begin = tonumber(args[2])
	if not begin or begin >= #list or begin < 0 then
		state:error("LIST sub-command SUBLIST begin index invalid or out-of-range.")
		return
	end

	local length = tonumber(args[3])
	if not length then
		state:error("LIST sub-command SUBLIST length invalid.")
		return
	end

	if length == -1 then
		length = #list
	end

	local result = {}
	Util.tableMove(list, begin + 1, math.min(begin + length + 1, #list), 1, result)
	state:setVariable(args[4], Util.toList(result))
end

---@param state Cartethyia.State
---@param args string[]
---@param isunq boolean[]
function ListSubCommands.FIND(state, args, isunq)
	if #args < 3 then
		state:error("LIST sub-command FIND requires 3 arguments.")
		return
	end

	local input = args[1]
	if isunq[1] then
		input = state:getVariable(input)
	end

	local list = Util.makeList(input)
	local tobesearch = args[2]

	for i, v in ipairs(list) do
		if v == tobesearch then
			state:setVariable(args[3], i - 1)
		end
	end

	state:setVariable(args[3], -1)
end

---@param state Cartethyia.State
---@param args string[]
function ListSubCommands.APPEND(state, args)
	if #args < 1 then
		state:error("LIST sub-command APPEND requires at least 1 argument.")
		return
	end

	local input = args[1]
	local list = Util.makeList(state:getVariable(input))
	Util.tableMove(args, 2, #args, #list, list)
	state:setVariable(input, Util.toList(list))
end

-- TODO: list(INSESRT|POP_BACK|POP_FRONT)

---@param state Cartethyia.State
---@param args string[]
function ListSubCommands.PREPEND(state, args)
	if #args < 1 then
		state:error("LIST sub-command PREPEND requires at least 1 argument.")
		return
	end

	local input = args[1]
	local list = Util.makeList(state:getVariable(input))
	local result = {}
	Util.tableMove(args, 2, #args, 1, result)
	Util.tableMove(args, 1, #list, #result, result)
	state:setVariable(input, Util.toList(result))
end

return ListSubCommands
