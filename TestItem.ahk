#NoEnv
#persistent
#SingleInstance, force

;#Warn

;--------------------------------------------------
; Initialization
;--------------------------------------------------

global _LuaDir := "\ItemTester"

global _IniFile := A_ScriptDir "\TestItem.ini"
global _LuaJIT := A_ScriptDir "\bin\luajit.exe"

global _GUIOK := false
global _PoBPath := "", _BuildDir = "", _CharacterFileName = "", _PoBInstall = ""

; Info Tooltip variables
global _Info, _InfoHwnd, _InfoText
; Character Picker GUI variables
global _CP, _CPHwnd, _CPCurrent, _CPDir, _CPTV, _CPUpdate, _CPChange, _CPOK
; Item Viewer variables
global _Item, _ItemHwnd, _ItemText

DetectHiddenWindows, On

CreateGUI()
SetVariablesAndFiles(_LuaDir, _PobInstall, _PoBPath, _BuildDir, _CharacterFileName)

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
    GuiControlGet, isChecked, , _CPCurrent
    if (isChecked) {
        GuiControl, _CP: +Disabled, _CPTV
        GuiControl, _CP: -Disabled +Default, _CPOK
    }
    else {
        GuiControl, _CP: -Disabled, _CPTV
        if (TV_GetChild(TV_GetSelection()))
            GuiControl, _CP: -Default +Disabled, _CPOK
    }
    return

CPTV:
    if ((A_GuiEvent != "S") || (!TV_GetText(_, A_EventInfo)))
        return

    ; A character file has been selected
    if (!TV_GetChild(A_EventInfo))
        GuiControl, _CP: +Default -Disabled, _CPOK
    else
        GuiControl, _CP: -Default +Disabled, _CPOK
    return

ChangeDir:
    CreateTV(GetBuildDir(_PoBPath, _BuildDir))
    return

Ok:
    _GUIOK := true
    Gui, Submit
    return

