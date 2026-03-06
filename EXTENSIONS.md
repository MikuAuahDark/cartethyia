Extensions, Differences, and Limitations
=====

In addition to standard CMake semantics minus build system-related functions, Cartethyia has some extensions,
behavior differences, and limitations.

Extensions
-----

### `CARTETHIYA` Variable

This variable is set to 1 if the CMake script is running under Cartethyia.

### `string(REPEAT)` Accepts `SEPARATOR`

For example:
```cmake
string(REPEAT "Foo" 5 BAZ SEPARATOR ";")
message(STATUS "${BAZ}")
```
Will print
```
-- Foo;Foo;Foo;Foo;Foo
```

### `math(FEXPR <var> "<expr>" [OUTPUT_PRECISION <DEFAULT|FULL>])` For Floating-Point Math

The original CMake requires `math(EXPR)` to be evaluated in 64-bit signed integer. However, Lua (< 5.3) does not
natively support 64-bit integer arithmetic. `math(FEXPR)` simply performs all evaluations in double-precision floating
point instead.

The `OUTPUT_PRECISION` controls the format specifier for the resulting nuber before storing into `var`:
* `DEFAULT` uses `%.14g` `string.format` specifier. This is the default is no `OUTPUT_PRECISION` is specified.
* `FULL` uses `%.17f` `string.format` specifier.

For example:
```cmake
math(FEXPR val1 "0.1 + 0.2")
math(FEXPR val2 "0.1 + 0.2" OUTPUT_PRECISION FULL)
message(STATUS "val1 = ${val1}")
message(STATUS "val2 = ${val2}")
```
Will print
```
-- val1 = 0.3
-- val2 = 0.30000000000000004
```

Differences
-----

### Regex-Related Function is not CMake-compliant

Due to limitation with Lua, regex related matching currently uses Lua pattern matching instead of standard CMake
regex.

### `cmake_minimum_required` Does Nothing

Cartethyia targets CMake 4 syntax and semantics.

Limitations
-----

### `math(EXPR)` Requires LuaJIT

Due to CMake requirement on 64-bit arithmetic on `math(EXPR)`, support for this currently requires running under
LuaJIT.

Support for Lua 5.3 64-bit integer arithmetic is welcome.
