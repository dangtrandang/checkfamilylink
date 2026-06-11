#!/system/bin/sh
# Magisk Uninstall Script
# Family Link Lock Cleanup Module

# This script runs when Magisk uninstalls the module.
# Clean up the persistent state file
rm -f /data/adb/familylock_state

log -t FamilyLockModule "Module uninstalled and state file cleaned up."
