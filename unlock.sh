#!/system/bin/sh
# Family Link Lock Cleanup - unlock.sh
# This script is executed when "unlocking device" is detected.

TAG="FamilyLockModule"

log -t "$TAG" "FamilyLockModule: UNLOCK DETECTED"

# 1. Unsuspend all user applications (Third-party only via -3)
# 2. Clear iptables firewall drop rules for all active users' UIDs
log -t "$TAG" "Unsuspending and restoring internet access for user applications..."
packages=$(pm list packages -3 | cut -d: -f2)
users=$(pm list users | grep -oE '\{[0-9]+:' | tr -d '{:')

for pkg in $packages; do
    [ -z "$pkg" ] && continue
    
    app_id=$(grep "^$pkg " /data/system/packages.list 2>/dev/null | awk '{print $2}')
    if [ -z "$app_id" ]; then
        app_id=$(stat -c %u "/data/data/$pkg" 2>/dev/null)
        if [ -n "$app_id" ]; then
            app_id=$((app_id % 100000))
        fi
    fi
    
    for user in $users; do
        # Unsuspend the package for all users
        pm unsuspend --user "$user" "$pkg" >/dev/null 2>&1
        
        # Remove firewall drop rules for all user UIDs
        if [ -n "$app_id" ]; then
            uid=$((user * 100000 + app_id))
            iptables -D OUTPUT -m owner --uid-owner "$uid" -j DROP >/dev/null 2>&1
            ip6tables -D OUTPUT -m owner --uid-owner "$uid" -j DROP >/dev/null 2>&1
        fi
    done
done
