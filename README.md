# AutoHotkey Master Controller

> **💡 Sample Project**: This is a demonstration project designed to provide inspiration and architectural ideas for managing multiple AutoHotkey scripts through a centralized master controller. Use it as a reference implementation, learning tool, or starting point for your own automation workflows. The patterns and techniques shown here can be adapted and extended to fit your specific needs.

A centralized control system for managing multiple AutoHotkey v2 automation scripts with a unified GUI, notification system, and coordinated lifecycle management.

## 🎯 Project Scope

This project provides a **master/child architecture** for organizing and controlling AutoHotkey automation scripts. Instead of running multiple independent scripts that are difficult to track and manage, this system offers:

- **Centralized Control**: One master script manages all your automation scripts
- **Visual Dashboard**: GUI showing all registered scripts with toggle controls
- **Coordinated Lifecycle**: Auto-launch child scripts on startup, clean shutdown on exit
- **Unified Notifications**: All scripts log to a single notification system with filtering
- **File-Based IPC**: Simple, reliable communication via marker files

## 🏗️ Architecture

### Master Script (`master.ahk`)
The controller that:
- Discovers and launches registered child scripts
- Provides a status GUI with enable/disable toggles
- Manages a centralized notification system
- Handles clean shutdown of all child processes
- Tracks process IDs for reliable cleanup

### Child Scripts (e.g., `spaceclick.ahk`)
Individual automation scripts that:
- Register themselves with the master on startup
- Monitor enable/disable state via marker files
- Send notifications to the master's log
- Exit gracefully when signaled by the master

### Control Directory Structure
```
control/
├── scripts/
│   └── spaceclick.info         # Registration files (name + path)
├── enabled/
│   └── spaceclick.enabled      # Marker files (exist = enabled)
├── notifications.txt           # Unified log file
└── shutdown.marker            # Temporary shutdown signal
```

## ✨ Features

### Master Script Features
- **Auto-Launch**: Automatically starts all registered child scripts on master startup
- **Status GUI**: Visual dashboard showing script status with toggle buttons
- **Notification Manager**: Centralized logging with levels (info/warning/error)
- **Filter Views**: Show all logs, master-only, children-only, or errors-only
- **Clean Shutdown**: Gracefully closes all child processes on exit
- **Process Tracking**: Maintains PIDs for reliable cleanup

### Hotkeys (Master)
- `Ctrl+Alt+G` — Toggle status GUI
- `Ctrl+Alt+S` — Toggle spaceclick script
- `Ctrl+Alt+N` — Show all notifications
- `Ctrl+Alt+M` — Show master notifications only
- `Ctrl+Alt+C` — Show child notifications only
- `Ctrl+Alt+E` — Show errors only
- `Pause` — Exit master and close all children

## 📝 How to Create a Child Script

Child scripts follow a standard pattern. Here's how `spaceclick.ahk` implements it:

### 1. Runtime Version Guard
```ahk
#Requires AutoHotkey v2.0
if SubStr(A_AhkVersion, 1, 1) != "2"
{
    MsgBox("This script requires AutoHotkey v2.x...")
    ExitApp
}
```

### 2. Setup Control Directory
```ahk
ControlDir := A_ScriptDir "\control"
DirCreate(ControlDir)
DirCreate(ControlDir "\enabled")
DirCreate(ControlDir "\scripts")
```

### 3. Register with Master
```ahk
regFile := ControlDir "\scripts\spaceclick.info"
regText := "name=spaceclick`npath=" A_ScriptFullPath "`n"
try FileDelete(regFile)
FileAppend(regText, regFile)
```

### 4. Create Notification Helper
```ahk
NotifyMaster(msg, level := "info")
{
    global ControlDir
    ts := A_Now
    scriptName := "spaceclick"
    
    line := ts "`t[" level "]`t[" scriptName "]`t" msg "`n"
    try FileAppend(line, ControlDir "\notifications.txt")
    
    switch level {
        case "info":
            TrayTip("[" scriptName "]", msg, 2)
        case "warning":
            TrayTip("[" scriptName "] WARNING", msg, 3)
        case "error":
            TrayTip("[" scriptName "] ERROR", msg, 5)
    }
}
```

