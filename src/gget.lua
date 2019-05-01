-- gget by hugeblank
-- Downloads and installs repositories and their submodules much like the beloved gitget
-- Usage: gget username repository branch[default=master] path[default=/]
local args = {...}
local dir = fs.getDir(shell.getRunningProgram())
if not fs.exists(dir.."/nap.lua") then
    local req = http.get("https://gist.githubusercontent.com/hugeblank/0184e7eeb638d9034d06284eaf0e8ca0/raw/nap.lua")
    if not req then
        error("Could not download necessary APIs", 2)
    end 
    local file = fs.open(dir.."/nap.lua", "w")
    file.write(req.readAll())
    file.close()
end
if not fs.exists(dir.."/json.lua") then -- json parse by RXI, check it out!
    local req = http.get("https://raw.githubusercontent.com/rxi/json.lua/master/json.lua")
    if not req then
        error("Could not download necessary APIs", 2)
    end 
    local file = fs.open(dir.."/json.lua", "w")
    file.write(req.readAll())
    file.close()
end
local json, github = dofile(dir.."/json.lua"), dofile(dir.."/nap.lua")("https://api.github.com/")
local user, repo, branch, path = table.unpack(args)
if not branch then branch = "master" end
if not path then path = "/" end
if #args < 2 then
    print("gget user repo [branchname=master] [path=/]") -- :thinky: looks familiar
    return 0
end
local function gget(user, repo, branch, path)
    path = fs.combine(path or "", "")
    branch = branch or "master"
    local function downFile(url, path) -- Download a file asynchronously
        local req = http.request(url)
        if not req then
            error("Could not download file "..path, 4)
        end
        return url, path
    end
    local function downJSON(call, repo) -- Download and parse a presumed JSON object
        if call then
            call = json.decode(call.readAll())
        else
            error("Could not locate repository "..repo, 4)
        end
        return call
    end
    local repository = downJSON(github.repos[user][repo].git.trees[branch]({
        method = "GET",
        query = {
            recursive = 1
        }
    }), repo)

    local requests = {}
    for i = 1, #repository.tree do
        if repository.tree[i].type == "blob" then
            requests[#requests+1] = {downFile("https://raw.github.com/"..user.."/"..repo.."/"..branch.."/"..repository.tree[i].path, path.."/"..repository.tree[i].path)}
        elseif repository.tree[i].type == "tree" then
            fs.makeDir(path.."/"..repository.tree[i].path)
        elseif repository.tree[i].type == "commit" then
            requests[#requests+1] = {function()
                local contents = downJSON(github.repos[user][repo].contents[repository.tree[i].path]({
                    method = "GET"
                }), repo)
                local subuser, subrepo, subbranch, subpath
                do
                    local location = contents.submodule_git_url:gsub("https://github.com/", "")
                    subuser = location:sub(1, location:find("/")-1)
                    subrepo = location:sub(location:find("/")+1, -1):gsub(".git", "")
                    subbranch = contents.sha
                    subpath = path.."/"..repository.tree[i].path
                end
                return gget(subuser, subrepo, subbranch, subpath)
            end}
        end
    end
    return requests
end

parallel.waitForAny(function() 
    local function download(reqs) 
        local functions = 0
        for i = 1, #reqs do
            if type(reqs[i][1]) == "function" then
                functions = functions+1
            end
        end
        while #reqs > functions do
            e, url, handle = os.pullEvent()
            if e == "http_success" then
                for i = 1, #reqs do
                    if reqs[i][1] == url then
                        local file = fs.open(reqs[i][2], "w")
                        file.write(handle.readAll())
                        file.close()
                        table.remove(reqs, i)
                        break
                    end
                end
            elseif e == "http_failure" then
                -- couldn't do it chief
            end
        end
        for i = 1, #reqs do
            if type(reqs[i][1]) == "function" then
                download(reqs[i][1]())
            end
        end
    end
    local requests = gget(table.unpack(args))
    download(requests)
end,
function()
    write("Downloading "..repo.." to /"..fs.combine(path, "").." ")
    local function write(str)
        local x, y = term.getCursorPos()
        term.write(str)
        term.setCursorPos(x, y)
    end
    while true do 
        write("/") sleep()
        write("-") sleep()
        write("\\") sleep()
        write("|") sleep()
    end
end)
print("\nDone")