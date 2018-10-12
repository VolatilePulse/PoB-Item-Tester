local BUILD_XML = arg[1]
local INPUT_FILE = arg[2]
local OUTPUT_FILE = INPUT_FILE..".html"

dofile("ItemTester/mockui.lua")

local fileHeader = [[
<!DOCTYPE html><html><head><style>
body { padding: 4px; margin: 0; font: 12px sans-serif; background: #0c0a08; color: white; border: #ffff77 solid 3px }
p { padding: 0; margin: 0 }
p:nth-child(1) { font-size: 120% }
p:nth-child(2) { font-size: 120% }
hr { margin: 4px -4px 4px -4px; border: none; border-top: #ffff77 solid 2px }
</style></head><body>
]]

-- Load a build file
local buildXml = loadText(BUILD_XML)
loadBuildFromXML(buildXml)

-- Load an item from copy data
local itemText = loadText(INPUT_FILE)
local newItem = common.New("Item", build.targetVersion, itemText)

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
end

print("Results output to: "..OUTPUT_FILE)