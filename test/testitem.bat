@echo off

call test/_testsetup.bat

"%LUAJIT%" "%BASEDIR%\ItemTester\TestItem.lua" "%BUILD%" "%BASEDIR%\test\testitems\ring.txt"
