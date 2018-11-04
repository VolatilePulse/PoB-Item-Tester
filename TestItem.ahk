#persistent
#SingleInstance, force

;--------------------------------------------------
; Initialization
;--------------------------------------------------

global LuaDir = "\ItemTester"
global BuildDir = "\Builds"

global SourceRepo = "https://raw.githubusercontent.com/VolatilePulse/PoB-Item-Tester/master/ItemTester/"
global SourceFiles = ["TestItem.lua", "mockui.lua", "inspect.lua", "UpdateBuild.lua"]

global IniFile = A_ScriptDir . "\TestItem.ini"
global LuaJIT = A_ScriptDir . "\bin\luajit.exe"

global DevMode = True, PoBPath, CharacterFileName

global ItemViewerGUI, ItemViewerControl

DetectHiddenWindows, On

GetDevMode(DevMode)
GetPoBPath(PoBPath)
SetVariablesAndFiles()
GetCharacterFileName(CharacterFileName)

InfoHwnd := DisplayInformation("Complete!")
Sleep, 1000
Gui, %InfoHwnd%:Destroy

; OnClipboardChange("ClipboardChange")
OnExit("ExitFunc")
return

;--------------------------------------------------
; Global Hooks
;--------------------------------------------------

CPListBox:
    if A_GuiControlEvent <> DoubleClick
        return
    Gui, Submit
    Gui, Destroy

Ok:
    Gui, Submit
    Gui, Destroy

Cancel:
    Gui, Destroy

; Re-import build (update)
+^u::
    InfoHwnd := DisplayInformation("Updating Character Build")
    RunWait, "%LuaJIT%" "%LuaDir%\UpdateBuild.lua" "%BuildDir%\%CharacterFileName%", , Hide
    Gui, %InfoHwnd%:Destroy
    return

; Test item from clipboard
^#c::
    TestItemFromClipboard(false)
    return

; Test item fom clipboard with character picker
^#!c::
    TestItemFromClipboard(true)
    return


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
        InfoHwnd := DisplayInformation("Please launch Path of Building")
        WinWait, Path of Building ahk_class SimpleGraphic Class, , 300
        WinGet, FullPath, ProcessPath, Path of Building ahk_class SimpleGraphic Class

        If !FullPath {
            MsgBox Path of Building not detected. Please relaunch this program and open Path of Building when requested
            ExitApp, 1
        }
        SplitPath, FullPath, , PoBPath
        IniWrite, %PoBPath%, %IniFile%, General, PathToPoB
        Gui, %InfoHwnd%:Destroy
    }
}

SetVariablesAndFiles() {
    SetWorkingDir, %PoBPath%

    LuaDir = %A_ScriptDir%%LuaDir%
    BuildDir = %A_WorkingDir%%BuildDir%

    EnvSet, LUA_PATH, %POBPATH%\lua\?.lua;%LuaDir%\?.lua

    If !DevMode {
        ; Make sure our Lua Directory exists, otherwise create it.
        If FileExist(LuaDir) != "D"
            FileCreateDir, %LuaDir%

        InfoHwnd := DisplayInformation("Updating helper files")
        Sleep, 500

        for index, file in SourceFiles
            UrlDownloadToFile, %SourceRepo%%file%, %LuaDir%\%file%

        Gui, %InfoHwnd%:Destroy
    }

    Gui, ItemViewerGUI:New, +AlwaysOnTop, PoB Item Tester
    Gui, ItemViewerGUI:Add, ActiveX, x0 y0 w400 h500 vItemViewerControl, Shell.Explorer
    ItemViewerControl.silent := true
}

GetCharacterFileName(ByRef CharacterFileName, force:=false) {
    if !force {
        IniRead, CharacterFileName, %IniFile%, General, CharacterBuildFileName, %A_Space%
    }

    If force or !CharacterFileName or !FileExist(BuildDir . "\" . CharacterFileName) {
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

        Gui, CharacterPicker:New, +HwndCharacterPickerHwnd, Pick You Character Build File
        Gui, CharacterPicker:Margin, 20, 20
        Gui, Font, s16
        Gui, CharacterPicker:Add, ListBox, vCharacterFileName gCPListBox r%entries%, %CharacterFileName%
        Gui, Font, s10
        Gui, CharacterPicker:Add, Button, Default gOk, Confirm
        Gui, CharacterPicker:Add, Button, X+50 gCancel, Cancel
        Gui, CharacterPicker:Show

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

TestItemFromClipboard(showPicker) {
    ; Verify the information is what we're looking for
    If RegExMatch(clipboard, "Rarity: .*?\R.*?\R?.*?\R--------\R.*") = 0 {
        MsgBox "Not a PoE item"
        Return
    }

    If showPicker || !FileExist(BuildDir . "\" . CharacterFileName) {
        GetCharacterFileName(CharacterFileName, true)
    }

    InfoHwnd := DisplayInformation("Parsing Item Data...")
    ; Erase old content first
    FileDelete, %A_Temp%\PoBTestItem.txt
    FileAppend, %clipboard%, %A_Temp%\PoBTestItem.txt

    RunWait, "%LuaJIT%" "%LuaDir%\TestItem.lua" "%BuildDir%\%CharacterFileName%" "%A_Temp%\PoBTestItem.txt", , Hide
    Gui, %InfoHwnd%:Destroy
    DisplayOutput()

}

ClipboardChange(ContentType) {
    If ContentType != 1
        Return

    TestItemFromClipboard(false)
}

DisplayOutput() {
    ItemViewerControl.Navigate("file://" . A_Temp . "\PoBTestItem.txt.html")
    while ItemViewerControl.busy or ItemViewerControl.ReadyState != 4
        Sleep 10
    WinGetPos, winX, winY, winW, winH, A
    Gui, ItemViewerGUI:+LastFound
    Gui, ItemViewerGUI:Show, Hide NoActivate
    WinGetPos, , , guiW, guiH
    MouseGetPos, mouseX, mouseY
    posX = % ((mouseX > winX + winW / 2) ? (winX + ((winW / 2) - guiW) / 2) : (winX + ((winW / 2) + guiW) / 2))
    posY = % ((mouseY > winY + winH / 2) ? (winY + ((winH / 2) - guiH) / 2) : (winY + ((winY / 2) + guiH) / 2))
    Gui, ItemViewerGUI:Show, w400 h500 X%posX% Y%posY% NoActivate
    return
}

DisplayInformation(string) {
    WinGetPos, winX, winY, winW, winH, A
    Gui, Info:New, +AlwaysOnTop -Border -MaximizeBox -MinimizeBox +LastFound +Disabled HwndInfoHwnd
    Gui, Info:Add, Text, , %string%
    Gui, Info:Show, Hide NoActivate
    WinGetPos, , , guiW, guiH
    posX = % winX + (winW - guiW) / 2
    posY = % winY + 50
    Gui, Info:Show, X%posX% Y%posY% NoActivate
    return InfoHwnd
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
