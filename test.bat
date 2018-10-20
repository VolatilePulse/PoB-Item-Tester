@echo off
set BASEDIR=%CD%
set POBPATH=D:\Programs\PathOfBuilding
set LUAJIT=%BASEDIR%\bin\luajit.exe

echo Config...
echo Base : %BASEDIR%
echo POB  : %POBPATH%

set LUA_PATH=%POBPATH%\lua\?.lua;%BASEDIR%\ItemTester\?.lua

echo:
echo Running script...

cd %POBPATH%
"%LUAJIT%" %BASEDIR%\ItemTester\TestItem.lua CURRENT "%BASEDIR%\testitems\ring.txt"
