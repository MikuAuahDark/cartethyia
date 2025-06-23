Extensions
=====

In addition to standard CMake semantics minus build system-related functions, Cartethyia adds some extensions:

`CARTETHIYA` Variable
-----

This variable is set to 1 if the CMake script is running under Cartethyia.

`string(REPEAT)` Accepts `SEPARATOR`
-----

For example:
```cmake
string(REPEAT "Foo" 5 BAZ SEPARATOR ";")
message(STATUS "${BAZ}")
```
Will print
```
-- Foo;Foo;Foo;Foo;Foo
```
