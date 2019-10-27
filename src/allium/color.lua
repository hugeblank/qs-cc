local colorAPI = {}

local cTable = {
    ["0"] = "black",
    ["1"] = "dark_blue",
    ["2"] = "dark_green",
    ["3"] = "dark_aqua",
    ["4"] = "dark_red",
    ["5"] = "dark_purple",
    ["6"] = "gold",
    ["7"] = "gray",
    ["8"] = "dark_gray",
    ["9"] = "blue",
    ["a"] = "green",
    ["b"] = "aqua",
    ["c"] = "red",
    ["d"] = "light_purple",
    ["e"] = "yellow",
    ["f"] = "white"
}
local formats = {
    ["l"] = "bold",
    ["n"] = "underlined",
	["o"] = "italic",
    ["k"] = "obfuscated",
    ["m"] = "strikethrough",
}
local actions = {
    ["s"] = "suggest_command",
    ["g"] = "run_command" ,
    ["i"] = "open_url" ,
}
local other = {
    ["h"] = "hoverEvent",
    ["r"] = "reset",
}
local dCurrent = {
	format = {
    	bold = false,
    	underlined = false,
    	italic = false,
    	obfuscated = false,
    	strikethrough = false,
	},
    color = "white",
    hoverEvent = false,
    action = false,
	actionText = "",
	hoverText = "",
}

local function copy(tbl)
	local ret = {}
	for k, v in pairs(tbl) do
		if type(v) ~= "table" then
			ret[k] = v
		else
			ret[k] = copy(v)
		end
	end
	return ret
end

local seperate = function(str)
	local outTbl = {}
	local tmpStr = ""
	local argument = ""
	local params = 0
	local start = false
	for i = 1, str:len() do
		local prev
		if i > 1 then
			prev = str:sub(i-1, i-1)
		end
		local current = str:sub(i, i)
		local next
		if i < str:len() then
			next = str:sub(i+1, i+1)
		end
		if next == "(" and (params > 0 or prev == "&") then
			params = params + 1
			if params == 1 then
				start = true
			end
		elseif prev == ")" and params > 0 then
			params = params - 1
		end
		if current == "&" and next ~= "&" and prev ~= "&" and params == 0 then
			table.insert(outTbl, {tmpStr, argument})
			tmpStr = ""
			argument = ""
		end
		if params > 0 and not start then
			argument = argument..current
		elseif current ~= "&" or (prev ~= "&" and current == "&") then
			start = false
			tmpStr = tmpStr..current
		end
	end
	table.insert(outTbl, {tmpStr, argument})
	return outTbl
end

colorAPI.format = function(str)
	local outTbl = {}
	local currentFormatting = copy(dCurrent)
	str = seperate(str)
	for _, v in pairs(str) do
		local first = v[1]:sub(1,1)
		local operator = v[1]:sub(2,2)
		local text = v[1]:sub(3)
		if first == "&" then
			if cTable[operator] then
				currentFormatting.color = cTable[operator]
				text = v[2]..text
			elseif formats[operator] then
				currentFormatting.format[formats[operator]] = not currentFormatting.format[formats[operator]]
				text = v[2]..text
			elseif actions[operator] then
				currentFormatting.action = actions[operator]
				currentFormatting.actionText = v[2]:sub(2, -2)
			elseif other[operator] then
				if other[operator] == "reset" then
					currentFormatting = copy(dCurrent)
					text = v[2]..text
				elseif other[operator] == "hoverEvent" then
					currentFormatting.hoverEvent = true
					currentFormatting.hoverText = v[2]:sub(2, -2)
				end
			else
				text = first..operator..v[2]..text
			end
		else
			text = first..operator..v[2]..text
		end
		local block = {
			["text"] = text,
			["color"] = currentFormatting.color,
			["bold"] = currentFormatting.format.bold,
			["underlined"] = currentFormatting.format.underlined,
			["italic"] = currentFormatting.format.italic,
			["strikethrough"] = currentFormatting.format.strikethrough,
			["obfuscated"] = currentFormatting.format.obfuscated,
		}
		if currentFormatting.action then
			block["clickEvent"] = {
				["action"] = currentFormatting.action,
				["value"] = currentFormatting.actionText
			}
		end
		if currentFormatting.hoverEvent then
			block["hoverEvent"] = {
				["action"] = "show_text",
				["value"] = currentFormatting.hoverText
			}
		end
		table.insert(outTbl, block)
	end
	return outTbl
end

return colorAPI
