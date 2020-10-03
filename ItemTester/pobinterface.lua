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
    local pickedGroupName = socketGroup and socketGroup.displayLabel
    local pickedActiveSkillIndex = socketGroup and socketGroup.mainActiveSkill
    local displaySkill = socketGroup and socketGroup.displaySkillList[pickedActiveSkillIndex]
    local activeEffect = displaySkill and displaySkill.activeEffect
    local pickedActiveSkillName = activeEffect and activeEffect.grantedEffect.name
    local pickedPartIndex = activeEffect and activeEffect.grantedEffect.parts and activeEffect.srcInstance.skillPart
    local pickedPartName = activeEffect and activeEffect.grantedEffect.parts and activeEffect.grantedEffect.parts[pickedPartIndex].name

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
    local skill = skill or pobinterface.readSkillSelection()
    return ""..(skill.group or '-').." / "..(skill.name or '-').." / "..(skill.part or '-')
end


function pobinterface.updateBuild()
    -- Update a build from the PoE website automatically, ensuring skills are restored after import
    print("Pre-update checks...")

    -- Check importing is configured correctly in the build
    if not isValidString(build.importTab.lastAccountHash) or not isValidString(build.importTab.lastCharacterHash) then
        error("Update failed: Character must be imported in PoB before it can be automatically updated")
    end

    -- Check importing is configured correctly in PoB itself
    if not isValidString(build.importTab.controls.accountName.buf) then
        error("Update failed: Account name must be set within PoB before it can be automatically updated")
    end

    -- Check importer is in the right state
    if build.importTab.charImportMode ~= "GETACCOUNTNAME" then
        error("Update failed: Unknown import error - is PoB importing set up correctly?")
    end

    -- Check account name in the input box actually matches the one configured in the build
    if common.sha1(build.importTab.controls.accountName.buf) ~= build.importTab.lastAccountHash then
        error("Update failed: Build comes from an account that is not configired in PoB - character must be imported in PoB before it can be automatically updated")
    end

    -- Get character list
    print("Looking for matching character...")
    build.importTab:DownloadCharacterList()

    -- Get the character PoB selected and check it actually matches the last import hash
    local char = build.importTab.controls.charSelect.list[build.importTab.controls.charSelect.selIndex]
    print("Character selected: "..char.char.name)
    if common.sha1(char.char.name) ~= build.importTab.lastCharacterHash then
        error("Update failed: Selected character not found - was it deleted or renamed?")
    end

    -- Check importer is in the right state
    if build.importTab.charImportMode ~= "SELECTCHAR" then
        error("Update failed: Import not fully set up on this build")
    end

    -- Import tree and jewels
    print("Downloading passive tree...")
    build.importTab.controls.charImportTreeClearJewels.state = true
    build.importTab:DownloadPassiveTree()

    -- Check importer is in the right state
    if build.importTab.charImportMode ~= "SELECTCHAR" then
        error("Update failed: Unable to download the passive tree")
    end

    -- Import items and skills
    print("Downloading items and skills...")
    build.importTab.controls.charImportItemsClearItems.state = true
    build.importTab.controls.charImportItemsClearSkills.state = true
    build.importTab:DownloadItems()

    -- Check importer is in the right state
    if build.importTab.charImportMode ~= "SELECTCHAR" then
        error("Update failed: Unable to download items and skills")
    end

    -- Update skills
    print("Completing update...")
    build.outputRevision = build.outputRevision + 1
    build.buildFlag = false
    build.calcsTab:BuildOutput()
    build:RefreshStatList()
    build:RefreshSkillSelectControls(build.controls, build.mainSocketGroup, "")

end


function pobinterface.selectSkill(prevSkill)
    local newSkill = pobinterface.readSkillSelection()

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
