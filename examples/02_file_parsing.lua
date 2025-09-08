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
local tokenizer = LuASM:file_tokenizer("./data/02_data.lasm")

-- 4. Parse
local result = asm:parse(tokenizer)

print("Lines parsed:", result.parsed_lines)
for name, info in pairs(result.labels) do
    print("Label: " .. name .. " -> line: " .. info.location)
end

for i, instr in ipairs(result.instructions) do
    print(i, instr.op)   -- currently just the instruction name
end
