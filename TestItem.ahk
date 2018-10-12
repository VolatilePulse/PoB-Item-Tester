#persistent
#SingleInstance, force

;--------------------------------------------------
; Initialization
;--------------------------------------------------

global LuaDir = "\ItemTester"
global BuildDir = "\Builds"

global SourceRepo = "https://raw.githubusercontent.com/VolatilePulse/PoB-Item-Tester/master/"
global SourceFiles = "TestItem.lua"

global IniFile = A_ScriptDir . "\TestItem.ini"
global LuaJIT = A_ScriptDir . "\bin\luajit.exe"

global PoBPath, CharacterFileName

global ItemViewerGUI, ItemViewerControl

GetPoBPath(PoBPath)
SetVariablesAndFiles()
GetCharacterFileName(CharacterFileName)

SplashTextOn, 200, 30, Initialization, Complete!
Sleep, 1000
SplashTextOff

;--------------------------------------------------
; Global Hooks
;--------------------------------------------------

OnClipboardChange("ClipboardChange")
OnExit("ExitFunc")

;--------------------------------------------------
; Functions
;--------------------------------------------------

GetPoBPath(ByRef PoBPath) {
    IniRead, PoBPath, %IniFile%, General, PathToPoB, %A_Space%

    If !PoBPath or !FileExist(PoBPath . "\Path of Building.exe") {
        SplashTextOn, 200, 30, Initialization, Please launch Path of Building.
        WinWait, Path of Building ahk_class SimpleGraphic Class, , 300
        WinGet, FullPath, ProcessPath, Path of Building ahk_class SimpleGraphic Class

        If !FullPath {
            MsgBox Path of Building not detected. Please relaunch this program and open Path of Building when requested
            ExitApp, 1
        }
        SplitPath, FullPath, , PoBPath
        IniWrite, %PoBPath%, %IniFile%, General, PathToPoB
    }
}

SetVariablesAndFiles() {
    SetWorkingDir, %PoBPath%
    EnvSet, LUA_PATH, %POBPATH%\lua\?.lua;%POBPATH%\ItemTester\?.lua

    LuaDir = %A_WorkingDir%%LuaDir%
    BuildDir = %A_WorkingDir%%BuildDir%

    ; Make sure our Lua Directory exists, otherwise create it.
    If FileExist(LuaDir) != "D"
        FileCreateDir, %LuaDir%

    SplashTextOn, 200, 30, Initialization, Updating helper files.
    Sleep, 500

    UrlDownloadToFile, %SourceRepo%%SourceFiles%, %LuaDir%\%SourceFiles%

    Gui, ItemViewerGUI:New, , PoB Item Tester
    Gui, ItemViewerGUI:Add, ActiveX, x0 y0 w400 h500 vItemViewerControl, Shell.Explorer
    ItemViewerControl.silent := true
}

GetCharacterFileName(ByRef CharacterFileName) {
    IniRead, CharacterFileName, %IniFile%, General, CharacterBuildFileName, %A_Space%

    If !CharacterFileName or !FileExist(BuildDir . "\" . CharacterFileName) {
        FileSelectFile, CharacterFileName, 3, %BuildDir%, Select Your Build File, Character Build File (*.xml)
        SplitPath, CharacterFileName, CharacterFileName
        if !CharacterFileName {
            MsgBox, You didn't select a Character file. Relaunch program to start again.
            ExitApp, 1
        }
    }

    IniWrite, %CharacterFileName%, %IniFile%, General, CharacterBuildFileName
}

ClipboardChange(ContentType) {
    If ContentType != 1
        Return

    ; Verify the information is what we're looking for
    If RegExMatch(clipboard, "Rarity: .*?\R.*?\R?.*?\R--------\R.*") = 0
        Return

    If !FileExist(BuildDir . "\" . CharacterFileName) {
        GetCharacterFileName(CharacterFileName)
    }

    SplashTextOn, 200, 30, PoB Item Tester, Parsing Item Data...
    ; Erase old content first
    FileDelete, %A_Temp%\PoBTestItem.txt
    FileAppend, %clipboard%, %A_Temp%\PoBTestItem.txt
    
    RunWait, "%LuaJIT%" "%LuaDir%\TestItem.lua" "%BuildDir%\%CharacterFileName%" "%A_Temp%\PoBTestItem.txt", , Hide

    SplashTextOff

    DisplayOutput()
}

DisplayOutput() {
    ItemViewerControl.Navigate("file://" . A_Temp . "\PoBTestItem.txt.html")
    while ItemViewerControl.busy or ItemViewerControl.ReadyState != 4
        Sleep 10
    Gui, ItemViewerGUI:Show, w400 h500
    return
}

; Clean up temporary files, if able to
ExitFunc() {
    FileDelete, %A_Temp%\PoBTestItem.txt
    FileDelete, %A_Temp%\PoBTestItem.txt.html
    return
}

/* 
;--------------------------------------------------
; Window Detection
;--------------------------------------------------

; Path of Exile Window
GetPoEID(PoEID)
GetPoBID(PoBID)

;ToolTip, %PoEID%`n%PoBID%

; Path of Building Window
If !PoEID
{
    ; MsgBox Please open Path of Exile before continuing.
}

If !PoBID
{
    ; MsgBox Please open Path of Building before continuing.
}

;--------------------------------------------------
; Hotkeys
;--------------------------------------------------

; CTRL + Shift + `
^+`::
MouseGetPos, , , winID
GetPoEID(PoEID)

; Window under cursor is PoE
IfEqual, winID, %PoEID%
{
    WinActivate, ahk_id %id%
    MsgBox PoE was detected
}

; Window was not PoE
Else
{
    MsgBox PoE was not detected
}

;--------------------------------------------------
; Functions
;--------------------------------------------------

GetPoEID(ByRef PoEID) {
    If !PoEID Or !WinExist("ahk_id " . %PoEID%)
        WinGet, PoEID, ID, Path of Exile ahk_class POEWindowClass
}

GetPoBID(ByRef PoBID) {
    If !PoBID Or !WinExist("ahk_id " . %PoBID%)
        WinGet, PoBID, ID, Path of Building ahk_class SimpleGraphic Class
} */