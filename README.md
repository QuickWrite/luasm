# LuASM
A library to parse and execute custom ASM.

It is a light‑weight Lua library that lets you define, parse and later execute a custom assembly‑like language. <br />
And the library is deliberately minimal:
- No external dependencies – pure Lua 5.1+.
- Pluggable instruction set – you decide which mnemonics exist and how their operands are interpreted.
- Configurable syntax – label delimiters, immediate prefixes, register prefixes, etc., are all driven by a settings table.
- Tokenizer abstraction – you can feed source from a string, a file, or any other stream by providing a get_next_line method.
- Execute the code - you can also define the behaviour of the instruction and with that execute this code.

## Installation
Because LuASM is a single Lua file, installation is straightforward:

```shell
# Clone the repository (or copy the file into your project)
git clone https://github.com/quickwrite/luasm.git
```

Or, if you just need the file:

```lua
-- In your project directory
luasm.lua   # <-- the file you just saw
```

No external libraries are required; the code runs on any Lua interpreter (5.1, 5.2, 5.3, LuaJIT, etc.).

## Quick Start
```lua
local LuASM = require("luasm")

-- 1. Define the instruction set
local instructions = {
    LuASM.instruction("mov", {"imm", "reg"}, {}),
    LuASM.instruction("mov", {"reg", "reg"}, {}),
    LuASM.instruction("add", {"reg", "reg"}, {}),
    LuASM.instruction("jmp", {"label"}, {}),
}

-- 2. Create a runner (use default settings)
local asm = LuASM:new(instructions, {})

-- 3. Tokenize a source string
local src = [[
start:  mov 10 r0
        add  r0 r1
        jmp  start
]]
local tokenizer = asm:string_tokenizer(src)

-- 4. Parse
local result = asm:parse(tokenizer)

print("Lines parsed:", result.parsed_lines)
for name, info in pairs(result.labels) do
    print("Label: " .. name .. " -> line: " .. info.location)
end

for i, instr in ipairs(result.instructions) do
    print(i, instr.op)   -- currently just the instruction name
end
```
Which should result in something like this:
```txt
Lines parsed:   4
Label: start -> line:   1
1       mov
2       add
3       jmp
```

## Examples
To see other examples, they can be found in the [`examples/`](examples) directory. To execute them the README inside this directory should be followed.

These examples are numbered so that they can be viewed in sequential order.

## Version
This project is currently in Version `0.1.0`. This is the first version that can actively be used.

## License
LuASM is released under the MIT License – you are free to use, modify, and distribute it in your projects. See the [LICENSE](LICENSE) file for the full text.
