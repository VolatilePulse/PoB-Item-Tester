@echo off
set BASEDIR=%CD%
REM Default path for the Installed version
REM set POBPATH=C:\ProgramData\Path of Building
set POBPATH=D:\Programs\PathOfBuilding
set POBINSTALL=D:\Programs\PathOfBuilding
set LUAJIT=%BASEDIR%\bin\luajit.exe

echo Config...
echo Base        : %BASEDIR%
echo POB Install : %POBINSTALL%
echo POB Data    : %POBPATH%

set PATH=%POBINSTALL%;%PATH%
set LUA_PATH=%BASEDIR%\ItemTester\?.lua;%POBPATH%\lua\?.lua;%POBINSTALL%\lua\?.lua
set LUA_CPATH=%POBINSTALL%\?.dll

echo:
echo Running script...

cd /d %POBPATH%
"%LUAJIT%" %BASEDIR%\ItemTester\UpdateBuild.lua CURRENT
