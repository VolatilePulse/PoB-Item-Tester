@echo off
set BASEDIR=%CD%
set POBPATH=D:\Programs\PathOfBuilding
set LUAJIT=%BASEDIR%\bin\luajit.exe

echo Config...
echo Base : %BASEDIR%
echo POB  : %POBPATH%

set LUA_PATH=%POBPATH%\lua\?.lua;%POBPATH%\ItemTester\?.lua

echo:
echo Copying scripts...
xcopy /YQ ItemTester %POBPATH%\ItemTester\ >NUL

echo:
echo Running script...

cd %POBPATH%
"%LUAJIT%" ItemTester\SearchDPS.lua "%POBPATH%\Builds\Zivhi.xml"
