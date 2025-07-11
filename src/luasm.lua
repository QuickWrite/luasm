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
        print("End line: " .. endIndex)

        local line = trim(string.sub(tokenizer.input, tokenizer.cursor, endIndex))

        tokenizer.cursor = endIndex + 1
        tokenizer.current_line = tokenizer.current_line + 1

        return line
    end

    return tokenizer
end

-- TODO: Everything

return luasm
