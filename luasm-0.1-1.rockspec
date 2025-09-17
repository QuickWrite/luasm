package = "LuASM"
version = "0.1-1"

source = {
   url = "git+https://github.com/QuickWrite/luasm.git",
   branch = "main"
}

description = {
   summary = "A library to parse and execute custom ASM.",
   detailed = "A library to parse and execute custom ASM. It is a light-weight Lua library that lets you define, parse and later execute a custom assembly-like language. And the library is deliberately minimal.",
   homepage = "https://github.com/QuickWrite/luasm",
   license = "MIT"
}

dependencies = {
   "lua >= 5.1",
}

build = {
   type = "builtin",
   modules = {
      luasm = "src/luasm.lua"
   }
}
