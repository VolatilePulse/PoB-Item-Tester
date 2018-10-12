HELP = [[
    To use this tool:

    1) Ensure you have an empty jewel socket in PoB and you have saved your build.
    2) Run this script with your build XML file as the first argument.
    3) Take the output weights and paste them into GenerateSearch.py.
    4) Set build-specific terms in 'selections' in GenerateSearch.py.
    5) Run GenerateSearch.py and use the generated URL.
]]


local BUILD_XML = arg[1];
if BUILD_XML == nil then
    print("Usage: SearchDPS.lua <build xml>")
    os.exit(1)
end

dofile("ItemTester/mockui.lua")

xml = require("xml")
inspect = require("inspect")


function findSlotToUse()
    -- A fake item to narrow the slots down
    local modLine = "+100 to Accuracy Rating"
    local itemText = "Rarity: Rare\n+100 to Accuracy Rating\nHypnotic Eye Jewel\n--------\nItem Level: 1\n--------\n+100 to Accuracy Rating"
    local item = common.New("Item", build.targetVersion, itemText)

    local compareSlots = { }
    for slotName, slot in pairs(build.itemsTab.slots) do
        if build.itemsTab:IsItemValidForSlot(item, slotName) and not slot.inactive and (not slot.weaponSet or slot.weaponSet == (build.itemsTab.activeItemSet.useSecondWeaponSet and 2 or 1)) then
            t_insert(compareSlots, slot)
        end
    end

    -- Sort empty or lowest-numbered sockets first
    table.sort(compareSlots, function(a, b)
        if a.selItemId ~= b.selItemId then
            if a.selItemId == 0 then
                return true
            elseif b.selItemId == 0 then
                return false
            elseif item == build.itemsTab.items[a.selItemId] then
                return true
            elseif item == build.itemsTab.items[b.selItemId] then
                return false
            end
        end
        local aNum = tonumber(a.slotName:match("%d+"))
        local bNum = tonumber(b.slotName:match("%d+"))
        if aNum and bNum then
            return aNum < bNum
        else
            return a.slotName < b.slotName
        end
    end)

    -- First is best
    return compareSlots[1]
end

function findModEffect(modLine, slot)
    -- Construct jewel with the mod
    local itemText = "Rarity: Rare\n"..modLine.."\n".."Hypnotic Eye Jewel\n--------\nItem Level: 1\n--------\n"..modLine
    local item = common.New("Item", build.targetVersion, itemText)
    item:NormaliseQuality()
    item:BuildModList()

    -- Calculate stat differences
    local calcFunc, calcBase = build.calcsTab:GetMiscCalculator()
    build.itemsTab:UpdateSockets()
    local selItem = build.itemsTab.items[slot.selItemId]
    local compareBase = calcFunc({ repSlotName = slot.slotName, repItem = item ~= selItem and item })

    -- Pull out the difference in Total DPS
    local statVal1 = compareBase.TotalDPS or 0
    local statVal2 = calcBase.TotalDPS or 0
    local diff = statVal1 - statVal2

    return diff
end



-- Load a build file
local buildXml = loadText(BUILD_XML)
loadBuildFromXML(buildXml)

-- Load the DPS mod data
local mods = xml.LoadXMLFile("ItemTester/mods.xml")

-- Work out which slot to use
local slot = findSlotToUse()
print("Using slot "..slot.label)
print()

-- Get DPS difference for each mod
local modEffects = {}
for _,mod in ipairs(mods[1]) do
    local dps = findModEffect(mod[1], slot)
    dps = dps / tonumber(mod.attrib.scale)
    modEffects[mod.attrib.id] = dps
end
modEffects["extra random"] = (modEffects["extra fire"] + modEffects["extra cold"] + modEffects["extra lightning"]) / 3

-- Save mod effects
for id,dps in pairs(modEffects) do
    print(string.format("\t\t\"%s\": %.1f,", id, dps))
end
