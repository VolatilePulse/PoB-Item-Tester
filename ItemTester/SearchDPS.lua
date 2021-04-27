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
local testercore = require("testercore")
local pobinterface = require("pobinterface")

debug = false

function findRelevantStat(activeEffect, chosenField)
    local calcFunc, stats = build.calcsTab:GetMiscCalculator()

    local actorType = nil
    if stats.FullDPS == nil or stats.FullDPS == 0 then
        if stats['Minion'] then
            actorType = 'Minion'
        end

        if actorType then
            stats = stats[actorType]
        end
    end

    if chosenField and chosenField == "OPTIONS" then -- show stat list
        print("\nAvailable stats:")
        print(inspect(stats))
        os.exit(1)
    elseif chosenField and stats[chosenField] ~= nil then -- user-specified stat
        return actorType,chosenField
    elseif chosenField then -- bad user-specified stat
        print("ERROR: Stat '"..chosenField.."' is not found (case sensitive)")
        os.exit(1)
    end

    if stats['FullDPS'] ~= 0 then return actorType,'FullDPS' end
    if stats['CombinedDPS'] ~= 0 then return actorType,'CombinedDPS' end
    if stats['AverageHit'] ~= 0 then return actorType,'AverageHit' end
    if stats['TotalDotDPS'] ~= 0 then return actorType,'TotalDotDPS' end
    print("ERROR: Don't know how to deal with this build's damage output type")
    os.exit(1)
end

function findModEffect(modLine, statField, actorType)
    -- Construct an empty passive socket node to test in
    local testNode = {id="temporary-test-node", type="Socket", alloc=false, sd={"Temp Test Socket"}, modList={}}

    -- Construct jewel with the mod just to use its mods in the passive node
    local itemText = "Test Jewel\nCobalt Jewel\n"..modLine
    local item
    if build.targetVersionData then -- handle code changes in 1.4.170.17
        item = new("Item", build.targetVersion, itemText)
    else
        item = new("Item", itemText)
    end
    testNode.modList = item.modList

    -- Calculate stat differences
    local calcFunc, baseStats = build.calcsTab:GetMiscCalculator()
    local newStats = calcFunc({ addNodes={ [testNode]=true } })

    -- Switch to minion/totem stats if needed
    if actorType then
        newStats = newStats[actorType]
        baseStats = baseStats[actorType]
    end

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
    if modDB:Flag(nil, "Use"..name.."Charges") then
		value = modDB:Override(nil, name.."Charges") or value
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
    print("ERROR: Failed to load mods.json")
    os.exit(1)
end

-- Load a specific build file or use the default
testercore.loadBuild(BUILD_XML)

-- Work out which field to use to report damage: Full DPS / CombinedDPS / AverageHit
local actorType,statField = findRelevantStat(activeEffect, arg[2])

-- Setup the main actor for gathering data
local calcFunc, baseStats = build.calcsTab:GetMiscCalculator()
local env = build.calcsTab.calcs.initEnv(build, "CALCULATOR")
local actor = env.player

if actorType and statField ~= "FullDPS" then
    print("SWITCHING ACTOR: " .. actorType)
    baseStats = baseStats[actorType]
end

-- Work out a reasonable skill name
local skillName = "<unknown>"
if statField == "FullDPS" then
    -- List all skills included in Full DPS
    skillName = ""
    for i,skill in pairs(baseStats.SkillDPS) do
        skillName = skillName .. " + " .. skill.name
    end
    skillName = skillName:sub(4)
else
    -- Gather currently selected skill and part
    local parts = pobinterface.readSkillSelection()
    local pickedGroupName = parts.group
    local pickedActiveSkillName = parts.name
    skillName = pickedGroupName;
    if (pickedGroupName ~= pickedActiveSkillName) then
        skillName = skillName.." / "..pickedActiveSkillName
    end
    if (pickedPartName) then
        skillName = skillName.." / "..parts.part
    end
end

print()
print("Using stat: " .. statField)
print("Using actor: " .. (actorType or 'Player'))
print("Using skill(s): " .. skillName)
print()

-- Get DPS difference for each mod
url = 'https://xanthics.github.io/PoE_Weighted_Search/?'
modsVersion = modData[1].version
if modsVersion == nil then
    print("ERROR: mods.json needs updating")
    os.exit(2)
