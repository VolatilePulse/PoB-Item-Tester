HELP = [[
    Use the AHK script with hotkey Ctrl-Windows-C.

    See testitem.bat for an example of running it directly.
    Output HTML goes to <input path>.html

    Usage: lua TestItem.lua <build xml> <item path>
]]

local BUILD_XML = arg[1]
local INPUT_FILE = arg[2]
local OUTPUT_FILE = INPUT_FILE..".html"

local _,_,SCRIPT_PATH=string.find(arg[0], "(.+[/\\]).-")
dofile(SCRIPT_PATH.."mockui.lua")

local fileHeader = [[
<!DOCTYPE html><html><head><style>
body { padding: 4px; margin: 0; font: 12px sans-serif; background: #0c0a08; color: white; border: #ffff77 solid 3px }
p { padding: 0; margin: 0 }
p:nth-child(1) { font-size: 120% }
p:nth-child(2) { font-size: 120% }
hr { margin: 4px -4px 4px -4px; border: none; border-top: #ffff77 solid 2px }
</style></head><body>
]]


local testercore = require("testercore")
local pobinterface = require('pobinterface')

-- Load a specific build file or use the default
testercore.loadBuild(BUILD_XML)
testercore.showSkills()

-- Load an item from copy data
local itemText = loadText(INPUT_FILE)
local newItem
if build.targetVersionData then -- handle code format changes in 1.4.170.17
    newItem = new("Item", build.targetVersion, itemText)
else
    newItem = new("Item", itemText)
end

if newItem.base then
	newItem:NormaliseQuality() -- Set to top quality
	newItem:BuildModList()

	-- Extract new item's info to a fake tooltip
	local tooltip = FakeTooltip:new()
	build.itemsTab:AddItemTooltip(tooltip, newItem)

	-- Output tooltip as HTML
	local outFile = io.open(OUTPUT_FILE, "w")
	if outFile then
		outFile:write(fileHeader)
		for i, txt in pairs(tooltip.lines) do
			outFile:write(txt.."\n");
		end
		outFile:close()
    end

    print("Results output to: "..OUTPUT_FILE)
else
    print("ERROR: Unknown error calculating item")
    os.exit(1)
end

