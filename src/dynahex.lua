-- DynaHex by hugeblank
-- Dynamically load and unload palette segments

local this = {} -- This API
local reserved = {} -- Colors set based on how many objects refer to them. If this number is 0 at any index then that color is not referred.
local objects = {} -- Objects that contain hexchex information
local orig = {} -- Original pallete colors 
for i = 0, 15 do -- For each color
    reserved[i+1] = 0 -- Set the reserved value to 0
    orig[i+1] = colors.rgb8(term.getPaletteColor(2^i)) -- Set the original colors 
end

this.load = function(object) -- Put a table with one or more hex values (or a table with 3 floats) to reserve 
    local palette = {} -- Object that's returned
    for k, v in pairs(object) do -- For each value
        if type(v) == "table" and #v == 3 then -- If the value is a table containing 3 numbers
            for i = 1, #v do -- For each index
                if type(v[i]) ~= "number" then -- If it's not a number
                     return false, 'inv', k -- Return false with the invalid tag
                end
            end
            v = colors.rgb8(v[1], v[2], v[3]) -- Convert the table into a hex number
        end
        if type(v) == "number" then -- If the value is a number
            local set = false -- Set a reference value to false
            for i = 1, #reserved do -- For each color in reserved
                local j = 2^(i-1) -- Set an iterator for proper exponentiation
                if v == colors.rgb8(term.getPaletteColor(2^j)) or reserved[i] == 0 then -- If the value is the same color as one of the current 
                    palette[k] = j -- Set the palette output key to the one being checked, and set it to the current exponentiated iterator
                    if reserved[i] == 0 then -- If the current palette space isn't taken
                        term.setPaletteColor(j, v) -- Set it
                    end
                    reserved[i] = reserved[i]+1 -- Mark it as reserved
                    set = true -- Note that the value has been successfully set
                    break -- Exit the loop
                end
            end
            if not set then -- If the value was not set
                return false, 'max', k -- Warn the user that the pallete is full
            end
        else -- OTHERWISE
            return false, 'nan', k -- Warn the user that this value is not a number
        end
    end
    objects[#objects+1] = palette -- Add the return object to a reference table for unloading
    return palette
end

this.unload = function(object) -- Unload an object
    for i = 1, #objects do -- For each object loaded
        if i == #objects and objects[i] ~= objects[#objects] then -- If the object isn't found
            return false, 'inv' -- Warn the user using the invalid tag
        end
    end
    for k, v in pairs(object) do -- For each value in the table
        if type(v) == "number" then -- If the object is a number
            local v = math.log(v)/math.log(2) -- Set the value to the color index
            if v == math.ceil(v) then -- If the value is a whole number
                reserved[v] = reserved[v]-1 -- Remove one off of the reserved value
                if reserved[v] == 0 then -- If the reserved value is 0
                    term.setPaletteColor(orig[i]) -- Set it back to the original color
                end
            else -- OTHERWISE
                return false, 'inv', k -- Warn the user using the invalid tag
            end
        else -- OTHERWISE
            return false, 'nan', k -- Warn the user the value is not a number
        end
    end
    return true -- Return a successful operation
end

return this