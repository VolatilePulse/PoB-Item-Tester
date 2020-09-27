@echo off
SETLOCAL EnableDelayedExpansion

set BASEDIR=%CD%
for /F "tokens=1,2 delims==" %%A IN ('"type %BASEDIR%\TestItem.ini"') do set "%%A=%%B"
if %CharacterBuildFileName%==CURRENT (
    set BUILD=CURRENT
) else (
    set "BUILD=%BuildDirectory%\%CharacterBuildFileName%"
)

set PATH=%PathToPoBInstall%;%PATH%
set LUA_PATH=%BASEDIR%\ItemTester\?.lua;%PathToPoB%\lua\?.lua;%PathToPoBInstall%\lua\?.lua
set LUA_CPATH=%PathToPoBInstall%\?.dll
set LUAJIT=%BASEDIR%\bin\luajit.exe
cd /d %PathToPoB%

"%LUAJIT%" %BASEDIR%\ItemTester\SearchDPS.lua %BUILD%

REM Add OPTIONS on the end to get skill damage stat options
