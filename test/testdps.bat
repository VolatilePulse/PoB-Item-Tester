@echo off

call test/_testsetup.bat

"%LUAJIT%" "%BASEDIR%\ItemTester\SearchDPS.lua" "%BUILD%"

REM Add OPTIONS on the end to get skill damage stat options
