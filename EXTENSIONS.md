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

The `OUTPUT_PRECISION` controls the format specifier for the resulting expression:
* `DEFAULT` uses `%.14g` in `string.format`.
* `FULL` uses `%.17f` in `string.format`.

Differences
-----

### Regex-Related Function is not CMake-compliant

Due to limitation with Lua, regex related matching currently uses Lua pattern matching instead of standard CMake
regex.

### `cmake_minimum_required` Does Nothing

Cartethyia targets CMake 4 syntax and semantics.

Limitations
-----

#### `math(EXPR)` Requires LuaJIT

Due to CMake requirement on 64-bit arithmetic on `math(EXPR)`, support for this currently requires running under
LuaJIT.

Support for Lua 5.3 64-bit integer arithmetic is welcome.