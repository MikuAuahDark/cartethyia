local MathParser = {}

---@class Cartethyia._MathParser.Token<T>
---@field type "LPAREN"|"RPAREN"|"PLUS"|"MINUS"|"MUL"|"DIV"|"MOD"|"BAND"|"BOR"|"BXOR"|"BN"|"LSH"|"RSH"|"NUMBER"
---@field value T?

---@generic T
---@param input string
---@param chars Cartethyia._MathParser.Characteristics<T>
---@return Cartethyia._MathParser.Token<T>[]?, string?
local function tokenize(input, chars)
	---@type Cartethyia._MathParser.Token[]
	local tokens = {}
	local i = 1
	while i <= #input do
		local char = input:sub(i, i)
		if char:match("%s") then
			i = i + 1
		elseif char == "(" then
			tokens[#tokens + 1] = {type = "LPAREN"}
			i = i + 1
		elseif char == ")" then
			tokens[#tokens + 1] = {type = "RPAREN"}
			i = i + 1
		elseif char == "+" then
			tokens[#tokens + 1] = {type = "PLUS"}
			i = i + 1
		elseif char == "-" then
			tokens[#tokens + 1] = {type = "MINUS"}
			i = i + 1
		elseif char == "*" then
			tokens[#tokens + 1] = {type = "MUL"}
			i = i + 1
		elseif char == "/" then
			tokens[#tokens + 1] = {type = "DIV"}
			i = i + 1
		elseif char == "%" then
			tokens[#tokens + 1] = {type = "MOD"}
			i = i + 1
		elseif char == "&" then
			tokens[#tokens + 1] = {type = "BAND"}
			i = i + 1
		elseif char == "|" then
			tokens[#tokens + 1] = {type = "BOR"}
			i = i + 1
		elseif char == "^" then
			tokens[#tokens + 1] = {type = "BXOR"}
			i = i + 1
		elseif char == "~" then
			tokens[#tokens + 1] = {type = "BN"}
			i = i + 1
		elseif char == "<" and input:sub(i + 1, i + 1) == "<" then
			tokens[#tokens + 1] = {type = "LSH"}
			i = i + 2
		elseif char == ">" and input:sub(i + 1, i + 1) == ">" then
			tokens[#tokens + 1] = {type = "RSH"}
			i = i + 2
		elseif char:match("%d") or (char == "0" and input:sub(i + 1, i + 1):lower() == "x") then
			local numstr = ""
			local value = nil

			if char == "0" and input:sub(i + 1, i + 1):lower() == "x" then
				numstr = input:match("0[xX][%da-fA-F]+", i)
				i = i + #numstr
				value = chars.stringToInt(numstr)
			else
				numstr = input:match("[%d%.]+", i)
				i = i + #numstr
				value = chars.stringToInt(numstr)
			end

			if not value then
				return nil, "Invalid number: "..tostring(numstr)
			end

			tokens[#tokens + 1] = {type = "NUMBER", value = value}
		else
			return nil, "Unexpected character at "..i..": "..char
		end
	end

	return tokens
end


---@class Cartethyia._MathParser.Characteristics<T>
---@field stringToInt fun(number:string): T?
---@field truncate fun(number:T): T
---@field bor fun(number:T, number:T): T
---@field band fun(number:T, number:T): T
---@field bxor fun(number:T, number:T): T
---@field bnot fun(number:T): T
---@field lshift fun(number:T, number:T): T
---@field rshift fun(number:T, number:T): T


local defaultCharacteristics = nil
local ok, bit, bit32
ok, bit = pcall(require, "bit")
if ok then
	---@type Cartethyia._MathParser.Characteristics<number>
	defaultCharacteristics = {
		stringToInt = tonumber,
		truncate = function(n)
			if n > 0 then
				return math.floor(n)
			else
				return math.ceil(n)
			end
		end,
		bor = bit.bor,
		band = bit.band,
		bxor = bit.bxor,
		bnot = bit.bnot,
		lshift = bit.lshift,
		rshift = bit.arshift,
	}
end
ok, bit32 = pcall(require, "bit32")
if ok then
	---@type Cartethyia._MathParser.Characteristics<number>
	defaultCharacteristics = {
		stringToInt = tonumber,
		truncate = function(n)
			if n > 0 then
				return math.floor(n)
			else
				return math.ceil(n)
			end
		end,
		bor = bit32.bor,
		band = bit32.band,
		bxor = bit32.bxor,
		bnot = bit32.bnot,
		lshift = bit32.lshift,
		rshift = bit32.arshift,
	}
end
if not defaultCharacteristics then
	error("missing bit support library")
end


---@generic T
---@param input string
---@param characteristics Cartethyia._MathParser.Characteristics<T>
---@return T?, string?
---@overload fun(input:string):(number?,string?)
function MathParser.parse(input, characteristics)
	characteristics = characteristics or defaultCharacteristics
	local tokens, msg = tokenize(input, characteristics)
	if not tokens then
		return nil, (assert(msg))
	end

	local pos = 1

	local function peek()
		return tokens[pos]
	end

	local function consume()
		local t = tokens[pos]
		pos = pos + 1
		return t
	end

	local function expect(type)
		local t = peek()
		if t.type ~= type then
			return nil, "Expected "..type.." but got "..t.type
		end
		return consume()
	end

	-- Precedence:
	-- 1. `()` Parentheses, Numbers
	-- 2. `~`, unary `+`, `-`
	-- 3. `*`, `/`, `%`
	-- 4. binary `+`, `-`
	-- 5. `<<`, `>>`
	-- 6. `&` (Bitwise AND)
	-- 7. `^` (Bitwise XOR)
	-- 8. `|` (Bitwise OR)

	local expression -- Forward declaration

	-- 1. Primary (Numbers and ())
	local function primary()
		local t = peek()
		if not t then
			return nil, "Unexpected end of expression"
		elseif t.type == "NUMBER" then
			return consume().value
		elseif t.type == "LPAREN" then
			consume()
			local v = expression()
			expect("RPAREN")
			return v
		else
			return nil, "Unexpected token: " .. t.type
		end
	end

	-- 2. Unary
	local function unary()
		local t = peek()
		if not t then
			return primary()
		elseif t.type == "PLUS" then
			consume()
			local value, errmsg = unary()
			if not value then
				return nil, errmsg
			end
			return value
		elseif t.type == "MINUS" then
			consume()
			local value, errmsg = unary()
			if not value then
				return nil, errmsg
			end
			return -value
		elseif t.type == "BN" then
			consume()
			local value, errmsg = unary()
			if not value then
				return nil, errmsg
			end
			return characteristics.bnot(characteristics.truncate(value))
		else
			return primary()
		end
	end

	-- 3. Multiplicative
	local function multiplicative()
		local v, emsg = unary()
		if not v then
			return nil, emsg
		end
		while true do
			local t = peek()
			if not t then
				break
			elseif t.type == "MUL" then
				consume()
				local value, errmsg = unary()
				if not value then
					return nil, errmsg
				end
				v = v * value
			elseif t.type == "DIV" then
				consume()
				local value, errmsg = unary()
				if not value then
					return nil, errmsg
				end
				v = v / value
			elseif t.type == "MOD" then
				consume()
				local value, errmsg = unary()
				if not value then
					return nil, errmsg
				end
				v = v % value
			else
				break
			end
		end
		return v
	end

	-- 4. Additive
	local function additive()
		local v, emsg = multiplicative()
		if not v then
			return nil, emsg
		end
		while true do
			local t = peek()
			if not t then
				break
			elseif t.type == "PLUS" then
				consume()
				local value, errmsg = multiplicative()
				if not value then
					return nil, errmsg
				end
				v = v + value
			elseif t.type == "MINUS" then
				consume()
				local value, errmsg = multiplicative()
				if not value then
					return nil, errmsg
				end
				v = v - value
			else
				break
			end
		end
		return v
	end

	-- 5. Shift
	local function shift()
		local v, emsg = additive()
		if not v then
			return nil, emsg
		end
		while true do
			local t = peek()
			if not t then
				break
			elseif t.type == "LSH" then
				consume()
				local value, errmsg = shift()
				if not value then
					return nil, errmsg
				end
				v = characteristics.lshift(v, characteristics.truncate(value))
			elseif t.type == "RSH" then
				consume()
				local value, errmsg = shift()
				if not value then
					return nil, errmsg
				end
				v = characteristics.rshift(v, characteristics.truncate(value))
			else
				break
			end
		end
		return v
	end

	-- 6. Bitwise AND
	local function bit_and()
		local v, emsg = shift()
		if not v then
			return nil, emsg
		end
		while true do
			local t = peek()
			if not t or t.type ~= "BAND" then
				break
			end

			consume()
			local value, errmsg = shift()
			if not value then
				return nil, errmsg
			end
			v = characteristics.band(v, characteristics.truncate(value))
		end
		return v
	end

	-- 7. Bitwise XOR
	local function bit_xor()
		local v, emsg = bit_and()
		if not v then
			return nil, emsg
		end
		while true do
			local t = peek()
			if not t or t.type ~= "BXOR" then
				break
			end

			consume()
			local value, errmsg = bit_and()
			if not value then
				return nil, errmsg
			end
			v = characteristics.bxor(v, characteristics.truncate(value))
		end
		return v
	end

	-- 8. Bitwise OR
	local function bit_or()
		local v, emsg = bit_xor()
		if not v then
			return nil, emsg
		end
		while true do
			local t = peek()
			if not t or t.type ~= "BOR" then
				break
			end

			consume()
			local value, errmsg = bit_xor()
			if not value then
				return nil, errmsg
			end
			v = characteristics.bor(v, characteristics.truncate(value))
		end
		return v
	end

	expression = bit_or

	local result = expression()
	if peek() then
		return nil, "Unexpected token at end of expression: "..consume().type
	end
	return result
end

return MathParser
