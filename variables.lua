local PATH = string.sub(..., 1, string.len(...) - #(".variables"))

---@type Cartethyia.Util.M
local Util = require(PATH..".util")

---@class Cartethyia.Variables
local Variables = {}
---@package
Variables.__index = Variables

---@alias Cartethyia.Variables.VariableStore table<string, {value:string|nil}>

---@class Cartethyia.Variables.Store
---@field public softCaptures Cartethyia.Variables.VariableStore[] If this is set, variables in this list is restored after exiting the scope.
---@field public variables Cartethyia.Variables.VariableStore List of variables.

---@param vars? Cartethyia.Variables.Store[]
---@package
function Variables:new(vars)
	---@private
	self.stack = {} ---@type Cartethyia.Variables.Store[]

	if vars then
		self.stack = Util.copyTable(vars)
	else
		self:beginScope()
	end
end

function Variables:beginScope()
	self.stack[#self.stack+1] = {softCaptures = {}, variables = {}}
end

---@param captureVars string[]
function Variables:beginSoftScope(captureVars)
	local softCaptures = {}
	for _, v in ipairs(captureVars) do
		if self:has(v, 0, true) then
			softCaptures[v] = {value = self:get(v)}
		else
			softCaptures[v] = {}
		end
	end

	local currentStack = self.stack[#self.stack]
	currentStack.softCaptures[#currentStack.softCaptures+1] = softCaptures
end

---@param propagate string[]?
function Variables:endScope(propagate)
	assert(#self.stack > 1, "no parent scope")

	---@type Cartethyia.Variables.Store
	local lastTop = table.remove(self.stack)

	if propagate then
		for _, k in ipairs(propagate) do
			local value = lastTop[k]
			if value then
				if value.value ~= nil then
					self:set(k, value.value)
				else
					self:unset(k)
				end
			end
		end
	end
end

function Variables:endSoftScope()
	---@type Cartethyia.Variables.Store
	local currentStack = self.stack[#self.stack]
	assert(table.remove(currentStack.softCaptures), "no soft scope for current variable scope")
end

---@param name string
---@param scopenum integer?
function Variables:get(name, scopenum)
	scopenum = scopenum or #self.stack
	local stack = self.stack[scopenum]
	if stack and stack[name] then
		return stack[name].value or ""
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
		if stack and stack[name] then
			return stack[name].value ~= nil
		end

		return false
	else
		for i = scopenum, 1, -1 do
			local stack = self.stack[i]
			if stack[name] then
				return stack[name].value ~= nil
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

	self.stack[scopenum][name] = {value = tostring(value)}
end

function Variables:unset(name, scopenum)
	scopenum = scopenum or #self.stack
	if scopenum <= 0 then
		scopenum = #self.stack + scopenum
	end

	local stack = self.stack[scopenum]
	if stack[name] then
		if scopenum == 1 then
			stack[name] = nil
		else
			stack[name].value = nil
		end
		return true
	end

	return false
end

---@return table<string, {value:string|nil}>[]
function Variables:serialize()
	return Util.copyTable(self.stack, true)
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

---@alias Cartethyia.Variables.new fun(vars?:table<string, {value:string|nil}>[]):Cartethyia.Variables
---@alias Cartethyia.Variables.M Cartethyia.Variables | Cartethyia.Variables.new
---@cast Variables +Cartethyia.Variables.new
return Variables
