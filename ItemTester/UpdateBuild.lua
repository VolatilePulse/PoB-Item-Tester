HELP = [[
    Re-imports a build from pathofexile.com automatically.

    See testupdate.bat for an example of running it directly.

    Usage: lua UpdateBuild.lua <build xml>|CURRENT
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

local testercore = require("testercore")
local pobinterface = require('pobinterface')


testercore.loadBuild(BUILD_XML)

-- Remember previously selected skill
local prevSkill = pobinterface.readSkillSelection()
print("Skill group/gem/part: "..pobinterface.skillString(prevSkill))

-- Update
print("Importing character changes...")
pobinterface.updateBuild()

-- Restore previously selected skill
print("After group/gem/part: "..pobinterface.skillString())
pobinterface.selectSkill(prevSkill)
print("Fixed group/gem/part: "..pobinterface.skillString())

testercore.saveBuild()
print("Success")
