#!/system/bin/sh
# Family Link Lock Cleanup - unlock.sh
# This script is executed when "unlocking device" is detected.

TAG="FamilyLockModule"

log -t "$TAG" "FamilyLockModule: UNLOCK DETECTED"

# 1. Unsuspend all user applications (Third-party only via -3)
# 2. Clear iptables firewall drop rules for user app UIDs
log -t "$TAG" "Unsuspending and restoring internet access for user applications..."
packages=$(pm list packages -3 | cut -d: -f2)
for pkg in $packages; do
    [ -z "$pkg" ] && continue
    
    # Always try to unsuspend the package (safe to run even if not suspended)
    pm unsuspend "$pkg" >/dev/null 2>&1
    
    # Always try to remove firewall drop rules
    uid=$(stat -c %u "/data/data/$pkg" 2>/dev/null)
    if [ -n "$uid" ]; then
        iptables -D OUTPUT -m owner --uid-owner "$uid" -j DROP >/dev/null 2>&1
        ip6tables -D OUTPUT -m owner --uid-owner "$uid" -j DROP >/dev/null 2>&1
    fi
done
