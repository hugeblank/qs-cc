-- SemVer parser by hugeblank https://github.com/hugeblank
-- Parses strings that meet SemVer 2.0.0 specs as documented here: https://semver.org/spec/v2.0.0.html
-- Feel free to use/redistribute/modify this file. Should you do so keep the above 3 lines as they are.

-- Any strings that don't meet SemVer specs the parse will return false, and the rule number violated
-- If successful, parser will return a table that can be compared with other SemVer tables.

local this, meta = {}, {}

meta.__eq = function(in1, in2)
    local recurse_tag = function(ver1, ver2)
        if #ver1 ~= #ver2 then
            return false, 1
        else
            for i = 1, #ver1 do
                if ver1[i] ~= ver2[i] then
                    return false, 2
                end
            end
        end
        if ver1.tag and ver2.tag then
            return recurse_tag(ver1.tag, ver2.tag)
        elseif (ver1.tag and not ver2.tag) or (ver2.tag and not ver1.tag) then
            return false, 3
        else
            return true, 4
        end
    end
    return recurse_tag(in1, in2)
end
meta.__lt = function(in1, in2)
    local recurse_tag = function(ver1, ver2)
        if #ver1 < #ver2 then
            return true
        end
        for i = 1, #ver1 do
            if ver1[i] ~= ver2[i] then
                if ver1[i] < ver2[i] then
                    return true
                else
                    return false
                end
            end
        end
        if ver1.tag and ver2.tag then
            return recurse_tag(ver1, ver2)
        elseif ver1.tag and not ver2.tag then
            return true
        elseif (ver2.tag and not ver1.tag) then
            return false
        else
            return false
        end
    end
    return recurse_tag(in1, in2)
end
meta.__le = function(in1, in2)
    if meta.__eq(in1, in2) then
        return true
    else
        return meta.__lt(in1, in2)
    end
end
meta.__tostring = function(in1)
    local out = table.concat(in1, ".")
    if in1.tag then
        out = out.."-"..table.concat(in1.tag, ".")
    end
    if in1.meta then
        out = out.."+"..table.concat(in1.meta, ".")
    end
    return out
end

this.parse = function(str)
    local out = {}
    local param = ""
    local mode = "release"
    for char in str:gmatch(".") do
        if mode == "release" then
            if char:find("%d") then
                param = param..char
            elseif char == "." then
                if #param == 0 or not tostring(tonumber(param)) == param then
                    return false, 2
                end
                out[#out+1] = tonumber(param)
                param = ""
            elseif char == "-" and not out.meta then
                if #param > 0 then
                    out[#out+1] = tonumber(param)
                    param = ""
                end
                if not out.tag then
                    mode = "patch"
                    out.tag = {}
                end
            elseif char == "+" then
                if #param > 0 then
                    out[#out+1] = tonumber(param)
                    param = ""
                end
                if not out.meta then
                    mode = "meta"
                    out.meta = {}
                end
            else
                return false, 2
            end
        elseif mode == "patch" then
            if char:find("%w") then
                param = param..char
            elseif char == "." then
                if #param == 0 then
                    return false, 9
                end
                out.tag[#out.tag+1] = param
                param = ""
            elseif char == "+" then
                if #param > 0 then
                    out.tag[#out.tag+1] = param
                    param = ""
                end
                if not out.meta then
                    mode = "meta"
                    out.meta = {}
                end
            else
                return false, 9
            end
        elseif mode == "meta" then
            if char == "." then
                if #param == 0 then
                    return false, 10
                end
                out.meta[#out.meta+1] = param
                param = ""
            end
            if char:find("%w") then
                param = param..char
            end
        else
            error("Invalid Semver syntax (Column "..str:find(char)..")", 2)
        end 
    end
    if #param > 0 then
        if mode == "release" then
            out[#out+1] = tonumber(param)
        elseif mode == "patch" then
            out.tag[#out.tag+1] = param
        elseif mode == "meta" then
            out.meta[#out.meta+1] = param
        end
    end
    if #out < 3 then
        return false, 2
    elseif out.tag and #out.tag == 0 then
        return false, 9
    elseif out.meta and #out.meta == 0 then
        return false, 10
    end
    return setmetatable(out, meta)
end

return this