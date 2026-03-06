Cartethyia
=====

An implementation of [CMake language](https://cmake.org/cmake/help/v4.0/manual/cmake-language.7.html) interpreter
written in Lua for general scripting purpose.

Quickstart
-----

Assume you have all the Lua files in a folder `cartethyia`, this is how you start bootstrap the CMake interpreter.

```lua
-- Load the library
local cartethyia = require("cartethyia")

-- Create enw interpreter state
local state = cartethyia.newInterpreter()

-- If you want to make `$ENV{stuff}` works as variable, uncomment line below.
-- state:registerInterpolatorExpansion("ENV", os.getenv)

-- Load the CMake script.
local filename = "cmake_script.cmake"
local f = assert(io.open(filename, "rb"))
local input = f:read("*a")
f:close()

-- Parse the CMake script
local parsed, errinfo = cartethyia.parse(input)
if not parsed then
	error("CMake parse error at col "..errinfo.column.." line "..errinfo.line..": "..errinfo.message)
end

-- Set the interpreter to begin executing first line of the script
assert(state:execute(parsed, filename))
-- Run the script until end.
-- See the implementation of `:run()` function if you want to perform single-stepping instead.
local status, msg = state:run()
-- If `status` does not return true, then there's error in your CMake script.
if not status then
	-- Print error and the traceback
	local tb = state:traceback()
	print("Error: "..msg)
	for _, v in ipairs(tb) do
		print(v[1].." line "..v[2])
	end
	error(msg)
end
```
