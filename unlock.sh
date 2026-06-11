#!/system/bin/sh
# Family Link Lock Cleanup - unlock.sh
# This script is executed when "unlocking device" is detected.

TAG="FamilyLockModule"

log -t "$TAG" "FamilyLockModule: UNLOCK DETECTED"

# Unsuspend all user applications (Third-party only via -3)
EXCLUDED_PACKAGES="com.google.android.gms com.google.android.apps.kids.familylinkhelper com.miui.home com.familylock.module com.android.vending com.google.android.gsf"

log -t "$TAG" "Unsuspending user applications..."
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
        log -t "$TAG" "Unsuspending: $pkg"
        pm unsuspend "$pkg" >/dev/null 2>&1
    fi
done
