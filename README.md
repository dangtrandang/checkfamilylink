# Family Link Lock Cleanup Magisk Module

This is a Magisk module designed for rooted Android devices to handle issues related to overlay, bubbles, or task persistence when Google Family Link locks the device.

## Why this is needed

When Google Family Link locks the device, Google Play Services log:
- **Lock**: `TimeLimitCheckingIntent: locking device`
- **Unlock**: `TimeLimitCheckingIntent: unlocking device`

Some apps might still keep their tasks alive or display overlays/bubbles. This module listens to logcat continuously to capture these logs and cleanly routes the device to the Home screen, force-stops user apps, and removes recent tasks.

---

## Features

- **Automated Startup**: Starts automatically on boot (`service.sh` runs late-start service mode as root).
- **Precise Log Filtering**: Watches for log lines containing BOTH `TimeLimitCheckingIntent` and `locking device` / `unlocking device` to avoid false triggers on generic text.
- **State Machine Debouncing**: Tracks state (`LOCKED` / `UNLOCKED`) via `/data/adb/familylock_state` (safely initialized on boot). This ensures that cleanup runs exactly once per lock cycle, even if Google Play Services logs the event multiple times.
- **Robust Cleanup Logic**:
  1. Sends the device back to the Home screen (`input keyevent KEYCODE_HOME`).
  2. Sleeps for 1 second to stabilize the Home screen transition.
  3. Force-stops all third-party applications (excluding whitelisted components).
  4. Suspends all third-party packages using `pm suspend` to grey them out and block Game Turbo / floating window bypasses.
- **Exclusion List**: Restricts stopping to third-party user apps only (`pm list packages -3`) and whitelists critical components:
  - `com.google.android.gms` (GMS)
  - `com.google.android.gsf` (Google Services Framework)
  - `com.android.vending` (Google Play Store)
  - `com.google.android.apps.kids.familylinkhelper` (Family Link Helper)
  - `com.miui.home` (MIUI Launcher - customize in scripts if using a different launcher)
  - `com.familylock.module` (Module exclusion)
- **Logcat Watcher**: Continuously monitors system logcat. If the logcat process dies, it automatically restarts within 5 seconds.

---

## File Structure

```text
checkfamilylink/
├── module.prop         # Module information and metadata
├── service.sh          # Late-start service to monitor logcat in the background
├── cleanup.sh          # Called when "locking device" is detected (forces stop & suspends apps)
├── unlock.sh           # Called when "unlocking device" is detected (unsuspends apps)
├── post-fs-data.sh     # Runs during post-fs-data hook (logs boot initialization)
├── uninstall.sh        # Runs when the module is removed
└── README.md           # This documentation
```

---

## Logging

All logs are tagged with `FamilyLockModule`. You can watch the module's actions in real-time by running:

```bash
adb shell "logcat | grep FamilyLockModule"
```

### Key Log Events to Expect
- On Lock (only on transition from UNLOCKED to LOCKED):
  `FamilyLockModule: MATCH FOUND: locking device`
  `FamilyLockModule: Transition to LOCKED state`
  `FamilyLockModule: FamilyLockModule: LOCK DETECTED`
  `FamilyLockModule: FamilyLockModule: CLEANUP START`
  `FamilyLockModule: Force-stopping and suspending user applications...`
  `FamilyLockModule: Stopping and suspending: com.example.userapp`
  `FamilyLockModule: FamilyLockModule: CLEANUP COMPLETE`
- On Unlock (only on transition from LOCKED to UNLOCKED):
  `FamilyLockModule: MATCH FOUND: unlocking device`
  `FamilyLockModule: Transition to UNLOCKED state`
  `FamilyLockModule: FamilyLockModule: UNLOCK DETECTED`
  `FamilyLockModule: Unsuspending user applications...`

---

## Installation

1. Compress the directory contents into a ZIP file (make sure `module.prop` is in the root of the ZIP file):
   ```bash
   zip -r FamilyLinkLockCleanup.zip *
   ```
2. Transfer the `FamilyLinkLockCleanup.zip` file to your Android device.
3. Open the **Magisk Manager** app (or KernelSU/APatch manager).
4. Go to **Modules** -> **Install from storage** and select `FamilyLinkLockCleanup.zip`.
5. Reboot your device.
