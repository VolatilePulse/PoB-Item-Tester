#persistent
#SingleInstance, force

;--------------------------------------------------
; Initialization
;--------------------------------------------------

global LuaDir = "\ItemTester"
global BuildDir = "\Builds"

global SourceRepo = "https://raw.githubusercontent.com/VolatilePulse/PoB-Item-Tester/master/ItemTester/"
global SourceFiles = ["TestItem.lua", "mockui.lua", "inspect.lua"]

global IniFile = A_ScriptDir . "\TestItem.ini"
global LuaJIT = A_ScriptDir . "\bin\luajit.exe"

global DevMode = True, PoBPath, CharacterFileName

global ItemViewerGUI, ItemViewerControl

CoordMode, Tooltip, Client

GetDevMode(DevMode)
GetPoBPath(PoBPath)
SetVariablesAndFiles()
GetCharacterFileName(CharacterFileName)

winGetActiveStats, winTitle, winWidth, winHeight, winX, winY
Tooltip, Complete!, (winWidth - 68) / 2, 0, 1 ; 68 x 20h

Sleep, 1000
Tooltip, , , , 1

;--------------------------------------------------
; Global Hooks
;--------------------------------------------------

OnClipboardChange("ClipboardChange")
OnExit("ExitFunc")

CPListBox:
    if A_GuiControlEvent <> DoubleClick
        return
    Gui, Submit

Ok:
    Gui, Submit

Cancel:
    Gui, Hide

;--------------------------------------------------
; Functions
;--------------------------------------------------

GetDevMode(ByRef DevMode) {
    IniRead, DevMode, %IniFile%, General, EnableDevMode, %DevMode%
    If DevMode
        IniWrite, %DevMode%, %IniFile%, General, EnableDevMode
}

GetPoBPath(ByRef PoBPath) {
    IniRead, PoBPath, %IniFile%, General, PathToPoB, %A_Space%

    If !PoBPath or !FileExist(PoBPath . "\Path of Building.exe") {
        winGetActiveStats, winTitle, winWidth, winHeight, winX, winY
        Tooltip, Please launch Path of Building, (winWidth - 173) / 2, 0, 1 ; 173w x 20h
        WinWait, Path of Building ahk_class SimpleGraphic Class, , 300
        WinGet, FullPath, ProcessPath, Path of Building ahk_class SimpleGraphic Class

        If !FullPath {
            MsgBox Path of Building not detected. Please relaunch this program and open Path of Building when requested
            ExitApp, 1
        }
        SplitPath, FullPath, , PoBPath
        IniWrite, %PoBPath%, %IniFile%, General, PathToPoB
        Tooltip, , , , 1
    }
}

SetVariablesAndFiles() {
    SetWorkingDir, %PoBPath%
    EnvSet, LUA_PATH, %POBPATH%\lua\?.lua;%POBPATH%\ItemTester\?.lua

    LuaDir = %A_WorkingDir%%LuaDir%
    BuildDir = %A_WorkingDir%%BuildDir%

    If !DevMode {
        ; Make sure our Lua Directory exists, otherwise create it.
        If FileExist(LuaDir) != "D"
            FileCreateDir, %LuaDir%

        winGetActiveStats, winTitle, winWidth, winHeight, winX, winY
        Tooltip, Updating helper files, (winWidth - 122) / 2, 0, 1 ; 122w x 20h
        Sleep, 500

        for index, file in SourceFiles
            UrlDownloadToFile, %SourceRepo%%file%, %LuaDir%\%file%
        
        Tooltip, , , , 1
    }

    Gui, ItemViewerGUI:New, , PoB Item Tester
    Gui, ItemViewerGUI:Add, ActiveX, x0 y0 w400 h500 vItemViewerControl, Shell.Explorer
    ItemViewerControl.silent := true
}

GetCharacterFileName(ByRef CharacterFileName) {
    IniRead, CharacterFileName, %IniFile%, General, CharacterBuildFileName, %A_Space%

    If !CharacterFileName or !FileExist(BuildDir . "\" . CharacterFileName) {

        entries = 0
        loop Files, %BuildDir%\*.xml
        {
            entries ++
            SplitPath, A_LoopFileName, , , , CBFileName
            if A_Index != 1
                CharacterFileName = %CharacterFileName%|%CBFileName%
            else
                CharacterFileName = %CBFileName%
        }

        Gui, CharacterPicker:New, +HwndCharacterPickerHwnd -Border -Caption
        ;Gui, CharacterPicker:Color, 828282
        Gui, CharacterPicker:Margin, 20, 20
        Gui, Font, s16
        Gui, CharacterPicker:Add, ListBox, vCharacterFileName gCPListBox r%entries%, %CharacterFileName%
        Gui, Font, s10
        Gui, CharacterPicker:Add, Button, Default gOk, Confirm
        Gui, CharacterPicker:Add, Button, X+50 gCancel, Cancel
        Gui, CharacterPicker:Show

        winGetActiveStats, winTitle, winWidth, winHeight, winX, winY
        Tooltip, Pick Your Character Build, (winWidth - 122) / 2, 0, 1 ; 122w x 20h

        WinWait, ahk_id %CharacterPickerHwnd%
        WinWaitClose, ahk_id %CharacterPickerHwnd%
        
        if !CharacterFileName or !FileExist(BuildDir . "\" . CharacterFileName . ".xml"){
            MsgBox, You didn't select a Character file. Relaunch program to start again.
            ExitApp, 1
        }

        CharacterFileName = %CharacterFileName%.xml

        IniWrite, %CharacterFileName%, %IniFile%, General, CharacterBuildFileName
    }
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

    winGetActiveStats, winTitle, winWidth, winHeight, winX, winY
    Tooltip, Parsing Item Data..., (winWidth - 115) / 2, 0, 1 ; 115w x 20h
    ; Erase old content first
    FileDelete, %A_Temp%\PoBTestItem.txt
    FileAppend, %clipboard%, %A_Temp%\PoBTestItem.txt
    
    RunWait, "%LuaJIT%" "%LuaDir%\TestItem.lua" "%BuildDir%\%CharacterFileName%" "%A_Temp%\PoBTestItem.txt", , Hide

    Tooltip, , , , 1

    DisplayOutput()
}

EnterAccountName() {
    
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

UrlEncode(String) {
	OldFormat := A_FormatInteger
	SetFormat, Integer, H

	Loop, Parse, String {
		if A_LoopField is alnum {
			Out .= A_LoopField
			continue
		}
		Hex := SubStr(Asc(A_LoopField), 3)
		Out .= "%" . (StrLen(Hex) = 1 ? "0" . Hex : Hex)
	}

	SetFormat, Integer, %OldFormat%

	return Out
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