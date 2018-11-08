#persistent
#SingleInstance, force

;--------------------------------------------------
; Initialization
;--------------------------------------------------

global LuaDir = "\ItemTester"
global BuildDir = "\Builds"

global IniFile = A_ScriptDir . "\TestItem.ini"
global LuaJIT = A_ScriptDir . "\bin\luajit.exe"

global PoBPath, CharacterFileName

global InfoWindowGUI, InfoTextCtrl, InfoWindowHwnd
global CharacterPickerGUI, CharacterCurrentCtrl, CharacterListCtrl, CharacterUpdateCtrl, CharacterChangeCtrl, CharacterPickerHwnd
global ItemViewerGUI, ItemViewerCtrl, ItemViewerHwnd

DetectHiddenWindows, On

CreateGUI()
SetVariablesAndFiles()

DisplayInformation("Complete!")
Sleep, 1000
DisplayInformation()

; Register the function to call on script exit
OnExit("ExitFunc")
return

;--------------------------------------------------
; Global Hooks
;--------------------------------------------------

CPCurrentCheck:
    GuiControlGet, isChecked, , CharacterCurrentCtrl
    if (isChecked)
        GuiControl, CharacterPickerGUI: +Disabled, CharacterListCtrl
    else
        GuiControl, CharacterPickerGUI: -Disabled, CharacterListCtrl
    return

CPListBox:
    if (A_GuiControlEvent = "DoubleClick")
        Gui, Submit
    return

Ok:
    Gui, Submit
    return

; Re-import build (update)
+^u::
    UpdateCharacterBuild()
    return

; Test item from clipboard
^#c::
    Item := GetItemFromClipboard()
    if (Item) {
        TestItemFromClipboard(Item)
    }
    return

; Test item fom clipboard with character picker
^#!c::
    Item := GetItemFromClipboard()
    if (Item) {
        filename := DisplayCharacterPicker(True)
        if (filename) {
            TestItemFromClipboard(Item, filename)
        }
    }
    return

; Generate DPS search
^#d::
    GenerateDPSSearch()
    return

; Generate DPS search with character picker
^#!d::
    filename := DisplayCharacterPicker(True)
    if (filename) GenerateDPSSearch(filename)
    return

;--------------------------------------------------
; Functions
;--------------------------------------------------

; Defines GUI layouts and forces Windows to render the GUI layouts
CreateGUI() {
    ; Information Window
    Gui, InfoWindowGUI:New, +AlwaysOnTop -Border -MaximizeBox -MinimizeBox +LastFound +Disabled +HwndInfoWindowHwnd
    Gui, InfoWindowGUI:Add, Text, vInfoTextCtrl Center, Please launch Path of Building ; Default control width
    Gui, InfoWindowGUI:Show, NoActivate Hide

    ; Character Picker
    Gui, CharacterPickerGUI:New, +HwndCharacterPickerHwnd, Pick You Character Build File
    ;Gui, CharacterPickerGUI:Margin, 20, 20
    Gui, CharacterPickerGUI:Add, Checkbox, vCharacterCurrentCtrl gCPCurrentCheck, Use PoB's last used build (since it last closed)
    Gui, Font, s16
    Gui, CharacterPickerGUI:Add, ListBox, vCharacterListCtrl gCPListBox r5, %CharacterFileName%
    Gui, Font, s10
    Gui, CharacterPickerGUI:Add, Checkbox, vCharacterUpdateCtrl, Update Build before continuing
    Gui, CharacterPickerGUI:Add, Checkbox, vCharacterChangeCtrl Checked, Make this the default Build
    Gui, CharacterPickerGUI:Add, Button, Default w50 gOK, OK
    Gui, CharacterPickerGUI:Show, NoActivate Hide

    ; Item Viewer
    Gui, ItemViewerGUI:New, +AlwaysOnTop +HwndItemViewerHwnd, PoB Item Tester
    Gui, ItemViewerGUI:Add, ActiveX, x0 y0 w400 h500 vItemViewerCtrl, Shell.Explorer
    ItemViewerCtrl.silent := True
    Gui, ItemViewerGUI:Show, NoActivate Hide
}

