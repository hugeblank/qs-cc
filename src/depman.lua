--[[ Depman by hugeblank
    Simple and free to use dependency managment framework to be packaged with your software.
    The end user is not only allowed to modify the code below, but is encouraged. 
    Please do not modify this comment block, but do credit yourself and any other 
    contributors in the block below.
]]
    
--[[ Depman Instance Information
    Maintained by: 
    Modified for: 
]]


--## Argument Evaluation ##--
local args = {...}
if #args < 5 then 
    print("Usage: depman <task> <list URL> <config path> <dep dir path> <application version>")
    return
end
local request, url, path, lib_path, version, save_semver = table.unpack(args)

--## Dependency Loading ##--
local semver
do -- Block to keep request value private
    local req = http.get("https://raw.github.com/hugeblank/semparse/master/semver.lua")
    if not req then error("Could not download semver, try again later") end
    if save_semver == "true" then
        local file = fs.open("semver.lua", "w")
        file.write(req.readAll())
        file.close()
    end
    if not fs.exists("semver.lua") then
        error("Could not save semver, is the disk full?")
    else
        semver = require("semver")
    end
end

--## Local Function Definitions ##--
local pullTable
do -- Block to keep cache value private
    local cache
    function pullTable() -- Downloads the package listing from online
        if cache then -- If the the listing has already been downloaded
            return cache -- Spit it to 'em
        end
        if not http.checkURL(url) then -- Check for the existence of the URL
            error("Could not download dependency data")
        end
        local contents = http.get(url) -- Get the contents
        local out = textutils.unserialise(contents.readAll()) -- Read it all
        if not out then 
            error("Could not parse dependency data")
        end
        cache = out -- Put the output into the cache for later calls
        contents.close() -- Close it all
        return out -- Return it all. nuff said.
    end
end

local function getTable() -- Provides the internal dependency listing
    if not fs.exists(path) then -- If the listing file doesn't exist, return a blank table
        return {}
    end
    local file = fs.open(path, "r") -- Read from current package listing
    local out = textutils.unserialise(file.readAll()) -- Read out the contents
    file.close() -- Close the file
    if not out then -- If it couldn't be unserialized, error
        error("Could not parse dependency data")
    else -- OTHERWISE
        return out -- return the table of currently installed deps
    end
end

local function applyData(name, meta) -- Set data within the local dependency listing
    local data = getTable() -- Get currently installed deps
    data[name] = meta -- Add the new index
    local file = fs.open(path, "w") -- Open the listing file
    if not file then -- If it can't be opened for writing
        error("Could not save dependency data")
    end
    file.write(textutils.serialise(data)) -- Write the serialized listing
    file.close() -- Close
    return true -- Mission accomplished
end

local function checkVersions(versions) -- Check versions within a range, comparison, or explicit list
    local function convert(str) -- Use the semver API to convert. Provide a detailled error if conversion fails
        if type(str) ~= "string" then
            error("Could not convert "..tostring(str))
        end
        local ver, rule = semver.parse(str:gsub("%s", ""))
        if not ver then
            error("Could not parse "..str:gsub("%s", "")..", breaks semver spec rule "..rule)
        end
        return ver
    end
    local version = convert(version) -- Duplicates the version of the main program, lowering the scope so we can parse it
    local function compare(in_str) -- compare version provided in string to input versions, using the operator provided
        local _, split = in_str:find("[><][=]*")
        local lim, op, res = convert(in_str:sub(split+1)), in_str:sub(1, split), nil -- Split operator and version string
        if op == ">" then
            res = version > lim
        elseif op == "<" then
            res =  version < lim
        elseif op == ">=" then
            res = version >= lim
        elseif op == "<=" then
            res = version <= lim
        end
        return res
    end
    for _, vstr in pairs(versions) do
        local range = vstr:find("&&") -- Matched a range definition
        local comp, c_e = vstr:find("[><][=]*") -- I do love me some pattern matching
		if range then -- If there's a range beginning definition
			local a, b = compare(vstr:sub(1, range-1)), compare(vstr:sub(range+3, -1))
			if a and b then
				return true
            end
        elseif comp then -- Otherwise if there's a comparison operator
            if compare(lim) then
                return true
            end
        elseif convert(vstr) == version then -- Otherwise this is a simple list element
            return true
        end
    end
    return false
