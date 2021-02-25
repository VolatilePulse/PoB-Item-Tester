REM This callable batch file simply reads TestItem.ini and sets up the environment needed to run the Lua files.

set BASEDIR=%CD%

REM Ini reading
for /F "tokens=1,2 delims==" %%A IN ('"type %BASEDIR%\TestItem.ini"') do set "%%A=%%B"
if "%CharacterBuildFileName%"==CURRENT (
    set BUILD=CURRENT
) else (
    set "BUILD=%BuildDirectory%\%CharacterBuildFileName%"
)

REM Get Documents folder
for /F "tokens=3" %%G IN ('REG QUERY "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Personal"') do set "POB_USERPATH=%%G"

REM Set up the environment
set "PATH=%PathToPoBInstall%;%PATH%"
set "LUA_PATH=%BASEDIR%\ItemTester\?.lua;%PathToPoB%\lua\?.lua;%PathToPoBInstall%\lua\?.lua"
set "LUA_CPATH=%PathToPoBInstall%\?.dll"
set "LUAJIT=%BASEDIR%\bin\luajit.exe"
set "POB_SCRIPTPATH=%PathToPoB%"
set "POB_RUNTIMEPATH=%PathToPoBInstall%"
cd /d %PathToPoB%
