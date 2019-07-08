-- SkyModem peripheral - by hugeblank

-- Syssm checks
if not syssm then
    printError("Missing dependency: Syssm")
    printError("Skymodem requires Syssm for runnning skynet background listener")
    print("Would you like to install Syssm? [y/n]")
    local _, key = os.pullEvent("char")
    if key:lower() == "y" then
        local content = http.get("https://raw.githubusercontent.com/hugeblank/syssm/master/installer.lua")
        if not content then
            printError("Could not download installer, try again later")
        else
            local suc, err = pcall(load(content:readAll()))
            if suc then 
                return
            else
                printError(err)
                return
            end
        end
    else
        print("Not installing, returning to shell")
    end
    return
end

-- ICUP setup
if not peripheral.attach then
    if not fs.exists("icup.lua") then
        local file, content = fs.open("icup.lua", "w"), http.get("https://raw.githubusercontent.com/hugeblank/qs-cc/master/src/icup.lua")
        if not content then
            printError("Could not download ICUP")
            printError("Skymodem requires ICUP for modem injection")
            return
        end
        file.write(content.readAll())
        file.close() content.close()
    end
    shell.run("icup.lua")
end

--SkyNet setup
if not fs.exists("skynet.lua") then
    local file, content = fs.open("skynet.lua", "w"), http.get("https://raw.githubusercontent.com/osmarks/skynet/master/client.lua")
    if not content then
        printError("Could not download SkyNet")
        printError("Skymodem requires SkyNet for modem functionality")
        return
    end
    file.write(content.readAll())
    file.close() content.close()
end
local skynet, expect = require("skynet"), _G["~expect"]

local function createModem()
    local open, modem, channels = false, {}, {}

    modem.isWireless = function()
        return true
    end

    modem.open = function(channel)
        skynet.connect()
        expect(1, channel, "number")
        if channel < 0 or channel > 65535 then
            error("Expected number in range 0-65535", 2)
        end
        channels[channel] = true
        skynet.open(channel)
    end

    modem.close = function(channel)
        expect(1, channel, "number")
        if channel < 0 or channel > 65535 then
            error("Expected number in range 0-65535", 2)
        end
        channels[channel] = nil
        skynet.close(channel)
        local total = 0
        for _ in pairs(channels) do
            total = total+1
        end
        if total == 0 then
            skynet.disconnect()
        end
    end

    modem.closeAll = function()
        for k in pairs(channels) do
            channels[k] = nil
            skynet.close(k)
        end
        skynet.disconnect()
    end

    modem.isOpen = function(channel)
        expect(1, channel, "number")
        return channels[channel] or false
    end

    modem.transmit = function(channel, reply, message)
        expect(1, channel, "number")
        expect(2, reply, "number")
        skynet.send(channel, message, {reply = reply})
    end

    return modem

end

syssm.inject("skymodem", function()
    parallel.waitForAny(skynet.listen, 
    function() 
        while true do
            local e = {os.pullEvent("skynet_message")}
            table.remove(e, 1)
            if type(e[3].reply) == "number" then
                os.queueEvent("modem_message", "skymodem", e[3].channel, e[3].reply, e[3].message, math.huge)
            end
        end
    end)
end)

local args = {...}
local command = table.remove(args, 1)
if command == "attach" or command == nil then
    if not peripheral.isPresent("skymodem") then
        peripheral.attach("skymodem", "modem", createModem())
    else
        printError("Skymodem already attached")
    end
elseif command == "detach" then
    if peripheral.isPresent("skymodem") then
        peripheral.detach("skymodem")
        skynet.disconnect()
    else
        printError("Skymodem not attached")
    end
else
    printError("skymodem <attach/detach>")
end