#!/system/bin/sh
# Family Link Lock Cleanup - cleanup.sh
# This script is executed when "locking device" is detected.

TAG="FamilyLockModule"

log -t "$TAG" "FamilyLockModule: LOCK DETECTED"
log -t "$TAG" "FamilyLockModule: CLEANUP START"

# 1. Return to Home screen first
log -t "$TAG" "Returning to Home screen..."
am start -a android.intent.action.MAIN -c android.intent.category.HOME >/dev/null 2>&1
input keyevent 3 >/dev/null 2>&1

# Sleep 1 second to ensure transition home completes and stabilizes
sleep 1

# 2. Force-stop and Suspend all user applications (Third-party only via -3)
EXCLUDED_PACKAGES="com.google.android.gms com.google.android.apps.kids.familylinkhelper com.miui.home com.familylock.module com.android.vending com.google.android.gsf"

log -t "$TAG" "Force-stopping and suspending user applications..."
packages=$(pm list packages -3 | cut -d: -f2)
for pkg in $packages; do
    [ -z "$pkg" ] && continue
    
    # Check exclusion list
    exclude=false
    for expkg in $EXCLUDED_PACKAGES; do
        if [ "$pkg" = "$expkg" ]; then
            exclude=true
            break
        fi
    done
    
    if [ "$exclude" = false ]; then
        log -t "$TAG" "Stopping and suspending: $pkg"
        am force-stop "$pkg" >/dev/null 2>&1
        pm suspend "$pkg" >/dev/null 2>&1
    fi
done

log -t "$TAG" "FamilyLockModule: CLEANUP COMPLETE"
