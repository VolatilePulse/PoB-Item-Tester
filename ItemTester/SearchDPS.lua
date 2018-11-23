HELP = [[
    Use the AHK script with hotkey Ctrl-Windows-D.

    See testdps.bat for an example of running it directly.
]]


local BUILD_XML = arg[1]
if BUILD_XML == nil or BUILD_XML == "-h" or BUILD_XML == "--help" or BUILD_XML == "/?" then
    print("Usage: SearchDPS.lua <build xml>|CURRENT [<statname>|OPTIONS]")
    os.exit(1)
end

local _,_,SCRIPT_PATH=string.find(arg[0], "(.+[/\\]).-")
dofile(SCRIPT_PATH.."mockui.lua")

xml = require("xml")
json = require("json")
inspect = require("inspect")

debug = false

function findRelevantStat(activeEffect, chosenField)
    local calcFunc, stats = build.calcsTab:GetMiscCalculator()

    if chosenField and stats[chosenField] ~= nil then
        return chosenField
    elseif chosenField and chosenField == "OPTIONS" then
        print("\nAvailable stats:")
        print(inspect(stats))
        os.exit(1)
    elseif chosenField and stats[chosenField] == nil then
        print("Error: Stat '"..chosenField.."' is not found (case sensitive)")
        os.exit(1)
    end

    local useAverage = false
    for _,mod in ipairs(activeEffect.grantedEffect.baseMods) do
        if mod.value and type(mod.value) == "table" and mod.value.key == "showAverage" and mod.value.value == true then
            useAverage = true
        end
    end

    if (stats['CombinedDPS']) and not useAverage then return 'CombinedDPS' end
    if (stats['AverageHit']) then return 'AverageHit' end

    print("Error: Don't know how to deal with this build's damage output type")
    os.exit(1)
end

function findModEffect(modLine, statField)
    -- Construct an empty passive socket node to test in
    local testNode = {id="temporary-test-node", type="Socket", alloc=false, sd={"Temp Test Socket"}, modList={}}

    -- Construct jewel with the mod just to use its mods in the passive node
    local itemText = "Test Jewel\nMurderous Eye Jewel\n"..modLine
    local item = common.New("Item", build.targetVersion, itemText)
    testNode.modList = item.modList

    -- Calculate stat differences
    local calcFunc, baseStats = build.calcsTab:GetMiscCalculator()
    local newStats = calcFunc({ addNodes={ [testNode]=true } })

    -- Pull out the difference in DPS
    local statVal1 = newStats[statField] or 0
    local statVal2 = baseStats[statField] or 0
    local diff = statVal1 - statVal2

    return diff
end

function char_to_hex(c)
    return string.format("%%%02X", string.byte(c))
end

function urlencode(url)
    if url == nil then
        return
    end
    url = url:gsub("([^%w])", char_to_hex)
    return url
end

function extractWeaponFlags(env, weapon, flags)
    if not weapon or not weapon.type then return end
    local info = env.data.weaponTypeInfo[weapon.type]
    flags[info.flag] = true
    if info.melee then flags['Melee'] = true end
    if info.oneHand then
        flags['One Handed Weapon'] = true
    else
        flags['Two Handed Weapon'] = true
    end
end

function getCharges(name, modDB)
    local value = modDB:Sum("BASE", nil, name.."ChargesMax")
    if modDB:Sum("FLAG", nil, "Use"..name.."Charges") then
		value = modDB:Sum("OVERRIDE", nil, name.."Charges") or value
	else
		value = 0
    end
    return value
end

function encodeValue(value)
    if value == true then
        return "True"
    else
        return string.format("%s", value)
    end
end

local modDataText = loadText(SCRIPT_PATH.."mods.json")
if modDataText then
    modData = json.decode(modDataText)
else
    print("Error: Failed to load mods.json")
    os.exit(1)
end

-- Load a specific build file or use the default
if BUILD_XML ~= "CURRENT" then
    local buildXml = loadText(BUILD_XML)
    loadBuildFromXML(buildXml)
end

-- Gather chosen skill and part
local pickedGroupIndex = build.mainSocketGroup
local socketGroup = build.skillsTab.socketGroupList[pickedGroupIndex]
local pickedGroupName = socketGroup.displayLabel
local pickedActiveSkillIndex = socketGroup.mainActiveSkill
local displaySkill = socketGroup.displaySkillList[pickedActiveSkillIndex]
local activeEffect = displaySkill.activeEffect
local pickedActiveSkillName = activeEffect.grantedEffect.name
local pickedPartIndex = activeEffect.grantedEffect.parts and activeEffect.srcInstance.skillPart
local pickedPartName = activeEffect.grantedEffect.parts and activeEffect.grantedEffect.parts[pickedPartIndex].name

-- Work out a reasonable skill name
local skillName = pickedGroupName;
if (pickedGroupName ~= pickedActiveSkillName) then
    skillName = skillName.." / "..pickedActiveSkillName
