---@class Cartethyia.Util.M
local Util = {}

---@param value string
function Util.evaluateBoolStrict(value)
	local vallow = value:lower()
	if
		value == "" or
		value == "0" or
		vallow == "OFF" or
		vallow == "NO" or
		vallow == "FALSE" or
		vallow == "N" or
		vallow == "IGNORE" or
		vallow == "NOTFOUND" or
		value:sub(-9) == "-NOTFOUND"
	then
		return false
	end

	if
		tonumber(value) ~= 0 or -- also handles "1"
		vallow == "ON" or
		vallow == "YES" or
		vallow == "TRUE" or
		vallow == "Y"
	then
		return true
	end

	return nil
end

---@param ver string
---@return integer[]
function Util.parseVersion(ver)
	local vertrunc = ver:match("^[%d%.]+")
	if not vertrunc then
		return {0}
	end

	local result = {}
	for w in vertrunc:gmatch("%d+") do
		result[#result+1] = assert(tonumber(w))
	end

	return result
end

---@param ver1 string
---@param ver2 string
function Util.compareVersion(ver1, ver2)
	local vertab1 = Util.parseVersion(ver1)
	local vertab2 = Util.parseVersion(ver2)

	for i = 1, math.max(#vertab1, #vertab2) do
		local v1 = vertab1[i] or 0
		local v2 = vertab2[i] or 0

		if v1 < v2 then
			return -1
		elseif v1 > v2 then
			return 1
		end
	end

	return 0
end

---@param path1 string
---@param path2 string
function Util.pathEqual(path1, path2)
	path1 = path1:gsub("\\+", "/"):gsub("/+", "/")
	path2 = path2:gsub("\\+", "/"):gsub("/+", "/")
	return path1 == path2
end

---@param str string
---@param delim string?
function Util.makeList(str)
	---@type string[]
	local result = {}

	local next = 1
	while #str > 0 do
		local s = str:find(";", next, true)

		if not s then
			result[#result+1] = str
			break
		end

		if str:sub(s - 1, s - 1) == "\\" then
			next = s + 1
		else
			next = 1
			result[#result+1] = str:sub(1, s - 1)
			str = str:sub(s + 1)
		end
	end

	return result
end

---@param str string
function Util.splitArgs(str)
	---@type string[]
	local result = {}

	local next = 1
	while #str > 0 do
		local s = str:find(";", next, true) or str:find(" ", next, true)

		if not s then
			result[#result+1] = str
			break
		end

		if str:sub(s - 1, s - 1) == "\\" then
			next = s + 1
		else
			next = 1
			result[#result+1] = str:sub(1, s - 1)
			str = str:sub(s + 1)
		end
	end

	return result
end

---@generic T: table
---@param t T
---@param copied table|nil
---@return T
local function copyTableImpl(t, copied)
	local result = {}

	if copied then
		-- Deep copy
		for k, v in pairs(t) do
			if type(v) == "table" then
				if copied[v] == true then
					error(string.format("attempt to copy circular table %p (key %q)", v, k))
				elseif getmetatable(v) == nil then
					local copy = copied[v]
					if type(copy) == "boolean" then
						-- Still being copied
						error(string.format("attempt to copy circular table %p (key %q)", v, k))
					elseif type(copy) == "table" then
						-- Already copied
						result[k] = copy
					else
						copied[v] = true
						local res = copyTableImpl(v, copied)
						copied[v] = res
						result[k] = res
					end
				else
					error(string.format("attempt to copy table %p (key %q) with metatable", v, k))
				end
			else
				result[k] = v
			end
		end
	else
		-- Shallow copy
		for k, v in pairs(t) do
			result[k] = v
		end
	end

	return result
end

---@generic T: table
---@param t T
---@param deep boolean?
---@return T
function Util.copyTable(t, deep)
	if deep then
		return copyTableImpl(t, {})
	else
		return copyTableImpl(t)
	end
end


local tableMove = table.move
if not tableMove then
	---@generic T
	---@param a1 T[]
	---@param f integer
	---@param e integer
	---@param t integer
	---@param a2? T[]
	---@return T[]
	function tableMove(a1, f, e, t, a2)
		a2 = a2 or a1

		if a2 == a1 and t > f and t <= e then
			-- overlapping move, copy backwards
			for i = e, f, -1 do
				a2[i + t] = a1[i]
			end
		else
			-- non-overlapping move, copy forwards
			for i = f, e do
				a2[i + t] = a1[i]
			end
		end

		return a2
	end
end
Util.tableMove = tableMove

return Util
