function loadBuild(path)
    if path ~= "CURRENT" then
        print("Loading build: "..path)
        local buildXml = loadText(path)
        loadBuildFromXML(buildXml)
        build.buildName = getFilename(path)
    else
        if build.buildName == nil then
            print("ERROR: Path of Building has no 'current' build selected!")
            print("PoB must be closed while the desired build is loaded for the 'current' build option to work.")
            os.exit(1)
        end
        print("Using PoB's last loaded build")
    end

    print("Loaded character: "..build.buildName)
end


function readBuildInfo()
    local pickedGroupIndex = build.mainSocketGroup
    local socketGroup = build.skillsTab.socketGroupList[pickedGroupIndex]
    local pickedGroupName = socketGroup.displayLabel
    local pickedActiveSkillIndex = socketGroup.mainActiveSkill
    local displaySkill = socketGroup.displaySkillList[pickedActiveSkillIndex]
    local activeEffect = displaySkill.activeEffect
    local pickedActiveSkillName = activeEffect.grantedEffect.name
    local pickedPartIndex = activeEffect.grantedEffect.parts and activeEffect.srcInstance.skillPart
    local pickedPartName = activeEffect.grantedEffect.parts and activeEffect.grantedEffect.parts[pickedPartIndex].name

    print("Current skill group/gem/part: "..pickedGroupName.." / "..pickedActiveSkillName.." / "..(pickedPartName or '-'))

    return {
        pickedGroupName=pickedGroupName,
        pickedActiveSkillName=pickedActiveSkillName,
        pickedPartName=pickedPartName,
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


function saveBuild(path)
    if path == "CURRENT" then
        build:SaveDBFile()
    else
        local saveXml = saveBuildToXml()
        saveText(path, saveXml)
    end
end


return {
    loadBuild=loadBuild,
    saveBuild=saveBuild,
    readBuildInfo=readBuildInfo,
}
