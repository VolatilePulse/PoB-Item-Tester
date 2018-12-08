#NoEnv
#persistent
#SingleInstance, force

;#Warn

;--------------------------------------------------
; Initialization
;--------------------------------------------------

global LuaDir = "\ItemTester"

global IniFile = A_ScriptDir . "\TestItem.ini"
global LuaJIT = A_ScriptDir . "\bin\luajit.exe"

global PoBPath, CharacterFileName, BuildDir

global InfoWindowGUI, InfoTextCtrl, InfoWindowHwnd
global CharacterPickerGUI, CharacterCurrentCtrl, CharacterTVCtrl
global CharacterUpdateCtrl, CharacterChangeCtrl, CharacterPickerHwnd
global CharacterDirectoryText, CharacterOKBtn
global ItemViewerGUI, ItemViewerCtrl, ItemViewerHwnd
global _GUIOK := false

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
    if (isChecked) {
        GuiControl, CharacterPickerGUI: +Disabled, CharacterTVCtrl
        GuiControl, CharacterPickerGUI: -Disabled +Default, CharacterOKBtn
    }
    else {
        GuiControl, CharacterPickerGUI: -Disabled, CharacterTVCtrl
        if (TV_GetChild(TV_GetSelection()))
            GuiControl, CharacterPickerGUI: -Default +Disabled, CharacterOKBtn
    }
    return

CPTV:
    if ((A_GuiEvent != "S") || (!TV_GetText(_, A_EventInfo)))
        return

    ; A character file has been selected
    if (!TV_GetChild(A_EventInfo)) {
        GuiControl, CharacterPickerGUI: +Default -Disabled, CharacterOKBtn
    }
    else
        GuiControl, CharacterPickerGUI: -Default +Disabled, CharacterOKBtn
    return

ChangeDir:
    CreateTV(GetBuildDir())
    return

Ok:
    _GUIOK := true
    Gui, Submit
    return

; Re-import build (update)
+^u::
    UpdateCharacterBuild()
    return

