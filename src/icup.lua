-- Interface for CUstom Peripherals - by hugeblank
-- Do what you want with this, I don't really mind. It's only a 150 line driver.
-- Usage: 
    -- All base peripheral functions work the same.
    --[[ peripheral.attach(string, string, table) - Attaches a peripheral and triggers the 'peripheral' event
        1. Custom side value to attach to
        2. Custom or existing type IE: "modem"
        3. Table of functions for this peripheral
        - True if attachment succeeded, false if it failed (side already taken)
    ]]
    --[[ peripheral.detach(string) - Detaches a peripheral and triggers the 'peripheral_detach' event
        1. Custom side value to detach from
        - True if detach was successful, false if failed (nothing present on side)
    ]]

    local peripheral, native, customs, expect, ocall = {}, _G.peripheral, {}, _G["~expect"], pcall

    local pcall = function(func, ...)
        local suc = {ocall(func, ...)}
        if table.remove(suc, 1) then
            return table.unpack(suc)
        else
            error(suc[1], 3)
        end
    end 
    
    local copy = function(tbl, met, mch)
        local out = {}
        if not met or mch then
            met, mch = {}, {}
        end
        met[#met+1], mch[#mch+1] = tbl, out
        for k, v in pairs(tbl) do
            local handled = false
            for i = 1, #met do
                if met[i] == v then
                    out[k] = mch[i]
                    handled = true
                end
            end
            if type(v) == "table" and not handled then
                copy(v, met, mch)
            else
                out[k] = v
            end
        end
        return out
    end
    
    peripheral.isPresent = function(side)
        expect(1, side, "string")
        if customs[side] then
            return true
        else
            return pcall(native.isPresent, side)
        end
    end
    
    peripheral.getType = function(side)
        expect(1, side, "string")
        if customs[side] then
            return customs[side].type
        else
            return pcall(native.getType, side)
        end
    end
    
    peripheral.getMethods = function(side)
        expect(1, side, "string")
        if customs[side] then
            local out = {}
            for k, v in pairs(customs[side].methods) do
                out[#out+1] = k
            end
            return out
        else
            return pcall(native.getMethods, side)
        end
    end
    
    peripheral.call = function(side, method, ...)
        expect(1, side, "string")
        expect(2, method, "string")
        if customs[side] then
            return pcall(customs[side].methods[method], ...)
        else
            return pcall(native.call, side, method, ...)
        end
    end
    
    peripheral.wrap = function(side)
        expect(1, side, "string")
        if customs[side] then
            return copy(customs[side].methods)
        else
            return pcall(native.wrap, side)
        end
    end
    
    peripheral.find = function(type, func)
        expect(1, type, "string")
        local out = {}
        for side, data in pairs(customs) do
            if data.type == type then
                if func then
                    if func(side, copy(data.methods)) then
                        out[#out+1] = data.methods
                    end
                else
                    out[#out+1] = data.methods
                end
            end
        end
        local base = {pcall(native.find, type, func)}
        return table.unpack(out), table.unpack(base)
    end
    
    peripheral.getNames = function()
        local out = {}
        for side in pairs(customs) do
            out[#out+1] = side
        end
        local base = native.getNames()
        for i = 1, #base do
            out[#out+1] = base[i]
        end
        return out
    end
    
    peripheral.attach = function(side, type, methods)
        expect(1, side, "string")
        expect(2, type, "string")
        expect(3, methods, "table")
        for _, name in pairs(native.getNames()) do
            if name == side then
                return false
            end
        end
        if customs[side] then
            return false
        end
        customs[side] = {type = type, methods = methods}
        os.queueEvent("peripheral", side)
        return true
    end
    
    peripheral.detach = function(side)
        expect(1, side, "string")
        for k, v in pairs(customs) do
            if k == side then
                customs[k] = nil
                os.queueEvent("peripheral_detach", side)
                return true
            end
        end
        return false
    end
    
    _G.peripheral = peripheral