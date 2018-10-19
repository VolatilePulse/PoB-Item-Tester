@echo off
set BASEDIR=%CD%
set POBPATH=D:\Programs\PathOfBuilding
set LUAJIT=%BASEDIR%\bin\luajit.exe

echo Config...
echo Base : %BASEDIR%
echo POB  : %POBPATH%

set LUA_PATH=%POBPATH%\lua\?.lua;%POBPATH%\ItemTester\?.lua

echo:
echo Running script...

cd %POBPATH%
REM "%LUAJIT%" ItemTester\UpdateBuild.lua "%POBPATH%\Builds\VolatileLightning.xml"
REM "%LUAJIT%" ItemTester\UpdateBuild.lua "%POBPATH%\Builds\Zamhi.xml"
"%LUAJIT%" ItemTester\UpdateBuild.lua "%POBPATH%\Builds\Zivhi.xml"
