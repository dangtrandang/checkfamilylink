# Family Link Lock Cleanup Magisk Module

This is a Magisk module designed for rooted Android devices to handle issues related to overlay, bubbles, or task persistence when Google Family Link locks the device (bedtime, daily limit, or parent manual lock).

---

## Features

- **Automated Background Service**: Starts automatically on boot (`service.sh` runs late-start service mode as root).
- **Precise Log Filtering**: Watches for log lines containing BOTH `TimeLimitCheckingIntent` and `locking device` / `unlocking device` to avoid false triggers on generic text.
- **State Machine Debouncing**: Tracks state (`LOCKED` / `UNLOCKED`) via `/data/adb/familylock_state` (safely initialized on boot). This ensures that cleanup runs exactly once per lock cycle, even if Google Play Services logs the event multiple times.
- **Double-Layer Lock Protection**:
  When the device is locked, all non-whitelisted third-party apps will be:
  1. Terminated (`am force-stop`).
  2. Suspended (`pm suspend`), greying out their launcher icons and completely blocking floating windows / Game Turbo bypasses.
  3. Firewalled (`iptables` / `ip6tables` drop rules targeting the app's Linux UID), blocking internet at the kernel level.
- **Whitelisting System**: System default critical packages (GMS, Play Store, GSF, Family Link Helper, MIUI Home launcher) are always excluded. You can configure custom whitelisted apps (e.g. Duolingo) dynamically.
- **Local Web UI Control Panel**: Spawns a background mini web server using Magisk's built-in `busybox httpd` on port `8080` (uses < 2MB RAM and 0% CPU when idle).
- **Launcher App Icon Shortcut**: Chrome -> "Add to Home Screen" turns the Web UI into a full-screen application on your launcher.

---

## File Structure

```text
checkfamilylink/
├── module.prop         # Module information and metadata
├── service.sh          # Late-start service to monitor logcat and start Web UI server
├── cleanup.sh          # Called when "locking device" is detected (forces stop, suspends, & firewalls apps)
├── unlock.sh           # Called when "unlocking device" is detected (unsuspends and unblocks apps)
├── post-fs-data.sh     # Runs during post-fs-data hook (logs boot initialization)
├── uninstall.sh        # Runs when the module is removed (kills server and cleans config files)
├── webroot/
│   ├── index.html      # Premium dark-theme HTML/JS whitelist controller Web UI
│   └── cgi-bin/
│       └── api.sh      # CGI API to query installed packages and toggle whitelist status
└── README.md           # This documentation
```

---

## How to Access & Manage Whitelist (Web UI)

1. Open Chrome on the device and navigate to `http://localhost:8080`.
2. A premium list of all user-installed applications will be displayed. Toggle the switch to whitelist/allow an app to run during lock.
3. **Add Launcher Icon Shortcut**:
   - In Chrome, click the three vertical dots (menu) in the top-right corner.
   - Select **"Add to Home screen"** (Thêm vào màn hình chính).
   - Chrome will place an icon on your home screen. Tapping it opens the panel in full-screen, acting exactly like a native app.

*Note: Custom whitelists are saved dynamically in `/data/adb/familylock_whitelist.txt`.*

---

## Logging

All logs are tagged with `FamilyLockModule`. You can watch the module's actions in real-time by running:

```bash
adb shell "logcat | grep FamilyLockModule"
```

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
