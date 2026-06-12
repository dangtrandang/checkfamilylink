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

# Enforce permanent bubble block (disables notification bubbles globally)
settings put secure notification_bubbles 0 >/dev/null 2>&1

# 2. Whitelist Setup
# Whitelist default system packages
EXCLUDED_PACKAGES="com.google.android.gms com.google.android.apps.kids.familylinkhelper com.miui.home com.familylock.module com.android.vending com.google.android.gsf"

# Read user-defined whitelist file from /data/adb/
WHITELIST_FILE="/data/adb/familylock_whitelist.txt"
if [ -f "$WHITELIST_FILE" ]; then
    while read -r line; do
        # Trim leading/trailing whitespace
        line=$(echo "$line" | xargs)
        [ -z "$line" ] && continue
        # Skip comment lines starting with #
        echo "$line" | grep -q "^#" && continue
        
        EXCLUDED_PACKAGES="$EXCLUDED_PACKAGES $line"
    done < "$WHITELIST_FILE"
fi

# 3. Force-stop, Suspend, and Firewall all user applications (Third-party only via -3)
log -t "$TAG" "Applying double-layer lock on user applications..."
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
        log -t "$TAG" "Locking app: $pkg"
        
        # Block overlays/bubbles (including custom MIUI pop-ups)
        appops set "$pkg" SYSTEM_ALERT_WINDOW ignore >/dev/null 2>&1
        appops set "$pkg" 10020 ignore >/dev/null 2>&1
        appops set "$pkg" 10021 ignore >/dev/null 2>&1
        
        # Force-stop
        am force-stop "$pkg" >/dev/null 2>&1
        
        # Suspend (grey out icon)
        pm suspend "$pkg" >/dev/null 2>&1
        
        # Firewall drop via Linux UID (camps internet connection at kernel level)
        app_id=$(grep "^$pkg " /data/system/packages.list 2>/dev/null | awk '{print $2}')
        if [ -z "$app_id" ]; then
            # Fallback to stat if packages.list is not readable or not found
            app_id=$(stat -c %u "/data/data/$pkg" 2>/dev/null)
            if [ -n "$app_id" ]; then
                app_id=$((app_id % 100000))
            fi
        fi
        
        if [ -n "$app_id" ]; then
            # Find all active users (to block for user 0, user 999 Dual Apps, etc.)
            users=$(pm list users | grep -oE '\{[0-9]+:' | tr -d '{:')
            for user in $users; do
                uid=$((user * 100000 + app_id))
                
                # Remove existing matching rule first to avoid duplicates
                iptables -D OUTPUT -m owner --uid-owner "$uid" -j DROP >/dev/null 2>&1
                ip6tables -D OUTPUT -m owner --uid-owner "$uid" -j DROP >/dev/null 2>&1
                
                # Inject drop rules
                iptables -I OUTPUT -m owner --uid-owner "$uid" -j DROP >/dev/null 2>&1
                ip6tables -I OUTPUT -m owner --uid-owner "$uid" -j DROP >/dev/null 2>&1
            done
        fi
    fi
done

log -t "$TAG" "FamilyLockModule: CLEANUP COMPLETE"