end

local function filterDeps() -- Filter dependencies that have matching versions and need updating
    local data, cur_data = pullTable(), getTable() -- Get the online query table, and current listing table
    local out = {}
    for i = 1, #data do -- For each dependency in the table
        local name = data[i].path -- Set a special variable for the path
        local valid = checkVersions(data[i].versions)
        if valid then -- If the version supported matches the inputted one
            if cur_data[name] then -- and this dep exists internally
                -- Let's download/open the remote/local sources
                local code_response, code_file = http.get(data[i].source), fs.open(fs.combine(lib_path, name), "r")
                if code_response and code_file then -- If we opened both of them
                    local code_remote, code_local = code_response.readAll(), code_file.readAll() -- Read them
                    code_response.close() code_file.close()
                    if code_remote ~= code_local then -- If they aren't equal to each other
                        out[name] = data[i] -- Add it to the list
                    end
                elseif not code_response then -- If we didn't get an http response
                    error("Could not read remote source "..name)
                elseif not code_file then -- If we didn't open an existing file
                    error("Could not read local source "..name)
                end
            else -- OTHERWISE
                out[name] = data[i] -- Add it anyways
            end
        end
    end
    return out -- Fin.
end

--## Task Definitions ##--
local tasks = {} -- Write tasks below this point

tasks.update = function() -- The generic update task, made for you
    local depmeta = filterDeps() -- Get all dependencies to be updated
    for name, meta in pairs(depmeta) do -- For each dependency
        if not http.checkURL(meta.source) then -- Check that the source is valid
            printError("Could not locate dependency "..name or "") -- Mention it couldn't be found then move on
        end
        local contents, file = http.get(meta.source), fs.open(fs.combine(lib_path, name), "w")
        -- Download the library, and open the file to dump it in
        if not file then -- If it couldn't be opened
            error("Could not write dependency "..name or "") -- Crash and burn
        end
        file.write(contents.readAll()) -- Write the library to the file
        file.close() -- Close the file, as you should always do
        applyData(name, meta.source) -- Apply relevant data to the dependency listing file
    end
    return true -- Job done.
end

tasks.clean = function() -- Clean up dependencies that are no longer used
    local function find(tbl, str) -- Hunt down a match of a string within a table
        for i = 1, #tbl do -- For each index
            if tbl[i] == str then -- If the index matches the string
                return true -- Return triumphantly
            end
        end
        return false -- Return defeated
    end
    local depmeta, listing = pullTable(), getTable() -- Get dependency listing online, and internally
    local delet = {}
    for i = 1, #depmeta do -- For each dependency
        if not find(depmeta[i].versions, version) then -- If the version can't be found within that dep
            delet[#delet+1] = fs.combine(lib_path, depmeta[i].path) -- Send it to the ranch
        end
    end
    for i = 1, #delet do -- For each thing within the ranch
        if delet[i] then
            if fs.exists(delet[i]) then -- If it can be removed
                fs.delete(delet[i]) -- Get rid of it
                applyData(delet[i]:gsub(lib_path, ""), nil) -- Remove it from the fr*cking internal listing
            end
        end
    end
end

local action = tasks[request] -- Set action to the index within the task list corresponding to a task
if action then -- If it's actually a task
    action() -- Fulfill it
else -- OTHERWISE
    print("Invalid task "..request) -- Let's tell them that they goofed
    print("List of valid tasks: ") -- And then list all the tasks that are availible
    for name in pairs(tasks) do
        print("- "..name)
    end
end