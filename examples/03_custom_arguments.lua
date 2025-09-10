local LuASM = require("luasm")

-- 1. Define the instruction set
local instructions = {
    LuASM.instruction("print", { "string" }, {}),
    LuASM.instruction("mov", { "reg", "reg" }, {})
}

-- 2. Create a runner (use default settings)
local asm = LuASM:new(instructions, {
    syntax = {
        string = "^\"[%w]*\"",
        reg    = "^%a[%w]*"
    }
})

-- 3. Tokenize a source string
local src = [[

mov reg0, reg1
print "Hello"
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
