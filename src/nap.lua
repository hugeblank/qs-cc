--[[ nap by hugeblank
    Nap is designed for use as a REST API parser, but works remarkably great with HTTP in general.
    It uses metatables to detect indexing, and when called GETs/POSTs/ETC. the given data depending on the table passed in.
    Ex:
        nap = require("nap")
        github = nap("https://api.github.com")
        handle = github.repos['username']['repo'].git.trees.master({
            method = "GET",
            query = {["recursive"] = 1}
        })
    This demo recursively gets the contents of the branch master from 'username'/'repo'. 
    Documentation on this operation can be found on github's API wiki.
]]


--[[ Main function:
    - str: (string) base URL [Ex: "https://api.github.com", or "https://discordapp.com/api"]
]]

--[[ Request function
    - data: (table) table of information to send Ex:
        1. { -- A generic post request
            method = "POST",
            body = "this=is&a=test",
            headers = {
                ["User-Agent"] = "Something"
            },

        }
        2. { -- A generic get request
            method = "GET",
            query = { -- query string for a youtube video
                v = "4A03ZAwhHt0",
                t = "0s"
            }
        }
]]

return function(str) -- function that takes a base URL to start from
    if type(str) ~= "string" then -- Type checking
        error("Invalid argument #1 (string expected, got "..type(str)..")", 2)
    elseif not http.checkURL(str) then -- Existence checking
        error("Could not verify URL "..str, 2)
    end
    if str:sub(-1,-1) ~= "/" then -- Appending a slash if there isn't already one
        str = str.."/"
    end
    local mt = {prefix = str, url = ""} -- Defining the metatable
    mt.__index = function(t, key) -- When the table get indexed, append the key to the URL string
        if mt.url == "" then
            mt.url = mt.prefix
        end
        mt.url = mt.url..key.."/"
        return t
    end
    mt.__call = function(_, data) -- When the key gets called, performs request
        if type(data) ~= "table" then
            error("Invalid argument #1 (table expected, got "..type(data)..")", 2)
        elseif type(data.method) ~= "string" then
            error("Invalid argument #1 (key 'method' as a string expected, got "..type(data.method)..")", 2)
        end
        data.url = mt.url
        mt.url = "" -- clear the URL for next use
        if data.method:lower() == "get" and not data.async then
            if type(data.query) == "table" then -- Convert the get query to a string if it's a table
                temp = ""
                for k, v in pairs(data.query) do
                    if type(v) == "string" or type(v) == "number" then
                        temp = temp..k.."="..v.."&"
                    end
                end
                data.query = temp:sub(1, -2)
            end
            if data.query then 
                data.url = data.url:sub(1, -2).."?"..data.query -- Append data like it's a query string
                data.query = nil
            end
            return http.get(data)
        elseif not data.async then
            data.url = data.url:sub(1, -2) -- remove excess slash
            return http.post(data)
        else
            data.url = data.url:sub(1, -2) -- remove excess slash
            data.async = nil
            return http.request(data)
        end
    end
    return setmetatable({}, mt) -- Set the metatable on a blank table
end 