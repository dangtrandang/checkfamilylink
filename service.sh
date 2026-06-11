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

# Reset boot state: unsuspend all apps and flush rules to prevent lockout
if [ -f "$MODDIR/unlock.sh" ]; then
    log -t "$TAG" "Initializing boot state: unsuspending all applications..."
    sh "$MODDIR/unlock.sh" &
fi

log -t "$TAG" "Module service started. Monitoring logcat..."

# Watcher Loop
while true; do
    log -t "$TAG" "Starting logcat watcher..."
    
    logcat -v brief 2>/dev/null | while read -r line; do
        # Match TimeLimitCheckingIntent logs
        if echo "$line" | grep -q "TimeLimitCheckingIntent"; then
            # Verify unlock event FIRST to prevent substring matching conflict ("unlocking" contains "locking")
            if echo "$line" | grep -q "unlocking device"; then
                log -t "$TAG" "MATCH FOUND: unlocking device"
                CURRENT_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "UNLOCKED")
                if [ "$CURRENT_STATE" != "UNLOCKED" ]; then
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
                if [ "$CURRENT_STATE" != "LOCKED" ]; then
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
