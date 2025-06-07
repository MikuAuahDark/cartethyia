---@class Cartethyia.Interpolator
local Interpolator = {}
---@package
Interpolator.__index = Interpolator

---@alias Cartethyia.Interpolator.Expansion 
---| fun(name:string):(string?)
---| table<string, any?>

---@param defaultExpansion Cartethyia.Interpolator.Expansion 
function Interpolator:new(defaultExpansion)
	self.expansions = {
		[""] = defaultExpansion
	}

	---@param backslash string
	---@param expansion string
	---@param name string
	function self.expansionImpl(backslash, expansion, name)
		if #backslash % 2 == 0 then
			local expansionObj = self.expansions[expansion]
			if not expansionObj then
				return ""
			end

			local expandedName = self:interpolate(name:sub(2, -2))
			if type(expansionObj) == "function" then
				return backslash..tostring(expansionObj(expandedName) or "")
			else
				return backslash..tostring(expansionObj[expandedName] or "")
			end
		else
			-- Return original but keep expanding the inner part
			return backslash:sub(1, -2).."$"..expansion.."{"..self:interpolate(name:sub(2, -2)).."}"
		end
	end
end

---@param expname string
---@param expansion Cartethyia.Interpolator.Expansion?
function Interpolator:setExpansion(expname, expansion)
	self.expansions[expname] = expansion
end

---@param str string
function Interpolator:interpolate(str)
	return (str:gsub("([\\]*)%$(%w*)(%b{})", self.expansionImpl))
end

setmetatable(Interpolator, {
	__call = function(_, ...)
		local obj = setmetatable({}, Interpolator)
		Interpolator.new(obj, ...)
		return obj
	end
})

---@alias Cartethyia.Interpolator.new fun(defaultExpansion:Cartethyia.Interpolator.Expansion):Cartethyia.Interpolator
---@alias Cartethyia.Interpolator.M Cartethyia.Interpolator | Cartethyia.Interpolator.new
---@cast Interpolator +Cartethyia.Interpolator.new
return Interpolator
