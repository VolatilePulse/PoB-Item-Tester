local BUILD_XML = arg[1]

dofile("ItemTester/mockui.lua")

inspect = require("inspect")

xml = require("xml")


function findModEffect(modLine)
    -- Construct jewel with the mod
    local itemText = "Rarity: Rare\n"..modLine.."\n".."Hypnotic Eye Jewel\n--------\nItem Level: 1\n--------\n"..modLine
    print(itemText)
    local newItem = common.New("Item", build.targetVersion, itemText)
    -- print(inspect(newItem, {depth=1}))

    -- Extract new item's info to a fake tooltip
    newItem:NormaliseQuality()
    newItem:BuildModList()

    local calcFunc, calcBase = build.calcsTab:GetMiscCalculator()
    build.itemsTab:UpdateSockets()

    local compareSlots = { }
    for slotName, slot in pairs(build.itemsTab.slots) do
        if build.itemsTab:IsItemValidForSlot(newItem, slotName) and not slot.inactive and (not slot.weaponSet or slot.weaponSet == (build.itemsTab.activeItemSet.useSecondWeaponSet and 2 or 1)) then
            t_insert(compareSlots, slot)
        end
    end
    table.sort(compareSlots, function(a, b)
        if a.selItemId ~= b.selItemId then
            if item == build.itemsTab.items[a.selItemId] then
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

    -- Add comparisons for each slot
    for _, slot in pairs(compareSlots) do
        local selItem = build.itemsTab.items[slot.selItemId]
        local compareBase = calcFunc({ repSlotName = slot.slotName, repItem = item ~= selItem and item })

        print("")
        print(slot.label)
        print(inspect(compareBase, {depth=1}))
        print(inspect(calcBase, {depth=1}))
        io.read()

        print(compareBase["TotalDPS"].." : "..calcBase["TotalDPS"])
        local statVal1 = compareBase["TotalDPS"] or 0
        local statVal2 = calcBase["TotalDPS"] or 0
        local diff = statVal1 - statVal2
        return diff
    end

    return 0
end


-- Load a build file
local buildXml = loadText(BUILD_XML)
loadBuildFromXML(buildXml)

-- Load the DPS mod data
local mods = xml.LoadXMLFile("ItemTester/mods.xml")

-- Get DPS difference for each mod
local modEffects = {}
for _,mod in ipairs(mods[1]) do
    -- print(inspect(mod))
    print(mod[1])
    local dps = findModEffect(mod[1])
    print(dps)
    dps = dps / tonumber(mod.attrib.scale)
    print(dps)
    modEffects[mod.attrib.id] = dps
end
modEffects["extra random"] = (modEffects["extra fire"] + modEffects["extra cold"] + modEffects["extra lightning"]) / 3

-- Save mod effects
for id,dps in ipairs(modEffects) do
    print(string.format("%.1f: %s", dps, id))
end
