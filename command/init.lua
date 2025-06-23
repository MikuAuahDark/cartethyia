local PATH = string.sub(..., 1, string.len(...) - #(".command"))

---@class Cartethyia.Commands.M
local Commands = {}

---@type Cartethyia.Command.Core.M
Commands.Core = require(PATH..".command.core")
---@type Cartethyia.Command.Control.M
Commands.Control = require(PATH..".command.control")

return Commands
