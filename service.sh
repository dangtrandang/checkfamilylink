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

# Permanent Bubble & Overlay Block: Disable bubbles and overlays globally on boot
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

# Reset boot state: unsuspend all apps and flush rules to prevent lockout
if [ -f "$MODDIR/unlock.sh" ]; then
    log -t "$TAG" "Initializing boot state: unsuspending all applications..."
    sh "$MODDIR/unlock.sh" &
fi

log -t "$TAG" "Module service started. Monitoring logcat..."

# Watcher Loop
DEBOUNCE_DELAY=10
LAST_LOCK_TIME=0
LAST_UNLOCK_TIME=0

while true; do
    log -t "$TAG" "Starting logcat watcher..."
    
    logcat -v brief 2>/dev/null | while read -r line; do
        # Match TimeLimitCheckingIntent logs
        if echo "$line" | grep -q "TimeLimitCheckingIntent"; then
            # Verify unlock event FIRST to prevent substring matching conflict ("unlocking" contains "locking")
            if echo "$line" | grep -q "unlocking device"; then
                log -t "$TAG" "MATCH FOUND: unlocking device"
                CURRENT_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "UNLOCKED")
                current_time=$(date +%s)
                time_diff=$((current_time - LAST_UNLOCK_TIME))
                
                # Self-healing: trigger unlock if out of sync, or if it's been more than 10s
                if [ "$CURRENT_STATE" != "UNLOCKED" ] || [ "$time_diff" -ge "$DEBOUNCE_DELAY" ]; then
                    LAST_UNLOCK_TIME=$current_time
                    echo "UNLOCKED" > "$STATE_FILE"
                    log -t "$TAG" "Transition to UNLOCKED state"
                    if [ -f "$MODDIR/unlock.sh" ]; then
                        sh "$MODDIR/unlock.sh" &
                    else
                        log -t "$TAG" "Error: unlock.sh not found at $MODDIR/unlock.sh"
                    fi
                fi
            # Verify lock event (only matched if it doesn't contain "unlocking device")
            elif echo "$line" | grep -q "locking device"; then
                log -t "$TAG" "MATCH FOUND: locking device"
                CURRENT_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "UNLOCKED")
                current_time=$(date +%s)
                time_diff=$((current_time - LAST_LOCK_TIME))
                
                # Self-healing: trigger lock if out of sync, or if it's been more than 10s
                if [ "$CURRENT_STATE" != "LOCKED" ] || [ "$time_diff" -ge "$DEBOUNCE_DELAY" ]; then
                    LAST_LOCK_TIME=$current_time
                    echo "LOCKED" > "$STATE_FILE"
                    log -t "$TAG" "Transition to LOCKED state"
                    if [ -f "$MODDIR/cleanup.sh" ]; then
                        sh "$MODDIR/cleanup.sh" &
                    else
                        log -t "$TAG" "Error: cleanup.sh not found at $MODDIR/cleanup.sh"
                    fi
                fi
            fi
        fi
    done
    
    log -t "$TAG" "Warning: logcat watcher exited. Restarting in 5 seconds..."
    sleep 5
done
