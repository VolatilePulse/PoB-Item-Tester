@echo off

call _testsetup.bat

"%LUAJIT%" "%BASEDIR%\ItemTester\TestItem.lua" "%BUILD%" "%BASEDIR%\testitems\ring.txt"
