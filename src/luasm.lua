--[[
     _             _    ____  __  __
    | |   _   _   / \  / ___||  \/  |
    | |  | | | | / _ \ \___ \| |\/| |
    | |__| |_| |/ ___ \ ___) | |  | |
    |_____\__,_/_/   \_\____/|_|  |_|


A library to parse and execute custom ASM.
--]]

--------------------------------------------------------------------
--- Helper functions
--------------------------------------------------------------------

--- Trim leading and trailing whitespace from a string.
--- @param s string The string to trim.
--- @return string The trimmed string.
local function trim(s)
    return s:match('^%s*(.-)%s*$')
end

--------------------------------------------------------------------
--- LuASM object (public API entry point)
--------------------------------------------------------------------
local LuASM = {}

--- Current version of the library.
LuASM.version = "0.0.1"

--- Creates a new LuASM runner with the specific instructions and settings
--- @param instructions table   List of instruction objects (created with `LuASM.instruction`).
--- @param settings     table   Optional table that overrides the default parsing settings.
--- @return table               A new LuASM instance.
function LuASM:new(instructions, settings)
    -- Default settings
    setmetatable(settings, { __index = {
        separator = "[^,%s]+",
        label = "^([%a]+):%s*(.*)",
        comment = "[;#].*$",
        syntax = {
            imm = "^[%d]+",
            reg = "^%a[%w]*",
            label = "^[%a]+"
        }
    }})

    local obj = {}

    setmetatable(obj, self)
    self.__index = self

    obj.instructions = instructions
    obj.settings     = settings

    return obj
end

--------------------------------------------------------------------
--- Instructions
--------------------------------------------------------------------
local instruction = {}

--- Default executor that raises an error when an instruction has no implementation.
--- @param _instruction any   Ignored (placeholder for the instruction object).
--- @param _interpreter any   Ignored (placeholder for the interpreter instance).
--- @return nil
local function invalidExecutor(_instruction, _interpreter)
    error("The executor is not implemented and such the instruction cannot be executed!")
    return nil
end

--- Creates an instruction that is being used for parsing the input
---
--- Example:
---  ```
---  LuASM:instruction("jmp", {"label"}, {})
---  ```
--- @param name string   Mnemonic of the instruction (e.g. `"jmp"`).
--- @param structure table Ordered list of operand types (e.g. `{"label"}`).
--- @param settings table  Optional per‑instruction settings (e.g. a custom executor).
--- @return table        An instruction object.
function LuASM.instruction(name, structure, settings)
    local obj = {}

    obj.name      = name
    obj.structure = structure

    -- Default settings
    setmetatable(settings, { __index = {
        executor = invalidExecutor   -- every instruction must provide an executor to run
    }})
    obj.settings = settings

    setmetatable(obj, instruction)
    instruction.__index = instruction

    return obj
end

--------------------------------------------------------------------
--- Parser
--------------------------------------------------------------------
local Tokenizer = {}

--- Abstract method that must be overridden by a concrete tokenizer.
function Tokenizer.get_next_line()
    error("This function has to be implemented!")
    return false
end

--- @return boolean
function Tokenizer:has_next_line()
    return false
end

--- @return string|nil
function Tokenizer:get_label()
    return nil
end

--- Creates a new tokenizer without a specific implementation.
--- @return table A tokenizer instance (needs a concrete `get_next_line` implementation).
function Tokenizer:new(luasm)
    local obj = {}

    obj.luasm = luasm

    setmetatable(obj, self)
    self.__index = self

    return obj
end

--- Reads in a file and returns a tokenizer for that file.
--- @param path string Path to the file to read.
--- @return table|nil Tokenizer instance or `nil` if the file cannot be opened.
function LuASM:file_tokenizer(path)
    local file = io.open(path, "r")
    if file == nil then
        return nil
    end

    local tokenizer = self:string_tokenizer(file:read("*a"))

    file:close()

    return tokenizer
end

