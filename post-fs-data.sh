#!/system/bin/sh
# Magisk post-fs-data Script
# Family Link Lock Cleanup Module

# This script runs in post-fs-data mode (before system services start).
# No initialization tasks are needed for this module, but we log the boot hook.

log -t FamilyLockModule "post-fs-data hook executed"