; Re-import build (update)
+^u::
    UpdateCharacterBuild((_CharacterFileName == "CURRENT") ? "CURRENT" : _BuildDir "\" _CharacterFileName)
    return

; Test item from clipboard
^#c::
    Item := GetItemFromClipboard()
    if (Item)
        TestItemFromClipboard(Item, (_CharacterFileName == "CURRENT") ? "CURRENT" : _BuildDir "\" _CharacterFileName)
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
    GenerateDPSSearch((_CharacterFileName == "CURRENT") ? "CURRENT" : _BuildDir "\" _CharacterFileName)
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
    Gui, _Info:New, +AlwaysOnTop -Border -MaximizeBox -MinimizeBox +LastFound +Disabled +Hwnd_InfoHwnd
    Gui, _Info:Add, Text, v_InfoText Center, Please select Character Build Directory ; Default control width
    Gui, _Info:Show, NoActivate Hide

    ; Character Picker
    Gui, _CP:New, +Hwnd_CPHwnd -MaximizeBox -MinimizeBox, Pick You Character Build File
    Gui, _CP:Margin, 8, 8
    Gui, _CP:Add, Checkbox, v_CPCurrent gCPCurrentCheck, Use PoB's last used build (since it last closed)
    Gui, _CP:Add, Button, gChangeDir, Change
    Gui, _CP:Add, Text, v_CPDir x+5 ym+27 w300, Build Directory
    Gui, _CP:Add, TreeView, v_CPTV gCPTV w300 r20 xm ImageList%ImageListID%
    Gui, _CP:Add, Checkbox, v_CPUpdate, Update Build before continuing
    Gui, _CP:Add, Checkbox, v_CPChange Checked, Make this the default Build
    Gui, _CP:Add, Button, v_CPOK Default w50 gOK, OK
    Gui, _CP:Show, NoActivate Hide

    ; Item Viewer
    Gui, _Item:New, +AlwaysOnTop +Hwnd_ItemHwnd, PoB Item Tester
    Gui, _Item:Add, ActiveX, x0 y0 w400 h500 v_ItemText, Shell.Explorer
    _ItemText.silent := true
    Gui, _Item:Show, NoActivate Hide
}

SetVariablesAndFiles(byRef luaDir, byRef pobInstall, byRef pobPath, byRef buildDir, byRef fileName) {
    IniRead, pobInstall, %_IniFile%, General, PathToPoBInstall, %A_Space%
    IniRead, pobPath, %_IniFile%, General, PathToPoB, %A_Space%
    IniRead, buildDir, %_IniFile%, General, BuildDirectory, %A_Space%
    IniRead, fileName, %_IniFile%, General, CharacterBuildFileName, %A_Space%

    ; Make sure PoB hasn't moved
    GetPoBPath(pobInstall, pobPath)
    SaveBuildDirectory(buildDir, GetBuildDir(pobInstall, buildDir, false))

    SetWorkingDir, %pobPath%

    luaDir := A_ScriptDir . luaDir
    EnvGet, curPATH, PATH
    EnvSet, PATH, %pobInstall%;%curPATH%
    EnvSet, LUA_PATH, %luaDir%\?.lua;%pobPath%\lua\?.lua;%pobInstall%\lua\?.lua
    EnvSet, LUA_CPATH, %pobInstall%\?.dll

    ; Make sure the Character file still exists
    if (fileName <> "CURRENT" and !(fileName and FileExist(buildDir "\" fileName))) {
        if (!DisplayCharacterPicker(false)) {
            MsgBox, You didn't make a selection. The script will now exit.
            ExitApp, 1
        }
    }
}

GetPoBPath(byRef pobInstall, byRef pobPath) {
    exeFound := (FileExist(pobInstall "\Path of Building.exe"))
    launchFound := ((FileExist(pobInstall "\Launch.lua")) || (FileExist(pobPath "\Launch.lua")))
    if ((!pobInstall) || (!pobPath) || (!exeFound) || (!launchFound)) {
        if (!WinExist("Path of Building ahk_class SimpleGraphic Class"))
            DisplayInformation("Please launch Path of Building")

        WinWait, Path of Building ahk_class SimpleGraphic Class, , 300
        WinGet, FullPath, ProcessPath, Path of Building ahk_class SimpleGraphic Class

        if !FullPath {
            MsgBox Path of Building not detected.  Please relaunch this program and open Path of Building when requested
            ExitApp, 1
        }
        ; Get the PoB Directory from the PoB Path
        SplitPath, FullPath, , pobInstall
        IniWrite, %pobInstall%, %_IniFile%, General, PathToPoBInstall
        if (FileExist(pobInstall "\Launch.lua"))
            pobPath := pobInstall
        else if (FileExist(A_AppDataCommon "\Path of Building\Launch.lua"))
            pobPath := A_AppDataCommon "\Path of Building"
        else
            MsgBox % A_AppDataCommon "\Path of Building\Launch.lua"
        IniWrite, %pobPath%, %_IniFile%, General, PathToPoB

        DisplayInformation()
    }
}

GetBuildDir(pobInstall, byRef buildDir, force = true) {
    if (!buildDir or !FileExist(buildDir))
    {
        if (FileExist(pobInstall "\Builds"))
            buildDir := pobInstall "\Builds"
        else if (FileExist(A_MyDocuments "\Path of Building\Builds"))
            buildDir := A_MyDocuments "\Path of Building\Builds"
    }

    newDir := ""
    tempDir := buildDir

    if (force or !buildDir)
        FileSelectFolder, newDir, *%buildDir%, 2, Select Character Build Directory

    if (!newDir and !tempDir) {
        MsgBox A Character Build Directory wasn't selected.  Please relaunch this program and select a Build Directory.
        ExitApp, 1
    }

    if (!newDir)
        newDir := tempDir

    GuiControl, _CP:Text, _CPDir, %newDir%
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

TestItemFromClipboard(item, fullPath) {
    ; Erase old content first
    FileDelete, %A_Temp%\PoBTestItem.txt
    FileDelete, %A_Temp%\PoBTestItem.txt.html
    FileAppend, %item%, %A_Temp%\PoBTestItem.txt

    DisplayInformation("Parsing Item Data...")
    RunWait, "%_LuaJIT%" "%_LuaDir%\TestItem.lua" "%fullPath%" "%A_Temp%\PoBTestItem.txt", , Hide
    DisplayInformation()
    DisplayOutput()
}

GenerateDPSSearch(fullPath) {
    DisplayInformation("Generating DPS search...")
    RunWait, "%_LuaJIT%" "%_LuaDir%\SearchDPS.lua" "%fullPath%", , Hide
    DisplayInformation()
}

UpdateCharacterBuild(fullPath) {
    DisplayInformation("Updating Character Build")
    RunWait, "%_LuaJIT%" "%_LuaDir%\UpdateBuild.lua" "%fullPath%", , Hide
    DisplayInformation()
}

SaveBuildDirectory(byRef buildDir, newDirectory) {
    buildDir := newDirectory
    IniWrite, %newDirectory%, %_IniFile%, General, BuildDirectory
}

SaveCharacterFile(byRef fileName, newFile) {
    fileName := newFile
    IniWrite, %newFile%, %_IniFile%, General, CharacterBuildFileName
}

SortArray(array, order := "A") {
    ; Order A: Ascending, D: Descending, R: Reverse
    maxIndex := ObjMaxIndex(array)
    if (order = "R") {
        count := 0
        loop, % maxIndex
            ObjInsert(array, ObjRemove(array, maxIndex - count ++))
        return
    }
    partitions := "|" ObjMinIndex(array) "," maxIndex
    loop {
        comma := InStr(this_partition := SubStr(partitions, InStr(partitions, "|", false, 0) + 1), ",")
        spos := pivot := SubStr(this_partition, 1, comma - 1) , epos := SubStr(this_partition, comma + 1)
        if (order = "A") {
            loop, % epos - spos {
                if (array[pivot] > array[A_Index + spos])
                    ObjInsert(array, pivot ++, ObjRemove(array, A_Index + spos))
            }
        }
        else {
            loop, % epos - spos {
                if (array[pivot] < array[A_Index + spos])
                    ObjInsert(array, pivot ++, ObjRemove(array, A_Index + spos))
            }
        }
        partitions := SubStr(partitions, 1, InStr(partitions, "|", false, 0) - 1)
        if (pivot - spos) > 1    ;if more than one elements
            partitions .= "|" spos "," pivot - 1        ;the left partition
        if (epos - pivot) > 1    ;if more than one elements
            partitions .= "|" pivot + 1 "," epos        ;the right partition
    } until !partitions
}

;--------------------------------------------------
; GUI Display Functions
;--------------------------------------------------
DisplayInformation(string := "") {
    ; Hide the Information Window
    if (string = "") {
        Gui, _Info:Hide
        return
    }

    GuiControl, _Info:Text, _InfoText, %string%
    WinGetPos, winX, winY, winW, winH, A

    ; If no active window was found
    if (winX = "") {
        return
    }

    WinGetPos, , , guiW, guiH, ahk_id %_InfoHwnd%
    posX := winX + (winW - guiW) / 2
    posY := winY + 50
    Gui, _Info:Show, X%posX% Y%posY% NoActivate
}

CreateTV(folder, filePattern = "*.xml") {
    Gui, _CP:Default
    GuiControl, _CP:-Redraw, _CPTV
    TV_Delete() ; Clear the TreeView
    fileList := []
    dirTree := ["" = 0] ; 0 for top directory in TV
    folder .= (SubStr(folder, 0) == "\" ? "" : "\") ; Directories aren't typically passed with trailing forward slash

    loop, Files, %folder%%filePattern%, FR
    {
        tempPath := SubStr(A_loopFileFullPath, StrLen(folder) + 1)
        fileList.push(tempPath)

        SplitPath, tempPath, tempFile, tempDir

        ; The directory has already been added
        if (dirTree[tempDir])
            continue

        runningDir := ""
        loop, Parse, tempDir, "\"
        {
            if (runningDir)
                newPath := runningDir "\" A_LoopField
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

        if ((folder . file) != (_BuildDir "\" _CharacterFileName))
            TV_Add(tempName, dirTree[tempDir])
        else
            TV_Add(tempName, dirTree[tempDir], "Select")
    }

    GuiControl, _CP:+Redraw, _CPTV
}

DisplayCharacterPicker(allowTemp = true) {
    _GUIOK := false
    rtnVal := ""
    GuiControl, _CP:Text, _CPDir, %_BuildDir%

    CreateTV(_BuildDir)
    if (TV_GetChild(TV_GetSelection()))
        GuiControl, _CP:-Default +Disabled, _CPOK

    if (allowTemp)
        GuiControl, _CP:-Disabled, _CPChange
    else
        GuiControl, _CP:+Disabled, _CPChange

    ; Move CharacterPicker to the center of the currently active window
    WinGetPos, winX, winY, winW, winH, A
    WinGetPos, , , guiW, guiH, ahk_id %_CPHwnd%
    posX := winX + (winW - guiW) / 2
    posY := winY + (winH - guiH) / 2
    Gui, _CP:Show, X%posX% Y%posY%

    DetectHiddenWindows, Off
    WinWait, ahk_id %_CPHwnd%
    WinWaitClose, ahk_id %_CPHwnd%
    DetectHiddenWindows, On

    if (!_GUIOK)
        return ""

    GuiControlGet, curDirectory, , _CPDir

    ; Set the Value to "CURRENT" instead of a specific path name
    if (_CPCurrent)
        rtnVal := "CURRENT"
    else {
        TV_GetText(rtnVal, TV_GetSelection())
        parentID := TV_GetSelection()
        loop {
            parentID := TV_GetParent(parentID)
            if (!parentID)
                break
            TV_GetText(parentText, parentID)
            rtnVal := parentText "\" rtnVal
        }
        rtnVal := rtnVal ".xml"
    }

    ; Update the INI with the changes
    if (_CPChange) {
        SaveCharacterFile(_CharacterFileName, rtnVal)
        SaveBuildDirectory(_BuildDir, curDirectory)
    }

    if (rtnVal != "CURRENT")
        rtnVal := curDirectory "\" rtnVal

    ; Update the build before continuing
    if (_CPUpdate)
        UpdateCharacterBuild(rtnVal)

    return rtnVal
}

DisplayOutput() {
    if (!FileExist(A_Temp "\PoBTestItem.txt.html")) {
        MsgBox, Item type is not supported.
        return
    }

    _ItemText.Navigate("file://" A_Temp "\PoBTestItem.txt.html")
    while _ItemText.busy or _ItemText.ReadyState != 4
        Sleep 10

    WinGetPos, winX, winY, winW, winH, A
    Gui, _Item:+LastFound
    WinGetPos, , , guiW, guiH, ahk_id %_ItemHwnd%
    MouseGetPos, mouseX, mouseY
    posX := ((mouseX > (winX + winW / 2)) ? (winX + winW * 0.25 - guiW * 0.5) : (winX + winW * 0.75 - guiW * 0.5))
    posY := ((mouseY > (winY + winH / 2)) ? (winY + winH * 0.25 - guiH * 0.5) : (winY + winH * 0.75 - guiH * 0.5))
    Gui, _Item:Show, w400 h500 X%posX% Y%posY% NoActivate
}

ExitFunc() {
    ; Clean up temporary files, if able to
    FileDelete, %A_Temp%\PoBTestItem.txt
    FileDelete, %A_Temp%\PoBTestItem.txt.html
}