--- Reads in a string of the asm and returns a tokenizer for that file.
--- @param input string The complete ASM source as a string.
--- @return table      Tokenizer instance.
function LuASM:string_tokenizer(input)
    local tokenizer = Tokenizer:new()

    tokenizer.input        = input
    tokenizer.cursor       = 1      -- byte index inside `input`
    tokenizer.current_line = 1      -- line counter (1‑based)

    tokenizer.line         = nil

    -- Concrete implementation of `get_next_line` for a string source.
    tokenizer.get_next_line = function()
        if #tokenizer.input <= tokenizer.cursor then
            return nil               -- EOF
        end

        local _, endIndex = string.find(tokenizer.input, "[^\r\n]+", tokenizer.cursor)

        local line = trim(string.sub(tokenizer.input, tokenizer.cursor, endIndex))

        -- Remove comment from the line
        if self.settings.comment ~= nil then
            line = line:gsub(self.settings.comment, "")
        end

        tokenizer.cursor       = endIndex + 1
        tokenizer.current_line = tokenizer.current_line + 1

        return line
    end

    tokenizer.has_line = function()
        tokenizer.line = tokenizer.get_next_line()

        return tokenizer.line ~= nil
    end

    tokenizer.get_label = function()
        if self.settings.label == nil then
            return nil
        end

        local label, rest = tokenizer.line:match(self.settings.label)

        if label ~= nil then
            tokenizer.line   = rest
            tokenizer.cursor = tokenizer.cursor + #label
        end

        return label
    end

    return tokenizer
end

