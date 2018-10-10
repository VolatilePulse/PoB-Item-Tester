#persistent
#SingleInstance, force

;--------------------------------------------------
; Initialization
;--------------------------------------------------
{
    ; First time running
    global CharacterFileName
    IniRead, CharacterFileName, TestItem.ini, General, CharacterBuildFileName

    If !CharacterFileName
        IniWrite, Default.xml, TestItem.ini, General, CharacterBuildFileName

    global PoBPath
    IniRead, PoBPath, TestItem.ini, General, PathToPoB

    ; If PoBPath hasn't been set yet
    If !PoBPath {
        WinGet, FullPath, ProcessPath, Path of Building ahk_class SimpleGraphic Class
        If FullPath {
            SplitPath, FullPath, , PoBPath
            IniWrite, %PoBPath%, TestItem.ini, General, PathToPoB
        }
        Else
            IniWrite, %PoBPath%, TestItem.ini, General, PathToPoB
    }

    If !PoBPath {
        MsgBox Check %A_ScriptDir%\TestItem.ini to update your values
        ExitApp, 0
    }

    SetWorkingDir, %PoBPath%
}

;--------------------------------------------------
; Global Hooks
;--------------------------------------------------

OnClipboardChange("ClipboardChange")
OnExit("ExitFunc")

GuiClose:
    Gui, Destroy
    return

;--------------------------------------------------
; Functions
;--------------------------------------------------

ClipboardChange(ContentType) {
    If ContentType != 1
        Return

    ; Verify the information is what we're looking for
    If RegExMatch(clipboard, "Rarity: .*?\R.*?\R?.*?\R--------\R.*") = 0
        Return

    ; Erase old content first
    FileDelete, %A_Temp%\PoBTestItem.txt
    FileAppend, %clipboard%, %A_Temp%\PoBTestItem.txt

    RunWait, "Path of Building.exe" "%A_ScriptDir%\TestItem.lua" "Builds\%CharacterFileName%" "%A_Temp%\PoBTestItem.txt"

    DisplayOutput()
}

DisplayOutput() {
    global
    Gui Add, ActiveX, x0 y0 w400 h500 vWB, Shell.Explorer
    WB.silent := true
    WB.Navigate("file://" . A_Temp . "\PoBTestItem.txt.html")

    while WB.readystate != 4 or WB.busy
        sleep 10

    Gui Show, w400 h500
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