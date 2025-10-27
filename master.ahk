#Requires AutoHotkey v2.0
; master.ahk — Master controller for automation scripts
; - v2 runtime guard
; - Creates a `control` folder next to this script for marker files and notifications
; - Manages child scripts via toggle hotkeys
; - Notifications written to control\notifications.txt
;
; Usage: Run this first, then launch child scripts. Child scripts register automatically.
; The master toggles children by creating/deleting marker files in control\enabled\

; Runtime guard: show a friendly message and exit if not running under AHK v2.
if SubStr(A_AhkVersion, 1, 1) != "2"
{
    MsgBox("This script requires AutoHotkey v2.x.`nPlease run it with AutoHotkey v2 (https://www.autohotkey.com/).")
    ExitApp
}

; ----------------
; Configuration
; ----------------
; Directory for coordination and notifications
ControlDir := A_ScriptDir "\control"
DirCreate(ControlDir)
DirCreate(ControlDir "\enabled")
DirCreate(ControlDir "\scripts")

NotifFile := ControlDir "\notifications.txt"

; Auto-launch child scripts on startup
AutoLaunchChildren := true  ; Set to false to disable auto-launch

; Track child script PIDs for cleanup on exit
ChildProcesses := []

; ----------------
; Notification Manager
; ----------------
class NotificationManager {
    static notifications := []
    static maxHistory := 100
    
    ; Log a notification with level and source
    ; level: "info", "warning", "error"
    ; source: "master" or child script name
    ; msg: the message text
    static Log(level, source, msg) {
        ts := A_Now
        entry := {
            timestamp: ts,
            level: level,
            source: source,
            message: msg
        }
        
        ; Add to in-memory history
        this.notifications.Push(entry)
        if this.notifications.Length > this.maxHistory
            this.notifications.RemoveAt(1)
        
        ; Write to file
        line := ts "`t[" level "]`t[" source "]`t" msg "`n"
        try FileAppend(line, ControlDir "\notifications.txt")
        
        ; Show tray tip based on level
        this.ShowTrayTip(level, source, msg)
    }
    
    static ShowTrayTip(level, source, msg) {
        ; Different icon/duration based on level
        switch level {
            case "info":
                TrayTip("[" source "]", msg, 2)
            case "warning":
                TrayTip("[" source "] WARNING", msg, 3)
            case "error":
                TrayTip("[" source "] ERROR", msg, 5)
        }
    }
    
    ; Get notifications filtered by criteria
    static GetFiltered(filterLevel := "", filterSource := "") {
        results := []
        for entry in this.notifications {
            if filterLevel != "" && entry.level != filterLevel
                continue
            if filterSource != "" && entry.source != filterSource
                continue
            results.Push(entry)
        }
        return results
    }
    
    ; Format notifications for display
    static Format(entries) {
        output := ""
        ; Show newest first
        loop entries.Length {
            i := entries.Length - A_Index + 1
            entry := entries[i]
            output .= entry.timestamp " [" entry.level "] [" entry.source "] " entry.message "`n"
        }
        return output
    }
    
    ; Show all notifications
    static ShowAll() {
        if this.notifications.Length == 0 {
            MsgBox("No notifications yet.")
            return
        }
        output := this.Format(this.notifications)
        MsgBox(output, "All Notifications")
    }
    
    ; Show only errors
    static ShowErrors() {
        errors := this.GetFiltered("error")
        if errors.Length == 0 {
            MsgBox("No errors logged.")
            return
        }
        output := this.Format(errors)
        MsgBox(output, "Errors Only")
    }
    
    ; Show only master notifications
    static ShowMasterOnly() {
        master := this.GetFiltered("", "master")
        if master.Length == 0 {
            MsgBox("No master notifications.")
            return
        }
        output := this.Format(master)
        MsgBox(output, "Master Notifications")
    }
    
    ; Show only child script notifications
    static ShowChildrenOnly() {
        children := []
        for entry in this.notifications {
            if entry.source != "master"
                children.Push(entry)
        }
        if children.Length == 0 {
            MsgBox("No child script notifications.")
            return
        }
        output := this.Format(children)
        MsgBox(output, "Child Script Notifications")
    }
}

; ----------------
; Status GUI
; ----------------
class StatusGui {
    static guiObj := ""
    static scriptControls := Map()
    
