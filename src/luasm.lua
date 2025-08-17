--[[
     _             _    ____  __  __ 
    | |   _   _   / \  / ___||  \/  |
    | |  | | | | / _ \ \___ \| |\/| |
    | |__| |_| |/ ___ \ ___) | |  | |
    |_____\__,_/_/   \_\____/|_|  |_|
                                    

A library to parse and execute custom ASM.
--]]

local function trim(s)
    return s:match('^%s*(.-)%s*$')
end

local Tokenizer = {}

function Tokenizer.get_next_line()
    error("This function has to be implemented!")
    return nil
end

--[[
    Creates a new tokenizer without a specific implementation.
]]
function Tokenizer:new()
    local obj = {}

    setmetatable(obj, self)
    self.__index = self

    return obj
end

local LuASM = {}

LuASM.version = "0.0.1"

--[[
    Creates a new LuASM runner with the specific instructions and settings
]]
function LuASM:new(instructions, settings)
    -- Default settings
    setmetatable(settings,{__index={
        separator = "[^,%s]+",
        reg_prefix = "",
        imm_prefix = "",
        label = true,
        label_syntax = "^([%a]+):%s*(.*)"
    }})

    local obj = {}

    setmetatable(obj, self)
    self.__index = self

    obj.instructions = instructions
    obj.settings = settings

    return obj
end

local instruction = {}
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

    -- TODO: Better argument parsing
    local args = {}
    for i = 2, #elements do
        args[i-1] = elements[i]
    end

    return { op = opcode, args = args, line = luasm.current_line }
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
]]
function LuASM.instruction(name, structure, settings)
    local obj = {}

    obj.name = name
    obj.structure = structure

    -- Default settings
    setmetatable(settings, {__index={
        -- Currently no settings
    }})
    obj.settings = settings

    setmetatable(obj, instruction)
    instruction.__index = instruction

    return obj
end

function LuASM.file_tokenizer(name)
    local file = io.open(name, "r")
    if file == nil then
        return nil
    end

    local tokenizer = LuASM.string_tokenizer(file:read("*a"))

    file:close()

    return tokenizer
end

function LuASM.string_tokenizer(input)
    local tokenizer = Tokenizer:new()

    tokenizer.input = input
    tokenizer.cursor = 1
    tokenizer.current_line = 1

    tokenizer.get_next_line = function()
        if #tokenizer.input <= tokenizer.cursor then
            return nil
        end

        local startIndex, endIndex = string.find(tokenizer.input, "[^\r\n]+", tokenizer.cursor)

        local line = trim(string.sub(tokenizer.input, tokenizer.cursor, endIndex))

        tokenizer.cursor = endIndex + 1
        tokenizer.current_line = tokenizer.current_line + 1

        return line
    end

    return tokenizer
end

--[[
    Parses the inputted source and returns a list of instructions.

    @param tokenizer The tokenizer
]]
function LuASM:parse(tokenizer)
    local line = 0

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
            if self.settings.label then
                local label, rest = token:match(self.settings.label_syntax)
                if(label ~= nil) then
                    -- Find label
                    if parse_data.labels[label] ~= nil then
                        return parse_data, { 
                            errors = { "The label '" .. label "' was found twice." },
                            line = parse_data.parsed_lines
                        }
                    end

                    -- Input Label
                    parse_data.labels[label] = { name = label, location = line }

                    token = trim(rest)

                end
            end

            local elements = {}

            string.gsub(token, self.settings.separator, function(value) elements[#elements + 1] = value end)
            if #elements == 0 then
                goto continue
            end

            local errors = {}
            for _, instruction in ipairs(self.instructions) do
                if instruction.name ~= elements[1] then -- Not a valid instruction
                    goto inline_continue
                end

                local result = instruction:parse(elements, self)
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
end

return LuASM
