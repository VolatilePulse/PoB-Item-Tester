@echo off

call test/_testsetup.bat

"%LUAJIT%" "%BASEDIR%\ItemTester\UpdateBuild.lua" "%BUILD%"
