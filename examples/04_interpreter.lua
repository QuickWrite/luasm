local LuASM = require("luasm")

-- 1. Define the instruction set
local instructions = {
    LuASM.instruction("print", { "string" }, {
        executor = function (instruction, _interpreter)
            print(instruction.args[1])
        end
    })
}

-- 2. Create a runner (use default settings)
local asm = LuASM:new(instructions, {
    syntax = {
        string = "^\"([%w]*)\"",
        reg    = "^%a[%w]*"
    }
})

-- 3. Tokenize a source string
local src = [[
print "Hello"
print "World"
print "Message"
]]
local tokenizer = asm:string_tokenizer(src)

-- 4. Parse
local result = asm:parse(tokenizer)

-- 5. Execution
local interpreter = LuASM:interpreter(result)

while interpreter:next_instruction() do end