    static Create() {
        global ControlDir
        
        ; Create the main GUI window
        this.guiObj := Gui("+Resize", "Master Controller Status")
        this.guiObj.SetFont("s10")
        this.guiObj.BackColor := "0xF0F0F0"
        
        ; Header
        this.guiObj.AddText("w400 Center", "Automation Master Controller").SetFont("s12 bold")
        this.guiObj.AddText("w400 xm", "")  ; Spacer
        
        ; Child Scripts Section
        this.guiObj.AddText("xm", "Child Scripts:").SetFont("s10 bold")
        
        ; Build script list
        scriptsDir := ControlDir "\scripts"
        yPos := 100
        scriptFound := false
        
        if DirExist(scriptsDir) {
            Loop Files, scriptsDir "\*.info" {
                scriptFound := true
                scriptName := StrReplace(A_LoopFileName, ".info", "")
                
                ; Check if enabled
                enabledFile := ControlDir "\enabled\" scriptName ".enabled"
                isEnabled := FileExist(enabledFile)
                
                ; Add controls for this script
                controls := []
                
                ; Script name
                nameCtrl := this.guiObj.AddText("xm y" yPos " w200", scriptName)
                controls.Push(nameCtrl)
                
                ; Status indicator
                statusText := isEnabled ? "ENABLED" : "disabled"
                statusColor := isEnabled ? "0x00AA00" : "0x999999"
                statusCtrl := this.guiObj.AddText("x+10 w80 c" statusColor, statusText)
                statusCtrl.SetFont("bold")
                controls.Push(statusCtrl)
                
                ; Toggle button
                btnText := isEnabled ? "Disable" : "Enable"
                btnCtrl := this.guiObj.AddButton("x+10 w80", btnText)
                btnCtrl.OnEvent("Click", this.MakeToggleHandler(scriptName))
                controls.Push(btnCtrl)
                
                this.scriptControls[scriptName] := controls
                yPos += 30
            }
        }
        
        ; If no scripts found
        if !scriptFound {
            noScriptsCtrl := this.guiObj.AddText("xm y100 w400 c0x999999", "No child scripts registered yet.")
            this.scriptControls["_none"] := [noScriptsCtrl]
        }
        
        ; Buttons section
        this.guiObj.AddText("xm w400", "")  ; Spacer
        this.guiObj.AddButton("xm w120", "Refresh").OnEvent("Click", (*) => this.RefreshScriptList())
        this.guiObj.AddButton("x+10 w120", "View Logs").OnEvent("Click", (*) => NotificationManager.ShowAll())
        this.guiObj.AddButton("x+10 w120", "Exit All").OnEvent("Click", (*) => CleanupAndExit())
        
        ; Status bar
        this.guiObj.AddText("xm w400", "")  ; Spacer
        statusText := this.guiObj.AddText("xm w400", "Ready")
        statusText.SetFont("s9 italic c0x666666")
        
        ; Window close handler
        this.guiObj.OnEvent("Close", (*) => this.guiObj.Hide())
        
        return this.guiObj
    }
    
    static RefreshScriptList() {
        global ControlDir, ChildProcesses
        
        if !this.guiObj
            return
        
        ; Destroy and recreate the entire GUI for a clean refresh
        this.guiObj.Destroy()
        this.guiObj := ""
        this.scriptControls := Map()
        
        ; Recreate the GUI
        this.Create()
        this.guiObj.Show()
    }
    
    static MakeToggleHandler(scriptName) {
        return (*) => (
            ToggleChildScript(scriptName),
            Sleep(100),
            this.RefreshScriptList()
        )
    }
    
    static Show() {
        if !this.guiObj
            this.Create()
        this.RefreshScriptList()
        this.guiObj.Show()
    }
    
    static Hide() {
        if this.guiObj
            this.guiObj.Hide()
    }
    
    static Toggle() {
        if !this.guiObj
            this.Create()
        
        if this.guiObj && WinExist("ahk_id " this.guiObj.Hwnd)
            this.Hide()
        else
            this.Show()
    }
}

