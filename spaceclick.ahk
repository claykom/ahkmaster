#Requires AutoHotkey v2.0
; Runtime guard: show a friendly message and exit if this script is run with the wrong AutoHotkey version.
if SubStr(A_AhkVersion, 1, 1) != "2"
{
    MsgBox("This script requires AutoHotkey v2.x.`nPlease install AutoHotkey v2 and run this script with the v2 executable.`nhttps://www.autohotkey.com/")
    ExitApp
}

; spaceclick.ahk — Managed child script: Space -> Left Click (1:1)
; This script registers itself with the master controller and honors the
; control/enabled marker file created by the master.
;
; Behavior:
; - On start, the script writes a registration file into `control\scripts\`
; - The master controller toggles this script by creating/deleting
;   `control\enabled\spaceclick.enabled`
; - When enabled, pressing Space sends exactly one left mouse click (1:1 remap)
; - The original Space key is suppressed when the remap is active

; Configuration
; Scope to a specific window. Examples:
;  "ahk_exe notepad.exe"   ; Notepad
;  "ahk_exe chrome.exe"    ; Chrome browser
; Set to "" for global (applies to all windows)
WinFilter := ""  ; change to your target application as needed

ControlDir := A_ScriptDir "\control"
DirCreate(ControlDir)
DirCreate(ControlDir "\enabled")
DirCreate(ControlDir "\scripts")

; Write registration file so master can discover this script
regFile := ControlDir "\scripts\spaceclick.info"
regText := "name=spaceclick`npath=" A_ScriptFullPath "`n"
try FileDelete(regFile)
FileAppend(regText, regFile)

; Helper: send a notification to master with level support
; level: "info", "warning", "error"
NotifyMaster(msg, level := "info")
{
    global ControlDir
    ts := A_Now
    scriptName := "spaceclick"
    
    ; Write to log file with standardized format
    line := ts "`t[" level "]`t[" scriptName "]`t" msg "`n"
    try FileAppend(line, ControlDir "\notifications.txt")
    
    ; Show tray notification based on level
    switch level {
        case "info":
            TrayTip("[" scriptName "]", msg, 2)
        case "warning":
            TrayTip("[" scriptName "] WARNING", msg, 3)
        case "error":
            TrayTip("[" scriptName "] ERROR", msg, 5)
    }
}

; State
enabledMarker := ControlDir "\enabled\spaceclick.enabled"
shutdownMarker := ControlDir "\shutdown.marker"
wasEnabled := false

; Hotkey setup - initially disabled, will be enabled/disabled dynamically
Hotkey("Space", SpaceClickHandler, "Off")

; Main loop: check enabled state and activate/deactivate hotkey
SetTimer(CheckEnabled, 500)
SetTimer(CheckShutdown, 250)

CheckShutdown()
{
    global shutdownMarker
    ; If master signals shutdown, exit gracefully
    if FileExist(shutdownMarker)
    {
        NotifyMaster("Exiting: Shutdown signal received from master", "info")
        ExitApp
    }
}

CheckEnabled()
{
    global enabledMarker, wasEnabled, WinFilter
    
    enabled := FileExist(enabledMarker)
    
    if enabled && !wasEnabled
    {
        ; Just became enabled
        Hotkey("Space", "On")
        NotifyMaster("Toggled ON by master (Space->Click active)", "info")
        wasEnabled := true
    }
    else if !enabled && wasEnabled
    {
        ; Just became disabled
        Hotkey("Space", "Off")
        NotifyMaster("Toggled OFF by master (Space->Click inactive)", "info")
        wasEnabled := false
    }
}

; The actual remap handler: Space sends a single left click
SpaceClickHandler(*)
{
    global WinFilter
    ; Only click if no WinFilter or the filter matches
    if WinFilter == "" || WinActive(WinFilter)
    {
        Click
    }
    else
    {
        ; If window doesn't match, send Space through normally
        Send("{Space}")
    }
}

; Quick exit hotkey for testing
Pause:: {
    NotifyMaster("Exiting: Manual exit via Pause key", "info")
    ExitApp
}

; On start notification (only shown once at startup)
NotifyMaster("Started: Waiting for master to enable", "info")

; --- End of spaceclick.ahk ---