end
url = url .. "vals=" .. modsVersion .. ","
for _,mod in ipairs(modData) do
    local dps = findModEffect(mod.desc, statField, actorType)
    if debug then print('  ' .. mod.desc .. ' = ' .. dps) end
    if dps >= 0.05 or dps <= -0.05 then
        url = url .. string.format("%.1f,", dps)
    else
        url = url .. ","
    end
end
url = url:match("(.-),*$") .. "&"

if debug then
    -- print("Stats:")
    -- print(inspect(baseStats))

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

local flags = {}
local values = {}

-- Grab flags from main skill
for skillType,_ in pairs(actor.mainSkill.skillTypes) do
    for name,type in pairs(SkillType) do
        if type == skillType then
            if name:match("Can[A-Z]") or name:match("Triggerable") or name:match(".+SingleTarget") or name:match("Type[0-9]+") then
                name = nil
            elseif name:match("ManaCost.+") or name:match("Aura.*") or name:match("Buff.*") then
                name = nil
            elseif name == "Instant" then
                name = nil
            elseif name == "SecondWindSupport" then
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
if actor.mainSkill.skillFlags.brand then flags['Brand'] = true end
if actor.mainSkill.skillFlags.totem then flags['Totem'] = true end
if actor.mainSkill.skillFlags.trap then flags['Trap'] = true end
if actor.mainSkill.skillFlags.mine then flags['Mine'] = true end
if actor.mainSkill.skillFlags.minion then flags['Minion'] = true end
if actor.mainSkill.skillFlags.hit then flags['conditionHitRecently'] = true end

-- Insert flags for weapon types
flags["Shield"] = (actor.itemList["Weapon 2"] and actor.itemList["Weapon 2"].type == "Shield") or (actor == actor and env.aegisModList)
flags["DualWielding"] = actor.weaponData1.type and actor.weaponData2.type and actor.weaponData1.type ~= "None"
if actor.itemList["Weapon 1"] then extractWeaponFlags(env, actor.weaponData1, flags) end
if actor.itemList["Weapon 2"] then extractWeaponFlags(env, actor.weaponData2, flags) end
if flags["Spell"] then flags["Melee"] = nil end

-- Grab config flags
for flag,value in pairs(env.configInput) do
    if value == true and not flag:match("override") then
        flags[flag] = true
    end
end
if env.configInput['enemyIsBoss'] then flags['enemyIsBoss'] = true end
if env.configInput['ImpaleStacks'] then flags['ImpaleStacks'] = env.configInput['ImpaleStacks'] end
if baseStats["LifeUnreservedPercent"] and baseStats["LifeUnreservedPercent"] < 35 then flags["conditionLowLife"] = true end

-- Work out how many charges we have
for flag,value in pairs(flags) do
    name = flag:match('^use(.+)Charges$')
    if name then
        count = getCharges(name, actor.modDB)
        if count then values[name .. 'Count'] = count end
        flags[flag] = nil
    end
end

-- Infer some extra flags from what we already have
if flags.Fire or flags.Cold or flags.Lightning then flags.Elemental = true end
if baseStats.ChaosTakenHitMult == 0 then flags.conditionFullLife = true end -- CI
if actorType == 'Minion' then flags.conditionUsedMinionSkillRecently = true end

-- Add values to URL
if debug then print('\nPost values:') end
for name,value in pairs(values) do
    if value then url = url..urlencode(name:gsub(' ','')).."="..encodeValue(value).."&" end
    if debug then print('  '..name..string.format(" = %s", value)) end
end

-- Add flags to URL
if debug then print('\nPost flags:') end
local flagsString = 'Flags='
for flag,value in pairs(flags) do
    flag = flag:gsub('^condition', '')
    flag = flag:gsub(' ', '')
    if value then flagsString = flagsString..urlencode(flag).."," end
    if debug then print('  '..flag) end
end
url = url..flagsString.."&"

-- Add skill name and character name
name = build.buildName:gsub('.*[/\\]', ''):gsub('.xml','')
url = url.."Skill="..urlencode(skillName).."&".."Character="..urlencode(name)

if debug then
    print()
    print(url)
else
    os.execute('start "" "' .. url .. '"')
end
