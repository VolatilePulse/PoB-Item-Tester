@echo off

call _testsetup.bat

"%LUAJIT%" %BASEDIR%\ItemTester\UpdateBuild.lua %BUILD%
