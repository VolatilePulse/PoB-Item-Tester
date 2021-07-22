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

global MODSURL := "https://raw.githubusercontent.com/VolatilePulse/PoB-Item-Tester/master/ItemTester/mods.json"

DetectHiddenWindows, On

CreateGUI()
SetVariablesAndFiles(_LuaDir, _PobInstall, _PoBPath, _BuildDir, _CharacterFileName)
InsertTrayMenuItems()

UpdateModData()

Display("PoB Item Tester Loaded!")

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
TMenu_UpdateCharacterBuild:
+^u::
    UpdateCharacterBuild((_CharacterFileName == "CURRENT") ? "CURRENT" : _BuildDir "\" _CharacterFileName)
    return

; Test item from clipboard
TMenu_TestItemFromClipboard:
^#c::
    Item := GetItemFromClipboard()
    if (Item)
        TestItemFromClipboard(Item, (_CharacterFileName == "CURRENT") ? "CURRENT" : _BuildDir "\" _CharacterFileName)
    return

; Test item from clipboard with character picker
TMenuWithPicker_TestItemFromClipboard:
^#!c::
    Item := GetItemFromClipboard()
    if (Item) {
        filename := DisplayCharacterPicker()
        if (filename)
            TestItemFromClipboard(Item, filename)
    }
    return

; Generate DPS search
TMenu_GenerateDPSSearch:
^#d::
    GenerateDPSSearch((_CharacterFileName == "CURRENT") ? "CURRENT" : _BuildDir "\" _CharacterFileName)
    return

; Generate DPS search with character picker
TMenuWithPicker_GenerateDPSSearch:
^#!d::
    filename := DisplayCharacterPicker()
    if (filename)
        GenerateDPSSearch(filename)
    return

TMenu_ShowCharacterPicker:
    if (!DisplayCharacterPicker(false)) {
        MsgBox, You didn't make a selection. The script will now exit.
        ExitApp, 1
    }
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
    Gui, _CP:New, +Hwnd_CPHwnd -MaximizeBox -MinimizeBox, Pick Your Character Build File
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
    userDocs := A_MyDocuments
    EnvGet, curPATH, PATH
    EnvSet, PATH, %pobInstall%;%curPATH%
    EnvSet, LUA_PATH, %luaDir%\?.lua;%pobPath%\lua\?.lua;%pobPath%\lua\?\init.lua;%pobInstall%\lua\?.lua;%pobInstall%\lua\?\init.lua
    EnvSet, LUA_CPATH, %pobInstall%\?.dll
    EnvSet, POB_SCRIPTPATH, %pobPath%
    EnvSet, POB_RUNTIMEPATH, %pobInstall%
    EnvSet, POB_USERPATH, %userDocs%

    ; Make sure the Character file still exists
    if (fileName <> "CURRENT" and !(fileName and FileExist(buildDir "\" fileName))) {
        if (!DisplayCharacterPicker(false)) {
            MsgBox, You didn't make a selection. The script will now exit.
            ExitApp, 1
        }
    }
}

GetPoBPath(byRef pobInstall, byRef pobPath) {
    exeFound := FileExist(pobInstall "\Path of Building.exe")
    launchFound := FileExist(pobPath "\Launch.lua")
    if ((!pobInstall) || (!pobPath) || (!exeFound) || (!launchFound)) {
        if (!WinExist("Path of Building ahk_class SimpleGraphic Class"))
            DisplayInformation("Please launch Path of Building")

        WinWait, Path of Building ahk_class SimpleGraphic Class, , 300
        WinGet, FullPath, ProcessPath, Path of Building ahk_class SimpleGraphic Class

        if !FullPath {
            MsgBox Path of Building not detected.  Please relaunch this program and open Path of Building when requested.
            ExitApp, 1
        }

        ; Look at running PoB's command-line for paths
        GetPoBPathsFromCommandLine(pobInstall, pobPath)

        ; First verify we got a good pobInstall
        if (!pobInstall or !IsDir(pobInstall)) {
            MsgBox, % "Unable to locate Path of Building - please re-launch PoB and this script and try again"
            ExitApp, 1
        }

        ; Figure out a good pobPath
        CalculatePoBPath(pobInstall, pobPath)

        ; Check we got something usable
        if (!pobPath or !IsDir(pobPath) or !FileExist(pobPath "\Launch.lua")) {
            MsgBox, % "Unable to find Path of Building's data directory :( Please report this as a bug with details of your Path of Building setup."
            ExitApp, 1
        }

        IniWrite, %pobInstall%, %_IniFile%, General, PathToPoBInstall
        IniWrite, %pobPath%, %_IniFile%, General, PathToPoB

        DisplayInformation()
    }
}

CalculatePoBPath(ByRef pobInstall, ByRef pobPath) {
    ; Check for portable installs where pobPath can be set to pobInstall
    if (!pobPath and FileExist(pobInstall "\Launch.lua")) {
        pobPath := pobInstall
        Display("Detected PoB data as portable")
        return
    }

    ; Split installs are no longer supported due to not parsing command line arguments
    MsgBox, % "Please uninstall and reinstall the latest version of Path of Building Community"
            . " and relaunch this script."
    ExitApp, 1

    ; Path may already be good if the full command-line came from the shortcut
    if (pobPath and FileExist(pobPath "\Launch.lua")) {
        Display("Detected PoB data from shortcut")
        return
    }

    ; The old installer would put data in <Drive>:\ProgramData\Path of Building [Community]
    SplitPath, pobInstall, , , , , drive

    pobPath := drive "\ProgramData\Path of Building Community"
    if (IsDir(pobPath) and FileExist(pobPath "\Launch.lua")) {
        Display("Detected PoB Community data")
        return
    }

    pobPath := drive "\ProgramData\Path of Building"
    if (IsDir(pobPath) and FileExist(pobPath "\Launch.lua")) {
        Display("Detected original PoB data")
        return
    }

    ; We failed :(
    pobPath := ""
}

GetPoBPathsFromCommandLine(ByRef pobInstall, ByRef pobPath) {
    ; Get the commandline that ran PoB
    cmdLine := ""
    pobPath := ""
    pobInstall := ""
    WinGet, pid, PID, Path of Building ahk_class SimpleGraphic Class
    for proc in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process") {
        if (proc.Name == "Path of Building.exe") {
            if (exePath and exePath != proc.ExecutablePath) {
                MsgBox, % "Multiple versions of Path of Building are running - please run only the most recent and try agian"
                ExitApp, 1
            }
            exePath := proc.ExecutablePath
        }
    }

    SplitPath, exePath,, pobInstall
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

InsertTrayMenuItems() {
    Menu, Tray, NoStandard
    Menu, Tray, Add, Show Character Picker, TMenu_ShowCharacterPicker
    Menu, Tray, Add, Re-import build (update), TMenu_UpdateCharacterBuild
    Menu, Tray, Add, Test item from clipboard, TMenu_TestItemFromClipboard
    Menu, Tray, Add, Test item from clipboard (choose char), TMenuWithPicker_TestItemFromClipboard
    Menu, Tray, Add, Generate DPS search, TMenu_GenerateDPSSearch
    Menu, Tray, Add, Generate DPS search (choose char), TMenuWithPicker_GenerateDPSSearch
    Menu, Tray, Add ; Separator
    Menu, Tray, Standard
}

GetItemFromClipboard() {
    ; Verify the information is what we're looking for
    if RegExMatch(clipboard, "(Rarity|Item Class): .+?(\r.+?){3,}") = 0 {
        MsgBox % "Not a PoE item"
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
    cmd = "%_LuaJIT%" "%_LuaDir%\TestItem.lua" "%fullPath%" "%A_Temp%\PoBTestItem.txt"
    RunLua(cmd)
    DisplayInformation()
    DisplayOutput()
}

GenerateDPSSearch(fullPath) {
    DisplayInformation("Generating DPS search...")
    cmd = "%_LuaJIT%" "%_LuaDir%\SearchDPS.lua" "%fullPath%"
    RunLua(cmd)
    DisplayInformation()
}

UpdateCharacterBuild(fullPath) {
    DisplayInformation("Updating Character Build")
    cmd = "%_LuaJIT%" "%_LuaDir%\UpdateBuild.lua" "%fullPath%"
    RunLua(cmd)
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
Display(byRef msg) {
    DisplayInformation(msg)
    Sleep, 3000
    DisplayInformation()
}

DisplayInformation(byRef string := "") {
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

UpdateModData() {
    OldEtag := ""
    FileRead, OldEtag, % "ItemTester\mods.json.version" ; ignores errors

    ; Begin a request for mods.json but only if the Etag doesn't match what we have
    global modsJsonReq
    modsJsonReq := ComObjCreate("Msxml2.XMLHTTP")
    modsJsonReq.open("GET", MODSURL, False)
    modsJsonReq.setRequestHeader("User-Agent", "VolatilePulse-PoBItemTester-updater")
    modsJsonReq.setRequestHeader("If-None-Match", OldEtag)
    modsJsonReq.onreadystatechange := Func("ReceiveModsJson")
    modsJsonReq.send()
}

ReceiveModsJson() {
    global modsJsonReq

    if (modsJsonReq.readyState != 4)  ; Not done yet.
        return

    statusN := modsJsonReq.status

    if (statusN >= 200 and statusN < 300) {
        ; New file version has been downloaded
        FileDelete, % A_ScriptDir "\ItemTester\mods.json"
        FileAppend, % modsJsonReq.responseText, % A_ScriptDir "\ItemTester\mods.json"

        ; Update version file with ETag
        NewEtag := modsJsonReq.getResponseHeader("ETag")
        FileDelete, % A_ScriptDir "\ItemTester\mods.json.version"
        FileAppend, % NewEtag, % A_ScriptDir "\ItemTester\mods.json.version"
    } else if (statusN == 304) {
        ; Not modified - do nothing
    } else {
        ; Failed :(
        Display("Failed to fetch latest mod data :(")
    }
}

ExitFunc() {
    ; Clean up temporary files, if able to
    FileDelete, %A_Temp%\PoBTestItem.txt
    FileDelete, %A_Temp%\PoBTestItem.txt.html
}

RunLua(cmd) {
    stdout := StdoutToVar_CreateProcess(cmd, , , exitcode)

    if (exitcode) {
        MsgBox, 4, % "Exit Code: " . exitcode, % "Output:`r `r" . stdout . "`rCopy output to clipboard?"
        IfMsgBox, Yes
            Clipboard := stdout
    }
}

; ----------------------------------------------------------------------------------------------------------------------
; Function .....: StdoutToVar_CreateProcess
; Description ..: Runs a command line program and returns its output.
; Parameters ...: sCmd      - Commandline to execute.
; ..............: sEncoding - Encoding used by the target process. Look at StrGet() for possible values.
; ..............: sDir      - Working directory.
; ..............: nExitCode - Process exit code, receive it as a byref parameter.
; Return .......: Command output as a string on success, empty string on error.
; AHK Version ..: AHK_L x32/64 Unicode/ANSI
; Author .......: Sean (http://goo.gl/o3VCO8), modified by nfl and by Cyruz
; License ......: WTFPL - http://www.wtfpl.net/txt/copying/
; Changelog ....: Feb. 20, 2007 - Sean version.
; ..............: Sep. 21, 2011 - nfl version.
; ..............: Nov. 27, 2013 - Cyruz version (code refactored and exit code).
; ..............: Mar. 09, 2014 - Removed input, doesn't seem reliable. Some code improvements.
; ..............: Mar. 16, 2014 - Added encoding parameter as pointed out by lexikos.
; ..............: Jun. 02, 2014 - Corrected exit code error.
; ..............: Nov. 02, 2016 - Fixed blocking behavior due to ReadFile thanks to PeekNamedPipe.
; ----------------------------------------------------------------------------------------------------------------------
StdoutToVar_CreateProcess(sCmd, sEncoding:="CP0", sDir:="", ByRef nExitCode:=0) {
    DllCall( "CreatePipe",           PtrP,hStdOutRd, PtrP,hStdOutWr, Ptr,0, UInt,0 )
    DllCall( "SetHandleInformation", Ptr,hStdOutWr, UInt,1, UInt,1                 )

            VarSetCapacity( pi, (A_PtrSize == 4) ? 16 : 24,  0 )
    siSz := VarSetCapacity( si, (A_PtrSize == 4) ? 68 : 104, 0 )
    NumPut( siSz,      si,  0,                          "UInt" )
    NumPut( 0x100,     si,  (A_PtrSize == 4) ? 44 : 60, "UInt" )
    NumPut( hStdOutWr, si,  (A_PtrSize == 4) ? 60 : 88, "Ptr"  )
    NumPut( hStdOutWr, si,  (A_PtrSize == 4) ? 64 : 96, "Ptr"  )

    If ( !DllCall( "CreateProcess", Ptr,0, Ptr,&sCmd, Ptr,0, Ptr,0, Int,True, UInt,0x08000000
                                  , Ptr,0, Ptr,sDir?&sDir:0, Ptr,&si, Ptr,&pi ) )
        Return ""
      , DllCall( "CloseHandle", Ptr,hStdOutWr )
      , DllCall( "CloseHandle", Ptr,hStdOutRd )

    DllCall( "CloseHandle", Ptr,hStdOutWr ) ; The write pipe must be closed before reading the stdout.
    While ( 1 )
    { ; Before reading, we check if the pipe has been written to, so we avoid freezings.
        If ( !DllCall( "PeekNamedPipe", Ptr,hStdOutRd, Ptr,0, UInt,0, Ptr,0, UIntP,nTot, Ptr,0 ) )
            Break
        If ( !nTot )
        { ; If the pipe buffer is empty, sleep and continue checking.
            Sleep, 100
            Continue
        } ; Pipe buffer is not empty, so we can read it.
        VarSetCapacity(sTemp, nTot+1)
        DllCall( "ReadFile", Ptr,hStdOutRd, Ptr,&sTemp, UInt,nTot, PtrP,nSize, Ptr,0 )
        sOutput .= StrGet(&sTemp, nSize, sEncoding)
    }

    ; * SKAN has managed the exit code through SetLastError.
    DllCall( "GetExitCodeProcess", Ptr,NumGet(pi,0), UIntP,nExitCode )
    DllCall( "CloseHandle",        Ptr,NumGet(pi,0)                  )
    DllCall( "CloseHandle",        Ptr,NumGet(pi,A_PtrSize)          )
    DllCall( "CloseHandle",        Ptr,hStdOutRd                     )
    Return sOutput
}

IsDir(dir) {
    return InStr(FileExist(dir), "D")
}

/*

PoB file behavior and locations

OpenArl's `Path of Building.exe` looks for Launch.lua in the following places:
    * The first passed in argument
    * The current directory
    * `%ProgramData%/Path of Building`

Path of Building Community Fork also currently uses this exe in its original form as it cannot be recompiled.

The PoB Community installer in the past has opted for installing into
    `%Drive%:/ProgramData/Path of Building Community` and requiring the path to be included
    as an argument to the exe in the progran's shortcut. Launching without the shortcut will fail.

As of writing, the current PoB Community installer installs as if it were the portable version (both exe and data)
    into `%AppData%/Path of Building Community` and no longer requires admin permissions.

Between Community versions 1.4.170.4 and 1.4.170.14 (at least) the installer has randomly switched between these
    two different approaches, meaning we have to support both.

*/
