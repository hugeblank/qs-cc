--[[ Emu-Corral by hugeblank
    Emu-corral is a simple emulator workspace managment script.
    Simply add the name of the project that correlates with the ID of the computer it's on into the `emus` variable
    For example "Project 1" would be on computer ID 1.
]]
local i_use_mac = false -- For people that use mac and hate the damn JFX issue

os.pullEvent = os.pullEventRaw -- Lock down this computer, we don't really need direct access to it
local title = "Your Emus:" -- Replace this with whatever you want to have as the header of this menu
local emus = {"Project 1"} -- Your projects. 
local open, selected, ctr = nil, 1, 0 -- emulator to open, is only set when a project is selected | the project that the cursor is hovering over | the position used to center the text. Half of the value of the largest string in your projects.
local x, y = term.getSize() -- Get the size of the terminal
for i = 1, #emus do -- For each of your projects
    if (emus[i]):len() > ctr then -- If the length of this project string is larger than the current center value
        ctr  = (emus[i]):len() -- Set it to that value
    end
end

local function write(txt, id) -- Function used to center align all text.
    if id > 0 and id <= #emus then -- If the id being used is a project
        txt = id..". "..txt -- Write the computer id number next to it
    end
    term.setCursorPos((x/2)-(ctr/2), (y/2)-(#emus/2)+id) -- Set the cursor position to the right area
    term.setTextColor(colors.white) -- Set the text color properly
    term.write(txt) -- Write the text inputted
end

local function menu() -- Function used to draw the menu
    term.clear() -- Clear the screen
    if i_use_mac then
        term.setCursorPos(1, 1)
        term.write(".") -- Stop the white flash dead in its tracks
    end
    write(title, -2) -- Write the menu title
    for i = 1, #emus do -- For each project
        write(emus[i], i) -- Write it using the project ID as the id parameter
    end
    write("'c' for config", #emus+2) -- Write some more options available to you, away from your projects.
    write("'d' for data", #emus+3) 
    write("'e' to edit this", #emus+4) -- You probably used this one to get here!
    write("'l' to open lua REPL", #emus+5)
end

menu() -- Draw the menu for the first time
repeat
    term.setCursorPos((x/2)-(ctr/2)-2, (y/2)-(#emus/2)+selected) -- Set the cursor position to the currently selected project
    term.setTextColor(colors.yellow) -- Set the text color to yellow
    term.write(">") -- Write the cursor
    local k = ({os.pullEvent()}) -- Pull everything
    if k[1] == "mouse_scroll" then -- If the event is a scroll event
        if k[2] == 1 then -- If the scrolling is down
            k = keys.down -- set k to the down key
        else -- OTHERWISE
            k = keys.up -- Set k to the up key
        end
    elseif k[1] == "key" then -- If the event is a key
        k = k[2] -- Set k to the key number
    else -- OTHERWISE
        k = nil -- Throw k away
    end
    if k then
        if k == keys.enter then -- If it's the enter key
                open = selected -- Set open to selected
        elseif k == keys.down then -- If it's the down arrow
            if selected == #emus then -- If the selected value is the largest one
                selected = 0 -- Wrap back around, and account for the addition out of this block
            end
            selected = selected+1 -- Move the cursor down by one
        elseif k == keys.up then -- If it's the up arrow
            if selected == 1 then -- If the selected value is the smallest one
                selected = #emus+1 -- Wrap back around, and account for the subtraction out of this block
            end
            selected = selected-1 -- Move the cursor up by one
        elseif k >= keys.one and k <= #emus+1 and k < keys.zero then -- If the selected value is a valid number key
            selected = k-1 -- Set the selected value to the right position
            open = selected -- Automatically open it
        elseif k == keys.c then -- If it's the 'c' key
            ccemux.openConfig() -- Open the config
        elseif k == keys.d then -- If it's the 'd' key
            ccemux.openDataDir() -- Open the data directory
        elseif k == keys.l then -- If it's the 'l' key
            os.pullEvent("key_up") -- Wait for the key_up event, so that it doesn't get added in the REPL
            term.clear() -- Clear the terminal
            term.setCursorPos(1, 1) -- Set the cursor position to 1, 1
            shell.run("lua") -- Run the REPL
            menu() -- Redraw the menu after exiting
        elseif k == keys.e then -- If it's the 'e' key
            os.pullEvent("key_up") -- Wait for the key_up event, so that it doesn't get added in the editor
            shell.run("edit startup.lua") -- Open this!
            menu() -- Redraw the menu after exiting
        end
        if k ~= keys.e and k ~= keys.l then
            term.setCursorPos(({term.getCursorPos()})[1]-1, ({term.getCursorPos()})[2]) -- Set the cursor position to where the yellow arrow is
            term.write(" ") -- Remove it
        end
        if open then -- If open isn't nil
            ccemux.openEmu(open) -- Open the project desired
            open = nil -- Reset the open value
        end
    end
until true == false -- Loop forever and ever