SetVariablesAndFiles() {
    IniRead, PoBPath, %IniFile%, General, PathToPoB, %A_Space%
    IniRead, CharacterFileName, %IniFile%, General, CharacterBuildFileName, %A_Space%

    ; Make sure PoB hasn't moved
    GetPoBPath()

    SetWorkingDir, %PoBPath%

    LuaDir = %A_ScriptDir%%LuaDir%
    BuildDir = %A_WorkingDir%%BuildDir%
    EnvSet, LUA_PATH, %POBPATH%\lua\?.lua;%LuaDir%\?.lua

    ; Make sure the Character file still exists
    if (CharacterFileName <> "CURRENT" and !(CharacterFileName and FileExist(BuildDir . "\" . CharacterFileName))) {
        if (!DisplayCharacterPicker(False)) {
            MsgBox, You didn't make a selection. The script will now exit.
            ExitApp, 1
        }
    }
}

GetPoBPath() {
    if !PoBPath or !FileExist(PoBPath . "\Path of Building.exe") {
        if (!WinExist("Path of Building ahk_class SimpleGraphic Class"))
            DisplayInformation("Please launch Path of Building")
        WinWait, Path of Building ahk_class SimpleGraphic Class, , 300
        WinGet, FullPath, ProcessPath, Path of Building ahk_class SimpleGraphic Class

        if !FullPath {
            MsgBox Path of Building not detected. Please relaunch this program and open Path of Building when requested
            ExitApp, 1
        }
        ; Get the PoB Directory from the PoB Path
        SplitPath, FullPath, , PoBPath
        IniWrite, %PoBPath%, %IniFile%, General, PathToPoB
        Gui, InforWindowGUI:Hide
    }
}

GetItemFromClipboard() {
    ; Verify the information is what we're looking for
    if RegExMatch(clipboard, "Rarity: .*?\R.*?\R?.*?\R--------\R.*") = 0 {
        MsgBox "Not a PoE item"
        return False
    }
    return clipboard
}

TestItemFromClipboard(Item, FileName := False) {
    ; If parameter is omitted, use the stored file name
    FileName := FileName ? FileName : CharacterFileName

    DisplayInformation("Parsing Item Data...")
    ; Erase old content first
    FileDelete, %A_Temp%\PoBTestItem.txt
    FileDelete, %A_Temp%\PoBTestItem.txt.html
    FileAppend, %Item%, %A_Temp%\PoBTestItem.txt

    if (FileName <> "CURRENT")
        FileName = % BuildDir . "\" . FileName

    RunWait, "%LuaJIT%" "%LuaDir%\TestItem.lua" "%FileName%" "%A_Temp%\PoBTestItem.txt", , Hide
    DisplayInformation()
    DisplayOutput()
}

GenerateDPSSearch(FileName := False) {
    ; If parameter is omitted, use the stored file name
    FileName := FileName ? FileName : CharacterFileName

    if (FileName <> "CURRENT")
        FileName = % BuildDir . "\" . FileName
    DisplayInformation("Generating DPS search...")
    RunWait, "%LuaJIT%" "%LuaDir%\SearchDPS.lua" "%FileName%", , Hide
    DisplayInformation()
}

UpdateCharacterBuild(FileName := False) {
    ; If parameter is omitted, use the stored file name
    FileName := FileName ? FileName : CharacterFileName

    if (FileName <> "CURRENT")
        FileName = % BuildDir . "\" . FileName

    DisplayInformation("Updating Character Build")
    RunWait, "%LuaJIT%" "%LuaDir%\UpdateBuild.lua" "%FileName%", , Hide
    DisplayInformation()
}

SaveCharacterFile(NewFileName) {
    CharacterFileName = %NewFileName%
    IniWrite, %NewFileName%, %IniFile%, General, CharacterBuildFileName
}

;--------------------------------------------------
; GUI Display Functions
;--------------------------------------------------
DisplayInformation(string := "") {
    ; Hide the Information Window
    if (!string) {
        Gui, InfoWindowGUI:Hide
        return
    }

    GuiControl, InfoWindowGUI:Text, InfoTextCtrl, %string%

    WinGetPos, winX, winY, winW, winH, A
    WinGetPos, , , guiW, guiH, ahk_id %InfoWindowHwnd%
    posX = % winX + (winW - guiW) / 2
    posY = % winY + 50
    Gui, InfoWindowGUI:Show, X%posX% Y%posY% NoActivate
}

DisplayCharacterPicker(allowTemp) {
    ListEntries =
    ; Does not support folders in the Builds Directory
    loop Files, %BuildDir%\*.xml
    {
        SplitPath, A_LoopFileName, , , , CBFileName
        ListEntries = %ListEntries%|%CBFileName%
    }

    GuiControl, CharacterPickerGUI:Text, CharacterListCtrl, %ListEntries%

    if (allowTemp)
        GuiControl, CharacterPickerGUI:-Disabled, CharacterChangeCtrl
    else
        GuiControl, CharacterPickerGUI:+Disabled, CharacterChangeCtrl

    ; Move CharacterPicker to the center of the currently active window
    WinGetPos, winX, winY, winW, winH, A
    WinGetPos, , , guiW, guiH, ahk_id %CharacterPickerHwnd%
    posX = % winX + (winW - guiW) / 2
    posY = % winY + (winH - guiH) / 2
    Gui, CharacterPickerGUI:Show, X%posX% Y%posY%

    DetectHiddenWindows, Off
    WinWait, ahk_id %CharacterPickerHwnd%
    WinWaitClose, ahk_id %CharacterPickerHwnd%
    DetectHiddenWindows, On

    ; Set the Value to "CURRENT" instead of a specific path name
    if (CharacterCurrentCtrl)
        CharacterListCtrl = CURRENT
    ; Ignores bypassing a selection
    else if (CharacterListCtrl)
        CharacterListCtrl = % CharacterListCtrl . ".xml"
    else {
        return False
    }

    ; Update the build before continuing
    if (CharacterUpdateCtrl)
        UpdateCharacterBuild(CharacterListCtrl)

    ; Update the INI with the changes
    if (CharacterChangeCtrl)
        SaveCharacterFile(CharacterListCtrl)

    return CharacterListCtrl
}

DisplayOutput() {
    if (!FileExist(A_Temp . "\PoBTestItem.txt.html")) {
        MsgBox, Item type is not supported.
        return
    }

    ItemViewerCtrl.Navigate("file://" . A_Temp . "\PoBTestItem.txt.html")
    while ItemViewerCtrl.busy or ItemViewerCtrl.ReadyState != 4
        Sleep 10
    WinGetPos, winX, winY, winW, winH, A
    Gui, ItemViewerGUI:+LastFound
    WinGetPos, , , guiW, guiH, ahk_id %ItemViewerHwnd%
    MouseGetPos, mouseX, mouseY
    posX = % ((mouseX > (winX + winW / 2)) ? (winX + winW * 0.25 - guiW * 0.5) : (winX + winW * 0.75 - guiW * 0.5))
    posY = % ((mouseY > (winY + winH / 2)) ? (winY + winH * 0.25 - guiH * 0.5) : (winY + winH * 0.75 - guiH * 0.5))
    Gui, ItemViewerGUI:Show, w400 h500 X%posX% Y%posY% NoActivate
}

ExitFunc() {
    ; Clean up temporary files, if able to
    FileDelete, %A_Temp%\PoBTestItem.txt
    FileDelete, %A_Temp%\PoBTestItem.txt.html
}
