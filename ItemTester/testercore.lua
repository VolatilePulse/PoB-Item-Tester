--[==[
    Shared methods used by multiple scripts within PoB Item Tester.
]==]--

local pobinterface = require('pobinterface')

local testercore = {}


function testercore.loadBuild(path)
    if path == "CURRENT" then
        -- Just check already-loaded build is viable
        if not build.buildName or not build.dbFileName then
            print("ERROR: Path of Building has no 'current' build selected!")
            print("PoB must be closed while the desired build is loaded for the 'current' option to work.")
            os.exit(1)
        end
        print("Using PoB's last loaded build")
    else
        pobinterface.loadBuild(path)
    end

    print("Path: "..build.dbFileName)
    print("Build: "..build.buildName)
end


function testercore.saveBuild()
    print("Saving: "..build.dbFileName)
    pobinterface.saveBuild()
end


function testercore.showSkills()
    local skill = pobinterface.readSkillSelection()
    print("Skill: "..pobinterface.skillString(skill))
end


return testercore