--- Parses the instruction and returns an object with the structure:
---
--- `{ op = opcode, args = args, line = current line }`
---
--- If the parsing has errored out, it returns a string with the error message.
--- @param elements table  Token list where `elements[1]` is the mnemonic.
--- @param luasm    table  The LuASM instance (provides settings, etc.).
--- @return table|string   On success a table `{op, args, line, run}`; on failure a string error message.
function instruction:parse(elements, luasm)
    -- `elements[1]` is the mnemonic, the rest are raw operands
    local opcode   = self.name
    local expected = self.structure          -- e.g. {"imm","reg"}

    if #elements - 1 ~= #expected then
        local err = string.format(
            "Wrong number of operands for %s (expected %d, got %d)",
            opcode, #expected, #elements - 1)
        return err
    end

    local args = {}
    for i = 2, #elements do
        local pattern = luasm.settings.syntax[expected[i - 1]]
        if pattern == nil then
            error("The pattern with the name of '" .. expected[i - 1] .. "' does not exist.", 2)
            return "Pattern not found"
        end

        local arg = elements[i]:match(pattern)
        if arg == nil then
            local err = string.format(
                "Could not match argument '%s' (expected %s)",
                elements[i], expected[i - 1])
            return err
        end
        args[i - 1] = arg
    end

    return {
        op   = opcode,
        args = args,
        line = luasm.current_line,
        run  = self.settings.executor   -- executor function (may be the default error)
    }
end

--- Parses the inputted source and returns a list of instructions.
--- @param tokenizer table Tokenizer instance that yields trimmed source lines.
--- @return table parsed_data   Table with fields `instructions`, `labels`, `parsed_lines`.
--- @return table|nil error     `nil` on success, otherwise a table `{errors = {...}, line = N}`.
function LuASM:parse(tokenizer)
    local parse_data = {
        instructions = {},
        labels       = {},
        parsed_lines = 0
    }

    while tokenizer:has_line() do
        parse_data.parsed_lines = parse_data.parsed_lines + 1

        local label = tokenizer:get_label()

        --[[
            This is very basic label processing as labels could be
            nested and there could be priorities assigned with labels.

            But here all the labels are just a simple reference to a line.
        --]]
        if label ~= nil then
            if parse_data.labels[label] ~= nil then
                return parse_data, {
                    errors = { "The label '" .. label .. "' was found twice." },
                    line   = parse_data.parsed_lines
                }
            end

            parse_data.labels[label] = {
                name     = label,
                location = #parse_data.instructions + 1
            }
        end

        if tokenizer:end_of_line() then
            goto continue
        end

        local mnemonic = tokenizer:get_mnemonic()

        local errors = {}
        for _, instr in ipairs(self.instructions) do
            if instr.name ~= mnemonic then
                goto inner
            end

            local result = instr:parse(tokenizer, self)
            if type(result) == "table" then
                parse_data.instructions[#parse_data.instructions + 1] = result
                goto continue           -- go to the outer `continue` label
            else
                errors[#errors + 1] = result
            end

            ::inner::
        end

        -------------------------------------------------
        -- NO INSTRUCTION MATCHED
        -------------------------------------------------
        if #errors == 0 then
            -- No instruction with that mnemonic exists.
            return parse_data, {
                errors = { "There is no instruction with the name '" .. mnemonic .. "'" },
                line   = parse_data.parsed_lines
            }
        else
            -- At least one instruction matched the name but rejected the operands.
            return parse_data, {
                errors = errors,
                line   = parse_data.parsed_lines
            }
        end

        ::continue::
    end

    return parse_data, nil
end

--------------------------------------------------------------------
--- Interpreter
--------------------------------------------------------------------

--- Simple LIFO stack implementation used by the interpreter.
local Stack = {}

--- Puts the given value onto the stack.
--- @param value any The value to store.
function Stack:push(value)
    self._content[self.size + 1] = value
    self.size = self.size + 1
end

--- Removes the top value of the stack and returns it.
--- If there is no value on the stack, it returns `nil`.
--- @return any|nil The popped value, or `nil` if the stack is empty.
function Stack:pop()
    if self.size == 0 then
        return nil
    end

    self.size = self.size - 1
    return self._content[self.size + 1]
end

--- Returns the top value on the stack, but does not remove it.
--- If there is no value on the stack, it returns `nil`.
--- @return any|nil The top value, or `nil` if the stack is empty.
function Stack:peek()
    if self.size == 0 then
        return nil
    end

    return self._content[self.size]
end

--- Gives the value on the stack with the index.
---
--- Given the scenario:
--- ```
--- stack:push("Hola")
--- stack:push("Hi")
--- stack:push("Hallo")
--- stack:push("Bonjour")
---
--- print(stack:get(1)) -- Prints "Hola"
--- print(stack:get(3)) -- Prints "Hallo"
--- print(stack:get(2)) -- Prints "Hi"
--- print(stack:get(4)) -- Prints "Bonjour"
--- ```
---
--- If the index is invalid, it will returns a nil:
--- ```
--- stack -- Currently has no elements
--- if stack:get(1) == nil then
---     print("Nothing here") -- Prints
--- end
---
--- stack:get(-10) -- Also returns nil
--- ```
---
--- The index is **1‑based** (bottom of the stack = 1).
--- @param index number The index to fetch.
--- @return any|nil The element at `index`, or `nil` if out of bounds.
function Stack:get(index)
    if index < 0 or index > self.size then
        return nil
    end

    return self._content[index]
end

--- Returns a stack datastructure.
--- A stack is a LIFO (Last‑In‑First‑Out) structure where the last element added
--- is the first one that can be removed.
--- @return table A fresh stack (initially empty).
function LuASM.stack()
    local obj = {
        _content = {},
        size     = 0,
    }

    setmetatable(obj, Stack)
    Stack.__index = Stack

    return obj
end

--------------------------------------------------------------------
--- Interpreter
--------------------------------------------------------------------
local interpreter = {}

--- Checks whether a label exists in the parsed data.
--- @param label string The label name to test.
--- @return boolean True if the label is defined.
function interpreter:label_exists(label)
    return self.data.labels[label] ~= nil
end

--- Verifies that a program counter is within the bounds of the parsed program.
--- @param index number The line number (1‑based) to test.
--- @return boolean True if the index is valid.
function interpreter:in_bounds(index)
    return not (index < 0 or index > self.data.parsed_lines)
end

--- Jumps to a specific line number or label.
--- @param index number|string The target line number or label name.
--- @return string|nil Error message on failure, `nil` on success.
function interpreter:jump(index)
    if type(index) == "string" then -- Jump to label
        index = self.data.labels[index]

        if index == nil then
            return "This label does not exist"
        end
    end

    if type(index) ~= "number" then
        error("The index must be a number or a string", 2)
    end

    if not self:in_bounds(index) then
        error("This position does not exist.")
    end

    self.ic = index
    return nil
end

--- Executes the next instruction in the program.
--- The function advances `self.ip` until it finds a non‑nil instruction,
--- then calls its `run` method (the executor supplied when the instruction
--- was defined).
--- @return boolean True if the instruction executed correctly
---                 False if there is no instruction or the instruction errored out
function interpreter:next_instruction()
    ::start::

    if self.data.parsed_lines < self.ip then
        return false
    end

    local line = self.data.instructions[self.ip]
    self.ip = self.ip + 1
    if line == nil then
        goto start
    end

    local result = line:run(self)

    return result == nil or result
end

--- Creates a new interpreter instance.
--- @param data   table Parsed program data (result of `LuASM:parse`).
--- @param memory table Optional memory layout (stack + heap). If omitted a default is created.
--- @return table       Interpreter object ready to run.
function LuASM:interpreter(data, memory)
    local obj = {}

    setmetatable(obj, interpreter)
    interpreter.__index = interpreter

    obj.luasm = self
    obj.ip    = 1                -- instruction pointer (1‑based)
    obj.data  = data

    obj.memory = memory or {
        stack = LuASM.stack(),
        heap  = {}
    }

    return obj
end

return LuASM
