--[[
     _             _    ____  __  __
    | |   _   _   / \  / ___||  \/  |
    | |  | | | | / _ \ \___ \| |\/| |
    | |__| |_| |/ ___ \ ___) | |  | |
    |_____\__,_/_/   \_\____/|_|  |_|


A library to parse and execute custom ASM.
--]]

-- Helper functions
local function trim(s)
    return s:match('^%s*(.-)%s*$')
end

-- LuASM object
local LuASM = {}

LuASM.version = "0.0.1"

--[[
    Creates a new LuASM runner with the specific instructions and settings
--]]
function LuASM:new(instructions, settings)
    -- Default settings
    setmetatable(settings, { __index = {
        separator = "[^,%s]+",
        label = "^([%a]+):%s*(.*)",
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
    obj.settings = settings

    return obj
end

local instruction = {}

local function invalidExecutor(_instruction, _interpreter)
    error("The executor is not implemented and such the instruction cannot be executed!")
    return nil
end

--[[
    Creates an instruction that is being used for parsing the input

    Example:
    ```
    LuASM:instruction("jmp", {"label"}, {})
    ```

    @param name The name of the instruction
    @param structure A list of datatypes on how the instruction should be parsed
    @param Different settings for the instruction
--]]
function LuASM.instruction(name, structure, settings)
    local obj = {}

    obj.name = name
    obj.structure = structure

    -- Default settings
    setmetatable(settings, { __index = {
        executor = invalidExecutor
    }})
    obj.settings = settings

    setmetatable(obj, instruction)
    instruction.__index = instruction

    return obj
end

-- =========================================== --
-- |                  Parser                 | --
-- =========================================== --

local Tokenizer = {}

function Tokenizer.get_next_line()
    error("This function has to be implemented!")
    return nil
end

--[[
    Creates a new tokenizer without a specific implementation.
--]]
function Tokenizer:new()
    local obj = {}

    setmetatable(obj, self)
    self.__index = self

    return obj
end

--[[
    Reads in a file and returns a tokenizer for that file.

    @param path A string of the path to the file
--]]
function LuASM.file_tokenizer(path)
    local file = io.open(path, "r")
    if file == nil then
        return nil
    end

    local tokenizer = LuASM.string_tokenizer(file:read("*a"))

    file:close()

    return tokenizer
end

--[[
    Reads in a string of the asm and returns a tokenizer for that file.

    @param input A string of the content
--]]
function LuASM.string_tokenizer(input)
    local tokenizer = Tokenizer:new()

    tokenizer.input = input
    tokenizer.cursor = 1
    tokenizer.current_line = 1

    tokenizer.get_next_line = function()
        if #tokenizer.input <= tokenizer.cursor then
            return nil
        end

        local _, endIndex = string.find(tokenizer.input, "[^\r\n]+", tokenizer.cursor)

        local line = trim(string.sub(tokenizer.input, tokenizer.cursor, endIndex))

        tokenizer.cursor = endIndex + 1
        tokenizer.current_line = tokenizer.current_line + 1

        return line
    end

    return tokenizer
end

--[[
    Parses the instruction and returns an object with the structure:
    { op = opcode, args = args, line = current line }

    If the parsing has errored out, it returns a string with the error message.
--]]
function instruction:parse(elements, luasm)
    -- `elements[1]` is the mnemonic, the rest are raw operands
    local opcode = self.name
    local expected = self.structure          -- e.g. {"imm","reg"}

    if #elements - 1 ~= #expected then
        local error = string.format(
            "Wrong number of operands for %s (expected %d, got %d)",
            opcode, #expected, #elements - 1)
        return error
    end

    local args = {}
    for i = 2, #elements do
        -- TODO: If structure element does not exist in settings
        local arg = elements[i]:match(luasm.settings.syntax[expected[i - 1]])
        if arg == nil then
            local error = string.format(
                "Could not match argument '%s' (expected %s)",
                elements[i], expected[i - 1])
            return error
        end

        args[i - 1] = arg
    end

    return {
        op = opcode,
        args = args,
        line = luasm.current_line,
        run  = self.settings.executor
    }
end

--[[
    Parses the inputted source and returns a list of instructions.

    @param tokenizer The tokenizer
--]]
function LuASM:parse(tokenizer)
    local parse_data = {
        instructions = {},
        labels = {},
        parsed_lines = 0
    }

    local token
    repeat
        token = tokenizer:get_next_line()
        parse_data.parsed_lines = parse_data.parsed_lines + 1

        if token ~= nil then

            --[[
                This is very basic label processing as labels could be
                nested and there could be priorities assigned with labels.

                But here all the labels are just a simple reference to a line.
            ]]

            -- Label processing
            if self.settings.label ~= nil then
                local label, rest = token:match(self.settings.label)
                if(label ~= nil) then
                    -- Find label
                    if parse_data.labels[label] ~= nil then
                        return parse_data, {
                            errors = { "The label '" .. label .. "' was found twice." },
                            line = parse_data.parsed_lines
                        }
                    end

                    -- Input Label
                    parse_data.labels[label] = { name = label, location = parse_data.parsed_lines }

                    token = trim(rest)

                end
            end

            local elements = {}

            string.gsub(token, self.settings.separator, function(value) elements[#elements + 1] = value end)
            if #elements == 0 then
                goto continue
            end

            local errors = {}
            for _, instr in ipairs(self.instructions) do
                if instr.name ~= elements[1] then -- Not a valid instruction
                    goto inline_continue
                end

                local result = instr:parse(elements, self)
                if type(result) == "table" then
                    parse_data.instructions[#parse_data.instructions + 1] = result

                    goto continue
                else
                    errors[#errors + 1] = result
                end

                ::inline_continue::
            end

            -- When the program gets here no instruction had the ability to parse this
            if #errors == 0 then
                -- There exists no instruction with that name,
                return parse_data, {
                    errors = { "There is no instruction with the name '" .. elements[1] .. "'" },
                    line = parse_data.parsed_lines
                }
            else -- The else only exists to please the linter
                return parse_data, {
                    errors = errors,
                    line = parse_data.parsed_lines
                }
            end

            ::continue::
        end
    until token == nil -- or true

    return parse_data, nil
end

-- =========================================== --
-- |                Interpreter              | --
-- =========================================== --

local Stack = {}

--[[
    Puts the given value onto the stack.
--]]
function Stack:push(value)
    self._content[self.size + 1] = value
    self.size = self.size + 1
end

--[[
    Removes the top value of the stack and returns it.

    If there is no value on the stack, it returns nil.
--]]
function Stack:pop()
    if self.size == 0 then
        return nil
    end

    self.size = self.size - 1
    return self._content[self.size + 1]
end

--[[
    Returns the top value on the stack, but does not remove it.

    If there is no value on the stack, it returns nil.
--]]
function Stack:peek()
    if self.size == 0 then
        return nil
    end

    return self._content[self.size]
end

--[[
    Gives the value on the stack with the index.

    Given the scenario:
    ```
    stack:push("Hola")
    stack:push("Hi")
    stack:push("Hallo")
    stack:push("Bonjour")

    print(stack:get(1)) -- Prints "Hola"
    print(stack:get(3)) -- Prints "Hallo"
    print(stack:get(2)) -- Prints "Hi"
    print(stack:get(4)) -- Prints "Bonjour"
    ```

    If the index is invalid, it will returns a nil:
    ```
    stack -- Currently has no elements
    if stack:get(1) == nil then
        print("Nothing here") -- Prints
    end

    stack:get(-10) -- Also returns nil
    ```
--]]
function Stack:get(index)
    if index < 0 or index > self.size then
        return nil
    end

    return self._content[index]
end

--[[
    Returns a stack datastructure.
    A stack is a LIFO (Last in, first out) datastructure where the last element that
    was added, will be the first that can be removed.
--]]
function LuASM.stack()
    local obj = { -- No size limit as this can be implemented if necessary
        _content = {},
        size = 0,
    }

    setmetatable(obj, Stack)
    Stack.__index = Stack

    return obj
end

local interpreter = {}

function interpreter:label_exists(label)
    return self.data.labels[label] ~= nil
end

function interpreter:in_bounds(index)
    return not (index < 0 or index > self.data.parsed_lines)
end

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

function interpreter:next_instruction()
    ::start::

    if self.data.parsed_lines < self.ip then
        return nil
    end

    local line = self.data.instructions[self.ip]
    if line == nil then
        self.ip = self.ip + 1
        goto start
    end

    line:run(self)
end

function LuASM:interpreter(data, memory)
    local obj = {}

    setmetatable(obj, interpreter)
    interpreter.__index = interpreter

    obj.luasm = self

    obj.ip = 1
    obj.data = data

    obj.memory = memory or {
        stack = LuASM.stack(),
        heap = {}
    }

    return obj
end

return LuASM
