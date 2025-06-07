local PATH = string.sub(..., 1, string.len(...) - #(".variables"))

---@type Cartethyia.Util.M
local Util = require(PATH..".util")

---@class Cartethyia.Variables
local Variables = {}
---@package
Variables.__index = Variables

---@param vars? table<string, string>[]
---@package
function Variables:new(vars)
	---@private
	self.stack = {} ---@type table<string, string>[]

	if vars then
		self.stack = Util.copyTable(vars)
	end
end

function Variables:beginScope()
	self.stack[#self.stack+1] = {}
end

function Variables:endScope()
	assert(#self.stack > 1, "no parent scope")
	table.remove(self.stack)
end

---@param name string
---@param scopenum integer?
function Variables:get(name, scopenum)
	scopenum = scopenum or #self.stack
	local stack = self.stack[scopenum]
	if stack then
		return stack[name] or ""
	end

	return ""
end

---@param name string
---@param scopenum integer?
---@param exactscopenum boolean?
function Variables:has(name, scopenum, exactscopenum)
	scopenum = scopenum or #self.stack
	if scopenum <= 0 then
		scopenum = #self.stack + scopenum
	end

	if exactscopenum then
		local stack = self.stack[scopenum]
		if stack then
			return not not stack[name]
		end

		return false
	else
		for i = scopenum, 1, -1 do
			local stack = self.stack[i]
			if stack[name] then
				return true
			end
		end

		return false
	end
end

---@param name string
---@param value string
---@param scopenum integer?
function Variables:set(name, value, scopenum)
	scopenum = scopenum or #self.stack
	if scopenum <= 0 then
		scopenum = #self.stack + scopenum
	end

	self.stack[scopenum][name] = tostring(value)
end

function Variables:unset(name, scopenum)
	scopenum = scopenum or #self.stack
	if scopenum <= 0 then
		scopenum = #self.stack + scopenum
	end

	local stack = self.stack[scopenum]
	if stack[name] then
		stack[name] = nil
		return true
	end

	return false
end

---@return table<string, string>[]
function Variables:serialize()
	local result = {}

	for _, stack in ipairs(self.stack) do
		local s = {}

		for k, v in pairs(stack) do
			s[k] = v
		end

		result[#result + 1] = s
	end

	return result
end

function Variables:getStackCount()
	return #self.stack
end

setmetatable(Variables, {
	__call = function(_, ...)
		local obj = setmetatable({}, Variables)
		Variables.new(obj, ...)
		return obj
	end
})

---@alias Cartethyia.Variables.new fun(vars?:table<string, string>[]):Cartethyia.Variables
---@alias Cartethyia.Variables.M Cartethyia.Variables | Cartethyia.Variables.new
---@cast Variables +Cartethyia.Variables.new
return Variables