end
if (pickedPartName) then
    skillName = skillName.." / "..pickedPartName
end

print("Character: "..build.buildName)
print("Current skill: "..skillName)

-- Work out which field to use to report damage: CombinedDPS / AverageHit
local statField = findRelevantStat(activeEffect, arg[2])
print("Using stat: " .. statField)
print()

-- Setup the main actor for gathering data
local env = build.calcsTab.calcs.initEnv(build, "CALCULATOR")
local actor = env.player

-- Get DPS difference for each mod
url = 'http://gw2crafts.net/pobsearch/modsearch.html?'
for _,mod in ipairs(modData) do
    local dps = findModEffect(mod.desc, statField)
    -- dps = dps / tonumber(mod.count) -- only needed if inputting to the original Python script
    url = url .. string.format("%s=%.1f&", urlencode(mod.name), dps)
    -- print(string.format("%s = %.1f", mod.desc, dps))
end

if debug then
    -- print("Stats:")
    -- local calcFunc, stats = build.calcsTab:GetMiscCalculator()
    -- print(inspect(stats))

    print("\nConditions:")
    print(inspect(env.modDB.conditions))

    print("\nConfig:")
    print(inspect(env.configInput))

    print("\nSkill flags:")
    print(inspect(actor.mainSkill.skillFlags))

    print("\nWeapon 1: " .. (actor.weaponData1.type or '-') .. " (" .. (actor.weaponData1.type and env.data.weaponTypeInfo[actor.weaponData1.type].flag or '-') .. ")")
    print("Weapon 2: " .. (actor.weaponData2.type or '-') .. " (" .. (actor.weaponData2.type and env.data.weaponTypeInfo[actor.weaponData2.type].flag or '-') .. ")")
    print()
end


-- Grab flags from main skill
local flags = {}
for skillType,_ in pairs(actor.mainSkill.skillTypes) do
    for name,type in pairs(SkillType) do
        if type == skillType then
            if name:match("Can[A-Z]") or name:match("Triggerable") or name:match(".+SingleTarget") or name:match("Type[0-9]+") then
                name = nil
            elseif name:match("ManaCost.+") or name:match("Aura.*") or name:match("Buff.*") then
                name = nil
            elseif name == "Instant" then
                name = nil
            elseif name:match(".+Skill") or name:match(".+Spell") then
                name = name:sub(0, #name-5)
            elseif name:match("Causes.+") then
                name = name:sub(7)
            elseif name:match(".+Attack") then
                name = name:sub(0, #name-6)
            end
            if name then flags[name] = true end
        end
    end
end
if actor.mainSkill.skillFlags.totem then flags['Totem'] = true end
if actor.mainSkill.skillFlags.trap then flags['Trap'] = true end
if actor.mainSkill.skillFlags.mine then flags['Mine'] = true end
if actor.mainSkill.skillFlags.minion then flags['Minion'] = true end
if actor.mainSkill.skillFlags.hit then flags['Recent Hit'] = true end

-- Insert flags for weapon types
flags["Shield"] = (actor.itemList["Weapon 2"] and actor.itemList["Weapon 2"].type == "Shield") or (actor == actor and env.aegisModList)
flags["Duel Wielding"] = actor.weaponData1.type and actor.weaponData2.type and actor.weaponData1.type ~= "None"
if actor.itemList["Weapon 1"] then extractWeaponFlags(env, actor.weaponData1, flags) end
if actor.itemList["Weapon 2"] then extractWeaponFlags(env, actor.weaponData2, flags) end
if flags["Spell"] then flags["Melee"] = nil end

-- Grab config flags
if env.configInput.useFrenzyCharges then flags["Frenzy"] = true end
if env.configInput.usePowerCharges then flags["Power"] = true end
if env.configInput.useEnduranceCharges then flags["Endurance"] = true end
if env.configInput.conditionCritRecently then flags["Recent Crit"] = true end
if env.configInput.conditionUsingFlask then flags["Flasked"] = true end

-- Work out how many charges we have
flags["Frenzy Count"] = getCharges("Frenzy", actor.modDB)
flags["Power Count"] = getCharges("Power", actor.modDB)
flags["Endurance Count"] = getCharges("Endurance", actor.modDB)

-- Grab enemy status flags
for configFlag,_ in pairs(env.configInput) do
    if configFlag:match('conditionEnemy.+') then flags[configFlag:sub(15)] = true end
end

-- Infer some extra flags from what we already have
if flags.Fire or flags.Cold or flags.Lightning then flags.Elemental = true end

-- Add flags to URL
for flag,value in pairs(flags) do
    if value then url = url..urlencode(flag).."="..encodeValue(value).."&" end
    if debug then print(flag..string.format(" = %s", value)) end
end

-- Add skill name and character name
url = url.."Skill="..urlencode(skillName).."&".."Character="..urlencode(build.buildName)

if debug then
    print()
    print(url)
else
    os.execute('start "" "' .. url .. '"')
end