### 5. Monitor Enable State
```ahk
enabledMarker := ControlDir "\enabled\spaceclick.enabled"
shutdownMarker := ControlDir "\shutdown.marker"
wasEnabled := false

; Setup your hotkeys as disabled initially
Hotkey("Space", SpaceClickHandler, "Off")

; Check enabled state every 500ms
SetTimer(CheckEnabled, 500)
SetTimer(CheckShutdown, 250)

CheckShutdown()
{
    global shutdownMarker
    if FileExist(shutdownMarker)
    {
        NotifyMaster("Exiting: Shutdown signal received from master", "info")
        ExitApp
    }
}

CheckEnabled()
{
    global enabledMarker, wasEnabled
    
    enabled := FileExist(enabledMarker)
    
    if enabled && !wasEnabled
    {
        Hotkey("Space", "On")
        NotifyMaster("Toggled ON by master (Space->Click active)", "info")
        wasEnabled := true
    }
    else if !enabled && wasEnabled
    {
        Hotkey("Space", "Off")
        NotifyMaster("Toggled OFF by master (Space->Click inactive)", "info")
        wasEnabled := false
    }
}
```

### 6. Implement Your Automation
```ahk
SpaceClickHandler(*)
{
    global WinFilter
    if WinFilter == "" || WinActive(WinFilter)
    {
        Click  ; Send left mouse click
    }
    else
    {
        Send("{Space}")  ; Pass through if window doesn't match
    }
}
```

### 7. Add Manual Exit Support
```ahk
Pause:: {
    NotifyMaster("Exiting: Manual exit via Pause key", "info")
    ExitApp
}
```

### 8. Send Startup Notification
```ahk
NotifyMaster("Started: Waiting for master to enable", "info")
```

## 🚀 Getting Started

### Requirements
- AutoHotkey v2.0+ installed at `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`

### Quick Start
1. Run `master.ahk`
2. Master will auto-launch all registered child scripts (like `spaceclick`)
3. Press `Ctrl+Alt+G` to open the status GUI
4. Use toggle buttons to enable/disable scripts
5. Press `Pause` to exit master and close all children

## 📊 Notification System

All scripts log to `control\notifications.txt` with this format:
```
[Timestamp]    [Level]    [Source]    [Message]
```

Example log entries:
```
20251026143052    [info]    [master]    Launched child script: spaceclick (PID: 12345)
20251026143053    [info]    [spaceclick]    Started: Waiting for master to enable
20251026143055    [info]    [master]    Enabled child script: spaceclick
20251026143055    [info]    [spaceclick]    Toggled ON by master (Space->Click active)
```

### Notification Levels
- **info**: Normal operation events
- **warning**: Non-critical issues
- **error**: Failures or critical problems

## 🔧 Configuration

### Adding a New Child Script
1. Copy the child script pattern from `spaceclick.ahk`
2. Change the script name in registration and notifications
3. Implement your custom automation logic
4. Run the child script once to register it
5. Restart master to auto-launch the new script

### Customizing spaceclick
Edit these settings in `spaceclick.ahk`:
```ahk
; Scope to specific window or leave empty for global
WinFilter := ""  ; e.g., "ahk_exe notepad.exe"
```

## 🛠️ Files

- **master.ahk** — Master controller script
- **spaceclick.ahk** — Example child script (Space → Left Click)
- **control/** — Generated directory for IPC and state management

## 🔮 Future Enhancements

Potential features for future development:
- Persistent enable/disable state across restarts
- Profile system (Gaming, Work, Coding presets)
- Global pause/resume for all scripts
- Performance monitoring and statistics
- Auto-start with Windows
- Child script template generator

## 📄 License

This is a personal automation project. Use and modify as needed for your own automation workflows.

## 🤝 Contributing

This is a personal project, but feel free to fork and adapt the architecture for your own AutoHotkey automation needs!

---

**Note**: All scripts require AutoHotkey v2.0+. The architecture uses file-based IPC for simplicity and reliability, avoiding complex inter-process communication mechanisms.