; ----------------
; Hotkeys
; ----------------
^!g::StatusGui.Toggle()               ; Ctrl+Alt+G — show/hide status GUI
^!s::ToggleChildScript("spaceclick")  ; Ctrl+Alt+S — toggle spaceclick child script
^!n::NotificationManager.ShowAll()    ; Ctrl+Alt+N — show all notifications
^!m::NotificationManager.ShowMasterOnly()  ; Ctrl+Alt+M — show master notifications only
^!c::NotificationManager.ShowChildrenOnly()  ; Ctrl+Alt+C — show child notifications only
^!e::NotificationManager.ShowErrors()  ; Ctrl+Alt+E — show errors only
Pause::CleanupAndExit()    ; Pause/Break — close all children and exit master

; ----------------
; Functions
; ----------------
ToggleChildScript(name)
{
    global ControlDir
    enabledFile := ControlDir "\enabled\" name ".enabled"
    if FileExist(enabledFile)
    {
        try {
            FileDelete(enabledFile)
            NotificationManager.Log("info", "master", "Disabled child script: " name)
        }
    }
    else
    {
        ; create an empty marker file
        try {
            FileAppend("", enabledFile)
            NotificationManager.Log("info", "master", "Enabled child script: " name)
        }
    }
}

; Launch all registered child scripts
LaunchChildScripts()
{
    global ControlDir
    scriptsDir := ControlDir "\scripts"
    
    ; Get all .info files
    Loop Files, scriptsDir "\*.info"
    {
        ; Read the script path from the info file
        content := FileRead(A_LoopFileFullPath)
        lines := StrSplit(content, "`n")
        
        scriptPath := ""
        for line in lines
        {
            if InStr(line, "path=")
            {
                scriptPath := SubStr(line, 6)  ; Remove "path=" prefix
                scriptPath := Trim(scriptPath)
                break
            }
        }
        
        if scriptPath != "" && FileExist(scriptPath)
        {
            ; Launch the child script with AutoHotkey v2
            ahkExe := "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
            try {
                pid := Run('"' ahkExe '" "' scriptPath '"')
                ; Track the process ID for cleanup
                global ChildProcesses
                ChildProcesses.Push(pid)
                
                scriptName := A_LoopFileName
                scriptName := StrReplace(scriptName, ".info", "")
                NotificationManager.Log("info", "master", "Launched child script: " scriptName " (PID: " pid ")")
            }
            catch as err {
                NotificationManager.Log("error", "master", "Failed to launch " scriptPath ": " err.Message)
            }
        }
    }
}

; Close all child script processes and exit
CleanupAndExit()
{
    global ChildProcesses
    
    NotificationManager.Log("info", "master", "Shutting down - closing " ChildProcesses.Length " child script(s)")
    
    ; Create shutdown marker file to signal children
    shutdownMarker := A_ScriptDir "\control\shutdown.marker"
    try FileAppend("", shutdownMarker)
    
    ; Try multiple methods to close each tracked child process
    for pid in ChildProcesses
    {
        try {
            ; First try graceful close via WM_CLOSE
            if ProcessExist(pid)
            {
                ; Send WM_CLOSE (0x0010) to all windows of this process
                DetectHiddenWindows(true)
                for hwnd in WinGetList("ahk_pid " pid)
                {
                    PostMessage(0x0010, 0, 0,, "ahk_id " hwnd)  ; WM_CLOSE
                }
                Sleep(100)
            }
            
            ; If still running, force close
            if ProcessExist(pid)
            {
                ProcessClose(pid)
                NotificationManager.Log("info", "master", "Force closed child process PID: " pid)
            }
            else
            {
                NotificationManager.Log("info", "master", "Child process PID: " pid " closed gracefully")
            }
        }
        catch as err {
            ; Process might have already closed
            NotificationManager.Log("warning", "master", "Could not close PID " pid ": " err.Message)
        }
    }
    
    ; Brief delay to let processes close
    Sleep(300)
    
    ; Clean up shutdown marker
    try FileDelete(shutdownMarker)
    
    ExitApp
}

; Legacy function kept for compatibility - redirects to NotificationManager
Notify(msg, level := "info")
{
    NotificationManager.Log(level, "master", msg)
}

; On start: brief tray hint (only shown once at startup)
NotificationManager.Log("info", "master", "Master controller started. Hotkeys: Ctrl+Alt+S toggle, Ctrl+Alt+N all notifs, Ctrl+Alt+M master only, Ctrl+Alt+C children only, Ctrl+Alt+E errors")

; Auto-launch child scripts if enabled
if AutoLaunchChildren
{
    Sleep(500)  ; Brief delay to let master fully initialize
    LaunchChildScripts()
}

; --- End of master.ahk ---