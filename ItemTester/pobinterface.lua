--[==[
    Methods that delve into the core of PoB and do useful things.

    This file is intended to be common across multiple projects.
]==]--

local pobinterface = {}


function pobinterface.loadBuild(path)
    local buildXml = loadText(path)
    loadBuildFromXML(buildXml)
    build.buildName = getFilename(path)
    build.dbFileName = path
    build.dbFileSubPath = ''
end


function pobinterface.saveBuild()
    if not build.dbFileName then
        error("Unable to save - no build path set")
    end

    build.actionOnSave = nil -- Avoid post-save actions like app update, exit
    build:SaveDBFile()
end


function pobinterface.saveBuildAs(path)
    local saveXml = saveBuildToXml()
    saveText(path, saveXml)
end


function pobinterface.readSkillSelection()
    local pickedGroupIndex = build.mainSocketGroup
    local socketGroup = build.skillsTab.socketGroupList[pickedGroupIndex]
    local pickedGroupName = socketGroup.displayLabel
    local pickedActiveSkillIndex = socketGroup.mainActiveSkill
    local displaySkill = socketGroup.displaySkillList[pickedActiveSkillIndex]
    local activeEffect = displaySkill.activeEffect
    local pickedActiveSkillName = activeEffect.grantedEffect.name
    local pickedPartIndex = activeEffect.grantedEffect.parts and activeEffect.srcInstance.skillPart
    local pickedPartName = activeEffect.grantedEffect.parts and activeEffect.grantedEffect.parts[pickedPartIndex].name

    return {
        group = pickedGroupName,
        name = pickedActiveSkillName,
        part = pickedPartName,
    }
end


function getFilename(path)
    local start, finish = path:find('[%w%s!-={-|]+[_%.].+')
    local name = path:sub(start,#path)
    if name:sub(-4) == '.xml' then
        name = name:sub(0, -5)
    end
    return name
end


function pobinterface.skillString(skill)
    return ""..(skill.group or '-').." / "..(skill.name or '-').." / "..(skill.part or '-')
end


function pobinterface.updateBuild()
    -- Update a build from the PoE website automatically, ensuring skills are restored after import

    -- Remember chosen skill and part
    local prevSkill = pobinterface.readSkillSelection()
    print("Previous skill group/gem/part: "..pobinterface.skillString(prevSkill))

    -- Check we have an account name
    if not isValidString(build.importTab.controls.accountName.buf) then
        error("Account name not configured for import")
    end
    -- result.account = build.importTab.controls.accountName.buf

    -- Check we have a character name
    if not build.importTab.lastCharacterHash or not isValidString(build.importTab.lastCharacterHash:match("%S")) then
        error("Character name not configured for import")
    end

    -- Get character list
    build.importTab:DownloadCharacterList()

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

    -- Restore chosen skills
    local newSkill = pobinterface.readSkillSelection()
    print("After update skill group/gem/part: "..pobinterface.skillString(newSkill))
    local newGroupIndex = build.mainSocketGroup
    socketGroup = build.skillsTab.socketGroupList[newGroupIndex]
    local newGroupName = socketGroup.displayLabel

    if newGroupName ~= prevSkill.group then
        print("Socket group name '"..(newSkill.group).."' doesn't match... fixing")
        for i,grp in pairs(build.skillsTab.socketGroupList) do
            if grp.displayLabel == prevSkill.group then
                build.mainSocketGroup = i
                newGroupIndex = i
                socketGroup = build.skillsTab.socketGroupList[newGroupIndex]
                newGroupName = socketGroup.displayLabel
                break
            end
        end
        if newGroupName ~= prevSkill.group then
            error("Unable to update safely: Previous socket group not found (was '"..prevSkill.group.."')")
        end
    end

    local newActiveSkillIndex = socketGroup.mainActiveSkill
    local displaySkill = socketGroup.displaySkillList[newActiveSkillIndex]
    local activeEffect = displaySkill and displaySkill.activeEffect
    local newActiveSkillName = activeEffect and activeEffect.grantedEffect.name

    if newActiveSkillName ~= prevSkill.name then
        print("Active skill '"..(newSkill.name).."' doesn't match... fixing")
        for i,skill in pairs(socketGroup.displaySkillList) do
            if skill.activeEffect.grantedEffect.name == prevSkill.name then
                socketGroup.mainActiveSkill = i
                newActiveSkillIndex = i
                displaySkill = socketGroup.displaySkillList[newActiveSkillIndex]
                activeEffect = displaySkill.activeEffect
                newActiveSkillName = activeEffect.grantedEffect.name
                break
            end
        end
        if newGroupName ~= prevSkill.group then
            error("Unable to update safely: Previous active skill not found (was '"..prevSkill.name.."')")
        end
    end

    local newPartIndex = activeEffect.grantedEffect.parts and activeEffect.srcInstance.skillPart
    local newPartName = activeEffect.grantedEffect.parts and activeEffect.grantedEffect.parts[newPartIndex].name

    if pickedPartIndex and newPartName ~= prevSkill.part then
        print("Active sub-skill '"..(newSkill.part).."' doesn't match... fixing")
        for i,part in pairs(activeEffect.grantedEffect.parts) do
            if part.name == prevSkill.part then
                activeEffect.srcInstance.skillPart = i
                newPartIndex = i
                newPartName = part.name
                break
            end
        end
        if newPartName ~= prevSkill.part then
            error("Unable to update safely: Previous active skill-part not found (was '"..prevSkill.part.."')")
        end
    end
end


function pobinterface.findModEffect(modLine)
    -- Construct an empty passive socket node to test in
    local testNode = {id="temporary-test-node", type="Socket", alloc=false, sd={"Temp Test Socket"}, modList={}}

    -- Construct jewel with the mod just to use its mods in the passive node
    local itemText = "Test Jewel\nMurderous Eye Jewel\n"..modLine
    local item = new("Item", build.targetVersion, itemText)
    testNode.modList = item.modList

    -- Calculate stat differences
    local calcFunc, baseStats = build.calcsTab:GetMiscCalculator()
    local newStats = calcFunc({ addNodes={ [testNode]=true } })

    return {base=baseStats, new=newStats}
end


return pobinterface
