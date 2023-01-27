-- gget by hugeblank
-- Downloads and installs repositories and their submodules much like the beloved gitget
-- Usage: gget <username> <repository> [branch=main] [path=/]
-- This program is designed for use by installer scripts. Usage in this case would be:
-- wget run https://raw.githubusercontent.com/hugeblank/qs-cc/master/src/gget.lua <username> <repository> [branch=main] [path=/]
local args = {...}
local dir = fs.getDir(shell.getRunningProgram())
local github
do
    local req = http.get("https://gist.githubusercontent.com/hugeblank/0184e7eeb638d9034d06284eaf0e8ca0/raw/nap.lua")
    if not req then
        error("Could not download nap", 2)
    end 
    github = load(req.readAll(), "nap", nil, _ENV)()("https://api.github.com/")
    req.close()
end

local function gget(user, repo, branch, path)
    path = fs.combine(path or "", "")
    branch = branch or "main"
    local function downFile(url, path) -- Download a file "asynchronously"
        local req = http.request(url)
        if not req then
            error("Could not download file "..path, 4)
        end
        return url, path
    end
    local function getJSON(call, repo) -- Download and parse a presumed JSON object
        if call then
            call = textutils.unserialiseJSON(call.readAll())
        else
            error("Could not locate repository "..repo, 4)
        end
        return call
    end
    local repository = getJSON(github.repos[user][repo].git.trees[branch]({
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
                local contents = getJSON(github.repos[user][repo].contents[repository.tree[i].path]({
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

if #args < 2 then
    print("gget user repo [branchname=main] [path=/]") -- :thinky: looks familiar
    return 0
end
local user, repo, branch, path = table.unpack(args)
branch = branch or "main"
path = path or "/"

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

    local requests = gget(user, repo, branch, path)
    download(requests)
end,
function()
    print("Downloading "..user.."/"..repo.." on branch "..branch.." to /"..fs.combine(path, "").." ")
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