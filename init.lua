---@type string
local PATH = ...

if PATH:sub(-5) == ".init" then
	PATH = PATH:sub(1, -6)
end

---@class Cartethyia.M
local Cartethyia = {}

---@type Cartethyia.State.M
Cartethyia.State = require(PATH..".state")
---@type Cartethyia.CMDControl.M
Cartethyia.ControlCommands = require(PATH..".cmdcontrol")
---@type Cartethyia.CMDCore.M
Cartethyia.CoreCommands = require(PATH..".cmdcore")

function Cartethyia.newInterpreter()
	local state = Cartethyia.State()
	state:registerLuaFunctions(Cartethyia.ControlCommands)
	state:registerLuaFunctions(Cartethyia.CoreCommands)

	if package.path:find("\\", 1, true) then
		state:setVariable("WIN32", "1")
	end

	return state
end

---@type Cartethyia.Parser.M
local parser = require(PATH..".parser")
Cartethyia.parse = parser.parse

return Cartethyia
