#!/system/bin/sh
# Magisk Late Start Service Script
# Family Link Lock Cleanup Module

# Ensure boot has completed
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
done

# Wait extra time to let GMS and system services stabilize
sleep 10

TAG="FamilyLockModule"
MODDIR="/data/adb/modules/familylink-cleanup"

# Fallback to the current script's directory if the module directory does not exist
if [ ! -d "$MODDIR" ]; then
    MODDIR=$(dirname "$0")
fi

# Initialize State Machine File in /data/adb (safely resets to UNLOCKED on boot)
STATE_FILE="/data/adb/familylock_state"
echo "UNLOCKED" > "$STATE_FILE"

# Start the local Web UI server on port 8080
BUSYBOX="/data/adb/magisk/busybox"
if [ ! -f "$BUSYBOX" ]; then
    BUSYBOX="busybox"
fi

if [ -d "$MODDIR/webroot" ]; then
    log -t "$TAG" "Starting Web UI server on port 8080..."
    # Ensure correct permissions for the webroot and cgi-bin
    chmod -R 755 "$MODDIR/webroot"
    # Kill any existing server on port 8080 to prevent conflicts
    pkill -f "httpd -p 8080" >/dev/null 2>&1
    # Start server
    $BUSYBOX httpd -p 8080 -h "$MODDIR/webroot" >/dev/null 2>&1
else
    log -t "$TAG" "Warning: webroot not found at $MODDIR/webroot"
fi

# Permanent Bubble Block: Disable notification bubbles globally on boot
log -t "$TAG" "Disabling notification bubbles globally..."
settings put secure notification_bubbles 0 >/dev/null 2>&1

log -t "$TAG" "Initializing AppOps overlay restrictions..."
EXCLUDED_PACKAGES="com.google.android.gms com.google.android.apps.kids.familylinkhelper com.miui.home com.familylock.module com.android.vending com.google.android.gsf"
WHITELIST_FILE="/data/adb/familylock_whitelist.txt"
if [ -f "$WHITELIST_FILE" ]; then
    while read -r line; do
        line=$(echo "$line" | xargs)
        [ -z "$line" ] && continue
        echo "$line" | grep -q "^#" && continue
        EXCLUDED_PACKAGES="$EXCLUDED_PACKAGES $line"
    done < "$WHITELIST_FILE"
fi

packages=$(pm list packages -3 | cut -d: -f2)
for pkg in $packages; do
    [ -z "$pkg" ] && continue
    exclude=false
    for expkg in $EXCLUDED_PACKAGES; do
        if [ "$pkg" = "$expkg" ]; then
            exclude=true
            break
        fi
    done
    if [ "$exclude" = false ]; then
        appops set "$pkg" SYSTEM_ALERT_WINDOW ignore >/dev/null 2>&1
        appops set "$pkg" 10020 ignore >/dev/null 2>&1
        appops set "$pkg" 10021 ignore >/dev/null 2>&1
    else
        appops set "$pkg" SYSTEM_ALERT_WINDOW default >/dev/null 2>&1
        appops set "$pkg" 10020 default >/dev/null 2>&1
        appops set "$pkg" 10021 default >/dev/null 2>&1
    fi
done

# Start background overlay/popup enforcer loop to prevent users/apps from manually granting/enabling overlay permissions
(
    while true; do
        sleep 5
        
        # Read whitelist
        EXCLUDED_PACKAGES="com.google.android.gms com.google.android.apps.kids.familylinkhelper com.miui.home com.familylock.module com.android.vending com.google.android.gsf"
        WHITELIST_FILE="/data/adb/familylock_whitelist.txt"
        if [ -f "$WHITELIST_FILE" ]; then
            while read -r line; do
                line=$(echo "$line" | xargs)
                [ -z "$line" ] && continue
                echo "$line" | grep -q "^#" && continue
                EXCLUDED_PACKAGES="$EXCLUDED_PACKAGES $line"
            done < "$WHITELIST_FILE"
        fi
        
        # Query currently allowed overlay permissions
        allowed_apps=$(appops query-op SYSTEM_ALERT_WINDOW allow 2>/dev/null)
        allowed_apps="$allowed_apps $(appops query-op 10020 allow 2>/dev/null)"
        allowed_apps="$allowed_apps $(appops query-op 10021 allow 2>/dev/null)"
        
        # Sort and deduplicate
        unique_apps=$(echo $allowed_apps | tr ' ' '\n' | sort -u)
        
        for pkg in $unique_apps; do
            [ -z "$pkg" ] && continue
            
            # Check if it is a user app installed in /data
            if pm path "$pkg" 2>/dev/null | grep -q "^package:/data/"; then
                # Check exclusion list
                exclude=false
                for expkg in $EXCLUDED_PACKAGES; do
                    if [ "$pkg" = "$expkg" ]; then
                        exclude=true
                        break
                    fi
                done
                
                if [ "$exclude" = false ]; then
                    log -t "$TAG" "Auto-enforcing overlay block on user app: $pkg"
                    appops set "$pkg" SYSTEM_ALERT_WINDOW ignore >/dev/null 2>&1
                    appops set "$pkg" 10020 ignore >/dev/null 2>&1
                    appops set "$pkg" 10021 ignore >/dev/null 2>&1
                    
                    # Force stop immediately to dismiss any active floating windows/bubbles
                    am force-stop "$pkg" >/dev/null 2>&1
                fi
            fi
        done
    done
) &
