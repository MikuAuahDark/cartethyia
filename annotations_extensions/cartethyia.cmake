# Cartethyia-specific annotation extensions meant to be loaded with Fleurdelys.

## This variable is set to 1 if the CMake script is running under Cartethyia.
## set(CARTETHYIA)

## Repeat a string a specified number of times, with separator.
##
## **Warning**: This is Cartethyia extension, not an official CMake function.
##
## function(string REPEAT <?string> <?count> <&output> SEPARATOR <?sep>)

## Evaluate an expression with double-precision floating-point arithmetic, optionally formatting the result with
## default (`%.14g` in `printf`) or full precision (`%.17f` in `printf`).
##
## **Warning**: This is Cartethyia extension, not an official CMake function.
##
## function(math FEXPR <&output> <?expression> [PRECISION <DEFAULT|FULL>])