; Test item from clipboard
^#c::
    Item := GetItemFromClipboard()
    if (Item)
        TestItemFromClipboard((CharacterFileName == "CURRENT") ? "CURRENT" : BuildDir "\" CharacterFileName, Item)
    return

; Test item fom clipboard with character picker
^#!c::
    Item := GetItemFromClipboard()
    if (Item) {
        filename := DisplayCharacterPicker()
        if (filename)
            TestItemFromClipboard(Item, filename)
    }
    return

; Generate DPS search
^#d::
    GenerateDPSSearch((CharacterFileName == "CURRENT") ? "CURRENT" : BuildDir "\" CharacterFileName)
    return

; Generate DPS search with character picker
^#!d::
    filename := DisplayCharacterPicker()
    if (filename)
        GenerateDPSSearch(filename)
    return

;--------------------------------------------------
; Functions
;--------------------------------------------------

; Defines GUI layouts and forces Windows to render the GUI layouts
CreateGUI() {
    ; Create an ImageList for the TreeView
    ImageListID := IL_Create(5)
    loop 5
        IL_Add(ImageListID, "shell32.dll", A_Index)

    ; Information Window
    Gui, InfoWindowGUI:New, +AlwaysOnTop -Border -MaximizeBox -MinimizeBox +LastFound +Disabled +HwndInfoWindowHwnd
    Gui, InfoWindowGUI:Add, Text, vInfoTextCtrl Center, Please select Character Build Directory ; Default control width
    Gui, InfoWindowGUI:Show, NoActivate Hide

    ; Character Picker
    Gui, CharacterPickerGUI:New, +HwndCharacterPickerHwnd -MaximizeBox -MinimizeBox, Pick You Character Build File
    Gui, CharacterPickerGUI:Margin, 8, 8
    Gui, CharacterPickerGUI:Add, Checkbox, vCharacterCurrentCtrl gCPCurrentCheck, Use PoB's last used build (since it last closed)
    Gui, CharacterPickerGUI:Add, Button, gChangeDir, Change
    Gui, CharacterPickerGUI:Add, Text, vCharacterDirectoryText x+5 ym+27 w300, Build Directory

    Gui, CharacterPickerGUI:Add, TreeView, vCharacterTVCtrl gCPTV w300 r20 xm ImageList%ImageListID%
    Gui, CharacterPickerGUI:Add, Checkbox, vCharacterUpdateCtrl, Update Build before continuing
    Gui, CharacterPickerGUI:Add, Checkbox, vCharacterChangeCtrl Checked, Make this the default Build
    Gui, CharacterPickerGUI:Add, Button, vCharacterOKBtn Default w50 gOK, OK
    Gui, CharacterPickerGUI:Show, NoActivate Hide

    ; Item Viewer
    Gui, ItemViewerGUI:New, +AlwaysOnTop +HwndItemViewerHwnd, PoB Item Tester
    Gui, ItemViewerGUI:Add, ActiveX, x0 y0 w400 h500 vItemViewerCtrl, Shell.Explorer
    ItemViewerCtrl.silent := True
    Gui, ItemViewerGUI:Show, NoActivate Hide
}

SetVariablesAndFiles() {
    IniRead, PoBPath, %IniFile%, General, PathToPoB, %A_Space%
    IniRead, BuildDir, %IniFile%, General, BuildDirectory, %A_Space%
    IniRead, CharacterFileName, %IniFile%, General, CharacterBuildFileName, %A_Space%

    ; Make sure PoB hasn't moved
    GetPoBPath()
    SaveBuildDirectory(GetBuildDir(false))

    SetWorkingDir, %PoBPath%

    LuaDir = %A_ScriptDir%%LuaDir%
    EnvSet, LUA_PATH, %POBPATH%\lua\?.lua;%LuaDir%\?.lua

    ; Make sure the Character file still exists
    if (CharacterFileName <> "CURRENT" and !(CharacterFileName and FileExist(BuildDir . "\" . CharacterFileName))) {
        if (!DisplayCharacterPicker(false)) {
            MsgBox, You didn't make a selection. The script will now exit.
            ExitApp, 1
        }
    }
}

GetPoBPath() {
    if (!PoBPath or !FileExist(PoBPath . "\Path of Building.exe")) {
        if (!WinExist("Path of Building ahk_class SimpleGraphic Class"))
            DisplayInformation("Please launch Path of Building")
        WinWait, Path of Building ahk_class SimpleGraphic Class, , 300
        WinGet, FullPath, ProcessPath, Path of Building ahk_class SimpleGraphic Class

        if !FullPath {
            MsgBox Path of Building not detected.  Please relaunch this program and open Path of Building when requested
            ExitApp, 1
        }
        ; Get the PoB Directory from the PoB Path
        SplitPath, FullPath, , PoBPath
        IniWrite, %PoBPath%, %IniFile%, General, PathToPoB
        DisplayInformation()
    }
}

GetBuildDir(force = true) {
    if (!BuildDir or !FileExist(BuildDir))
        if (FileExist(PoBPath . "\Builds"))
            BuildDir := PoBPath . "\Builds"

    newDir := ""
    tempDir := BuildDir

    if (force or !BuildDir)
        FileSelectFolder, newDir, *%BuildDir%, 2, Select Character Build Directory

    if (!newDir and !tempDir) {
        MsgBox A Character Build Directory wasn't selected.  Please relaunch this program and select a Build Directory.
        ExitApp, 1
    }

    if (!newDir)
        newDir := tempDir

    GuiControl, CharacterPickerGUI:Text, CharacterDirectoryText, %newDir%
    return newDir
}

GetItemFromClipboard() {
    ; Verify the information is what we're looking for
    if RegExMatch(clipboard, "Rarity: .*?\R.*?\R?.*?\R--------\R.*") = 0 {
        MsgBox "Not a PoE item"
        return false
    }
    return clipboard
}

TestItemFromClipboard(Item, FileName := false) {
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

GenerateDPSSearch(FileName := false) {
    DisplayInformation("Generating DPS search...")
    RunWait, "%LuaJIT%" "%LuaDir%\SearchDPS.lua" "%FileName%", , Hide
    DisplayInformation()
}

UpdateCharacterBuild(FileName := false) {
    DisplayInformation("Updating Character Build")
    RunWait, "%LuaJIT%" "%LuaDir%\UpdateBuild.lua" "%FileName%", , Hide
    DisplayInformation()
}

SaveBuildDirectory(newDirectory) {
    BuildDir := newDirectory
    IniWrite, %newDirectory%, %IniFile%, General, BuildDirectory
}

SaveCharacterFile(NewFileName) {
    CharacterFileName = %NewFileName%
    IniWrite, %NewFileName%, %IniFile%, General, CharacterBuildFileName
}

SortArray(Array, Order="A") {
    ;Order A: Ascending, D: Descending, R: Reverse
    MaxIndex := ObjMaxIndex(Array)
    if (Order = "R") {
        count := 0
        loop, % MaxIndex
            ObjInsert(Array, ObjRemove(Array, MaxIndex - count++))
        Return
    }
    Partitions := "|" ObjMinIndex(Array) "," MaxIndex
    loop {
        comma := InStr(this_partition := SubStr(Partitions, InStr(Partitions, "|", False, 0)+1), ",")
        spos := pivot := SubStr(this_partition, 1, comma-1) , epos := SubStr(this_partition, comma+1)
        if (Order = "A") {
            loop, % epos - spos {
                if (Array[pivot] > Array[A_Index+spos])
                    ObjInsert(Array, pivot++, ObjRemove(Array, A_Index+spos))
            }
        } else {
            loop, % epos - spos {
                if (Array[pivot] < Array[A_Index+spos])
                    ObjInsert(Array, pivot++, ObjRemove(Array, A_Index+spos))
            }
        }
        Partitions := SubStr(Partitions, 1, InStr(Partitions, "|", False, 0)-1)
        if (pivot - spos) > 1    ;if more than one elements
            Partitions .= "|" spos "," pivot-1        ;the left partition
        if (epos - pivot) > 1    ;if more than one elements
            Partitions .= "|" pivot+1 "," epos        ;the right partition
    } until !Partitions
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

CreateTV(Folder, filePattern = "*.xml")
{
    Gui, CharacterPickerGUI:Default
    GuiControl, CharacterPickerGUI:-Redraw, CharacterTVCtrl
    TV_Delete() ; Clear the TreeView
    fileList := []
    dirTree := ["" = 0] ; 0 for top directory in TV
    Folder .= (SubStr(Folder, 0) == "\" ? "" : "\") ; Directories aren't typically passed with trailing forward slash

    loop, Files, %Folder%%filePattern%, FR
    {
        tempPath := SubStr(A_loopFileFullPath, StrLen(Folder) + 1)
        fileList.push(tempPath)

        SplitPath, tempPath, tempFile, tempDir

        ; The directory has already been added
        if (dirTree[tempDir])
            continue

        runningDir := ""
        Loop, Parse, tempDir, "\"
        {
            if (runningDir)
                newPath := runningDir . "\" . A_LoopField
            else
                newPath := A_LoopField

            if (!dirTree[newPath])
                dirTree[newPath] := TV_Add(A_LoopField, dirTree[runningDir], "Icon4")
            runningDir := newPath
        }
    }

    SortArray(fileList)
    for index, file in fileList {
        SplitPath, file, , tempDir, , tempName
        if ((Folder . file) != (BuildDir . "\" . CharacterFileName))
            TV_Add(tempName, dirTree[tempDir])
        else
            TV_Add(tempName, dirTree[tempDir], "Select")
    }
    if (!TV_GetCount()) {
        TV_Add("No Builds Found!", 0)
    }
    GuiControl, +Redraw, CharacterTVCtrl
}

DisplayCharacterPicker(allowTemp = true) {
    rtnVal := ""
    _GUIOK := false
    GuiControl, CharacterPickerGUI:Text, CharacterDirectoryText, %BuildDir%

    CreateTV(BuildDir)
    if (TV_GetChild(TV_GetSelection()))
        GuiControl, CharacterPickerGUI: -Default +Disabled, CharacterOKBtn

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

    if (!_GUIOK)
        return ""

    GuiControlGet, curDirectory, , CharacterDirectoryText

    ; Set the Value to "CURRENT" instead of a specific path name
    if (CharacterCurrentCtrl)
        rtnVal := "CURRENT"

    else {
        TV_GetText(rtnVal, TV_GetSelection())
        ParentID := TV_GetSelection()
        loop {
            ParentID := TV_GetParent(ParentID)
            if (!ParentID)
                break
            TV_GetText(ParentText, ParentID)
            rtnVal := ParentText "\" rtnVal
        }
        rtnVal := rtnVal . ".xml"
    }

    ; Update the INI with the changes
    if (CharacterChangeCtrl) {
        SaveCharacterFile(rtnVal)
        SaveBuildDirectory(curDirectory)
    }

    if (rtnVal != "CURRENT")
        rtnVal := curDirectory "\" rtnVal

    ; Update the build before continuing
    if (CharacterUpdateCtrl)
        UpdateCharacterBuild(rtnVal)

    return rtnVal
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
