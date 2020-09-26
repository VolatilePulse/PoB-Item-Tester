HELP = [[
    Re-imports a build from pathofexile.com automatically.

    Usage: lua UpdateBuild.lua <build xml>
]]


local BUILD_XML = arg[1];
if BUILD_XML == nil then
    print("Usage: UpdateBuild.lua <build xml>|CURRENT")
    os.exit(1)
end

local _,_,SCRIPT_PATH=string.find(arg[0], "(.+[/\\]).-")
dofile(SCRIPT_PATH.."mockui.lua")

xml = require("xml")
inspect = require("inspect")
testercore = require("testercore")

-- Load a specific build file or use the default
testercore.loadBuild(BUILD_XML)
local parts = testercore.readBuildInfo()
local pickedGroupName = parts.pickedGroupName
local pickedActiveSkillName = parts.pickedActiveSkillName
local pickedPartName = parts.pickedPartName

-- Being the long update process...
print("Importing character changes...")

-- Check we have an account name
if not isValidString(build.importTab.controls.accountName.buf) then
    print("ERROR: Account name not configured. Aborting.")
    os.exit(1)
end

-- Check we have a character name
if not build.importTab.lastCharacterHash or not isValidString(build.importTab.lastCharacterHash:match("%S")) then
    print("ERROR: Importable character name not configured for this build. Aborting.")
    os.exit(1)
end

-- Get character list
build.importTab:DownloadCharacterList()
-- print('Status: '..build.importTab.charImportStatus)

-- Import tree and jewels
build.importTab.controls.charImportTreeClearJewels.state = true
build.importTab:DownloadPassiveTree()
-- print('Status: '..build.importTab.charImportStatus)

-- Import items and skills
build.importTab.controls.charImportItemsClearItems.state = true
build.importTab.controls.charImportItemsClearSkills.state = true
build.importTab:DownloadItems()
-- print('Status: '..build.importTab.charImportStatus)

-- Update skills
build.outputRevision = build.outputRevision + 1
build.buildFlag = false
build.calcsTab:BuildOutput()
build:RefreshStatList()
build:RefreshSkillSelectControls(build.controls, build.mainSocketGroup, "")



-- Re-instate chosen skills
local newGroupIndex = build.mainSocketGroup
socketGroup = build.skillsTab.socketGroupList[newGroupIndex]
local newGroupName = socketGroup.displayLabel
-- print("After import group: "..newGroupName)

if newGroupName ~= pickedGroupName then
    print("Socket group name doesn't match... fixing")
    for i,grp in pairs(build.skillsTab.socketGroupList) do
        if grp.displayLabel == pickedGroupName then
            build.mainSocketGroup = i
            newGroupIndex = i
            socketGroup = build.skillsTab.socketGroupList[newGroupIndex]
            newGroupName = socketGroup.displayLabel
            break
        end
    end
    if newGroupName ~= pickedGroupName then
        print("ERROR: Previously selected socket group was not found. Aborting.")
        os.exit(11)
    end
end

local newActiveSkillIndex = socketGroup.mainActiveSkill
local displaySkill = socketGroup.displaySkillList[newActiveSkillIndex]
local activeEffect = displaySkill.activeEffect
local newActiveSkillName = activeEffect.grantedEffect.name
-- print("After import skill: "..newActiveSkillName)

if newActiveSkillName ~= pickedActiveSkillName then
    print("Active skill doesn't match... fixing")
    for i,skill in pairs(socketGroup.displaySkillList) do
        if skill.activeEffect.grantedEffect.name == pickedActiveSkillName then
            socketGroup.mainActiveSkill = i
            newActiveSkillIndex = i
            displaySkill = socketGroup.displaySkillList[newActiveSkillIndex]
            activeEffect = displaySkill.activeEffect
            newActiveSkillName = activeEffect.grantedEffect.name
            break
        end
    end
    if newGroupName ~= pickedGroupName then
        print("ERROR: Previously selected active skill not found. Aborting.")
        os.exit(11)
    end
end

local newPartIndex = activeEffect.grantedEffect.parts and activeEffect.srcInstance.skillPart
local newPartName = activeEffect.grantedEffect.parts and activeEffect.grantedEffect.parts[newPartIndex].name
-- print("After import sub-skill: "..newPartName)

if pickedPartIndex and newPartName ~= pickedPartName then
    print("Active sub-skill doesn't match... fixing")
    for i,part in pairs(activeEffect.grantedEffect.parts) do
        -- print(inspect(part, {depth=1}))
        if part.name == pickedPartName then
            activeEffect.srcInstance.skillPart = i
            newPartIndex = i
            newPartName = part.name
            break
        end
    end
    if pickedPartName and newPartName ~= pickedPartName then
        print("ERROR: Previous active sub-skill not found. Aborting.")
        os.exit(11)
    end
end

-- print("Chosen group/skill/sub-skill: "..newGroupName..":"..newActiveSkillName..":"..newPartName)

-- Save
testercore.saveBuild(BUILD_XML)

print("Success")
