---@type string
local PATH = ...

if PATH:sub(-5) == ".init" then
	PATH = PATH:sub(1, -6)
end

---@module "command.math.parser"
local parser = require(PATH..".parser")

local characteristicsForCMakeCompliance = nil
if jit then
	-- Has characteristics for LuaJIT
	local zero = loadstring("return 0LL")() --[[@as integer]]

	--- @param s string
	--- @return integer?
	local function strtolli(s)
		-- Trim whitespace
		s = s:match("^%s*(.-)%s*$")

		-- Sign
		local neg = false
		if s:sub(1,1) == '-' then
			neg = true
			s = s:sub(2)
		elseif s:sub(1,1) == '+' then
			s = s:sub(2)
		end

		-- Truncate at decimal point
		local dot = s:find('.', 1, true)
		if dot then
			s = s:sub(1, dot - 1)
		end

		local result = zero --[[@as integer]]

		-- Hex path
		if s:sub(1,2):lower() == '0x' then
			s = s:sub(3)
			if #s == 0 then return result end

			for i = 1, #s do
				local c = s:sub(i,i)
				local digit
				if c >= '0' and c <= '9' then
					digit = c:byte() - ('0'):byte()
				elseif c >= 'a' and c <= 'f' then
					digit = c:byte() - ('a'):byte() + 10
				elseif c >= 'A' and c <= 'F' then
					digit = c:byte() - ('A'):byte() + 10
				else
					return nil
				end
				result = result * 16 + (digit + zero)
			end

		-- Decimal path
		else
			if #s == 0 then return result end

			for i = 1, #s do
				local c = s:sub(i,i)
				if c < '0' or c > '9' then
					return nil
				end
				local digit = c:byte() - ('0'):byte()
				result = result * 10 + (digit + zero)
			end
		end

		-- Negate: for signed two's complement mod 2^64, this is exact
		if neg then
			result = -result
		end

		return result
	end

	---@type Cartethyia._MathParser.Characteristics<integer>
	characteristicsForCMakeCompliance = {
		stringToInt = strtolli,
		truncate = function(n) return n + 0LL end,
		-- LuaJIT 2.1 support boxed 64-bit bitwise
		bor = bit.bor,
		band = bit.band,
		bxor = bit.bxor,
		bnot = bit.bnot,
		lshift = bit.lshift,
		rshift = bit.arshift,
		luajit = true,
	}
end

---@class Cartethyia.Command.Math
local Math = {}

---@param state Cartethyia.State
---@param args string[]
function Math.MATH(state, args)
	if #args < 3 then
		state:error("MATH called with incorrect number of arguments")
		return
	end

	if args[1] == "EXPR" then
		if not characteristicsForCMakeCompliance then
			state:error("Platform does not support CMake-compliant math evaluation.")
			return
		end

		local hex = false
		if args[4] == "OUTPUT_FORMAT" then
			if args[5] == "HEXADECIMAL" then
				hex = true
			elseif args[5] ~= "DECIMAL" then
				state:error("math(EXPR) called with incorrect number of arguments")
				return
			end
		end

		local result, msg = parser.parse(args[3], characteristicsForCMakeCompliance)
		if not result then
			state:error(msg or "Unknown error parsing expression")
			return
		end

		-- TODO: Non-LuaJIT
		if hex then
			result = string.format("0x%X", result)
		else
			result = string.format("%d", result)
		end

		state:setVariable(args[2], result)
	elseif args[2] == "FEXPR" then
		local result, msg = parser.parse(args[3])
		if not result then
			state:error(msg or "Unknown error parsing expression")
			return
		end

		state:setVariable(args[2], result)
	else
		state:error("MATH does not recognize sub-command "..string(args[1]))
	end
end

return Math
