#!/system/bin/sh
# Magisk Uninstall Script
# Family Link Lock Cleanup Module

# This script runs when Magisk uninstalls the module.
# 1. Kill the Web UI server
pkill -f "httpd -p 8080" >/dev/null 2>&1

# 2. Restore notification bubbles back to default (1)
settings put secure notification_bubbles 1 >/dev/null 2>&1

# 3. Clean up persistent files
rm -f /data/adb/familylock_state
rm -f /data/adb/familylock_whitelist.txt

log -t FamilyLockModule "Module uninstalled. Web UI stopped, notification bubbles restored, and persistent configs cleaned up."
