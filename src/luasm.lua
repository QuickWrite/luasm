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
    print("This function has to be implemented!")
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
        comma = false,
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

    return obj
end

function LuASM:file_tokenizer(name)
    
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
        labels = {},
        parsed_lines = 0,
        error = nil
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
                        parse_data.error = "The label '" .. label "' was found twice."

                        return parse_data
                    end

                    -- Input Label
                    parse_data.labels[label] = { name = label, location = line }
                    print("Found label - " .. label)

                    token = trim(rest)

                end
            end

            for index, instruction in ipairs(self.instructions) do
               -- TODO: Create parser 
            end
        end
    until token == nil -- or true

    return parse_data
end

return luasm
