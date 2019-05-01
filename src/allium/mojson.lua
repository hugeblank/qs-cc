-- Mojang NBT format parser by hugeblank
-- Link: 
-- Feel free to do what you want with this file as long as the three above lines are left untouched

local function parseNumber(str, bool)
    if bool and not str:find("b") then
        bool = false
    end
    str = str:gsub("[bslfdBSLFD]", "")
    if bool and str == "0" then
        return false
    elseif bool and str == "1" then
        return true
    end
    if tonumber(str) then
        return tonumber(str)
    else
        return false
    end
end

local function parseString(str)
    if str:sub(1, 1):find("\"") then
        str = str:sub(2, -2)
        return str
    else
        return false
    end
end

local function clipArr(str, square)
    local open, close = "{", "}"
    if square then
        open, close = "[", "]"
    end
    local oam, cam, tot = 0, 0, 1
    for char in str:gmatch(".") do
        if char == open then
            oam = oam+1
        elseif char == close then
            cam = cam+1
        end
        if oam == cam then
            return str:sub(1, tot), str:sub(tot+1, -1)
        end
        tot = tot+1
    end
    return false
end

local function splitLabel(tag)
    local tsep, vsep = tag:find(": ")
    local label, value = tag:sub(1, tsep-1), tag:sub(vsep+1, -1)
    return label, value
end

local function handleValue(list, bool)
    local coma, comb = list:find(", ")
    local value
    if coma then
        value, list = list:sub(1, coma-1), list:sub(comb+1, -1)
    else
        value, list = list, ""
    end
    local num = parseNumber(value, bool)
    local str = parseString(value)
    local out = num or str
    return out, list
end

local parseList, parseArray

local function handleTable(label, list, square, bool)
    local value
    value, list = clipArr(list, square)
    if not value then
        if square then
            error("Malformed array at index "..label)
        else
            error("Malformed list at index "..label)
        end
    end
    local arr
    if square then
        arr = parseArray(value, bool)
    else
        arr = parseList(value, bool)
    end
    local comma, ending = list:find(", ")
    if comma ~= 1 and #list > 0 then
        if square then
            error("Comma expected at end of array afer index "..label) -- Technically comma and space
        else
            error("Comma expected at end of list afer index "..label) -- Technically comma and space
        end
    end
    if #list == 0 then
        ending = 0
    end
    return arr, list:sub(ending+1, -1)
end

function parseList(list, bool)
    local out, size = {}, #list
    list = list:sub(2, -2)
    while #list > 0 do
        local label, temp = splitLabel(list)
        if not label then
            error("Malformed label at column "..size-#list)
        else
            list = temp
        end
        if list:sub(1, 1) == "{" then
            out[label], list = handleTable(label, list, false, bool)
        elseif list:sub(1, 1) == "[" then
            out[label], list = handleTable(label, list, true, bool)
            
        else
            out[label], list = handleValue(list, bool)
        end
    end
    return out
end

function parseArray(list, bool)
    local out, size = {}, #list
    list = list:sub(2, -2)
    while #list > 0 do
        if list:sub(1, 1) == "{" then
            out[#out+1], list = handleTable(#out+1, list, false, bool)
        elseif list:sub(1, 1) == "[" then
            out[#out+1], list = handleTable(#out+1, list, true, bool)
        else
            out[#out+1], list = handleValue(list, bool)
        end
    end
    return out
end

return {parseList = parseList, parseArray = parseArray}