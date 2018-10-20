HELP = [[
    To use this tool:

    1) Ensure you have saved your build in PoB.
    2) On the command-line run: "Path of Building.exe" ItemTester\SearchDPS.lua Builds\<buildname>.xml
    3) Take the output and paste it into the JavaScript console (F12) of http://gw2crafts.net/pobsearch/modsearch.html.
]]


local BUILD_XML = arg[1];
if BUILD_XML == nil then
    print("Usage: SearchDPS.lua <build xml>")
    os.exit(1)
end

local _,_,SCRIPT_PATH=string.find(arg[0], "(.+[/\\]).-")
dofile(SCRIPT_PATH.."mockui.lua")

xml = require("xml")
inspect = require("inspect")


function findModEffect(modLine)
    -- Construct flask with the mod
    local itemText = "Test Item\nAmethyst Flask\n"..modLine
    local item = common.New("Item", build.targetVersion, itemText)

    -- Calculate stat differences
    local calcFunc, baseStats = build.calcsTab:GetMiscCalculator()
    local newStats = calcFunc({ toggleFlask = item })

    -- Pull out the difference in Total DPS
    local statVal1 = newStats.TotalDPS or newStats.AverageHit or 0
    local statVal2 = baseStats.TotalDPS or baseStats.AverageHit or 0
    local diff = statVal1 - statVal2

    return diff
end

modData = {
    { id="flat accuracy", scale="100", text="+100 to Accuracy Rating" },
    { id="% accuracy", scale="10", text="10% increased Global Accuracy Rating" },
    { id="% physical", scale="12", text="12% increased Physical Damage" },
    { id="% lightning", scale="12", text="12% increased Lightning Damage" },
    { id="% cold", scale="12", text="12% increased Cold Damage" },
    { id="% fire", scale="12", text="12% increased Fire Damage" },
    { id="% elemental", scale="12", text="12% increased Elemental Damage" },
    { id="% chaos", scale="12", text="12% increased Chaos Damage" },
    { id="% generic", scale="12", text="12% increased Damage" },
    { id="crit chance", scale="16", text="16% increased Global Critical Strike Chance" },
    { id="crit multi", scale="16", text="+16% to Global Critical Strike Multiplier" },
    { id="attack speed", scale="10", text="10% increased Attack Speed" },
    { id="cast speed", scale="10", text="10% increased Cast Speed" },
    { id="pen all", scale="8", text="Damage Penetrates 8% Elemental Resistances" },
    { id="pen lightning", scale="8", text="Damage Penetrates 8% Lightning Resistance" },
    { id="pen cold", scale="8", text="Damage Penetrates 8% Cold Resistance" },
    { id="pen fire", scale="8", text="Damage Penetrates 8% Fire Resistance" },
    { id="flat phys", scale="6", text="Adds 5 to 7 Physical Damage" },
    { id="flat lightning", scale="37", text="Adds 6 to 68 Lightning Damage" },
    { id="flat cold", scale="22.5", text="Adds 14 to 31 Cold Damage" },
    { id="flat fire", scale="27.5", text="Adds 21 to 34 Fire Damage" },
    { id="flat chaos", scale="5.5", text="Adds 4 to 7 Chaos Damage" },
    { id="extra lightning", scale="15", text="15% of Physical Damage as Extra Lightning Damage" },
    { id="extra cold", scale="15", text="15% of Physical Damage as Extra Cold Damage" },
    { id="extra fire", scale="15", text="15% of Physical Damage as Extra Fire Damage" },
    { id="extra chaos", scale="15", text="Gain 15% of Non-Chaos damage as Extra Chaos Damage" },
    { id="ele as chaos", scale="15", text="Gain 15% of Elemental Damage as Extra Chaos Damage" },
    { id="+1 power charge", scale="1", text="+1 to Maximum Power Charges" },
    { id="+1 frenzy charge", scale="1", text="+1 to Maximum Frenzy Charges" },
    { id="+1 endurance charge", scale="1", text="+1 to Maximum Endurance Charges" },
}


-- Load a specific build file or use the default
if BUILD_XML ~= "CURRENT" then
    local buildXml = loadText(BUILD_XML)
    loadBuildFromXML(buildXml)
end

-- Get DPS difference for each mod and output
print('f=function(n,v){document.getElementsByName(n)[0].value=v}')
local modEffects = {}
for _,mod in ipairs(modData) do
    local dps = findModEffect(mod.text)
    -- dps = dps / tonumber(mod.scale) -- only needed if inputting to the original Python script
    print(string.format("f('%s','%.1f')", mod.id, dps))
end
