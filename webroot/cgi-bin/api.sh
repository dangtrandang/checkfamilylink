#!/system/bin/sh
# Family Link Lock Cleanup - api.sh CGI Script
# Handles HTTP API requests for whitelisting applications

echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo "Cache-Control: no-cache, no-store, must-revalidate"
echo ""

# Parse QUERY_STRING parameters (e.g. action=list&pw=meocon0301)
ACTION=$(echo "$QUERY_STRING" | grep -oE "action=[a-zA-Z0-9_]+" | cut -d= -f2)
PACKAGE=$(echo "$QUERY_STRING" | grep -oE "package=[a-zA-Z0-9._]+" | cut -d= -f2)
PW=$(echo "$QUERY_STRING" | grep -oE "pw=[a-zA-Z0-9_]+" | cut -d= -f2)

if [ "$PW" != "meocon0301" ]; then
    echo "{"
    echo "  \"status\": \"error\","
    echo "  \"message\": \"Unauthorized: Invalid password\""
    echo "}"
    exit 0
fi

WHITELIST_FILE="/data/adb/familylock_whitelist.txt"

# Whitelist default system packages
EXCLUDED_PACKAGES="com.google.android.gms com.google.android.apps.kids.familylinkhelper com.miui.home com.familylock.module com.android.vending com.google.android.gsf"

is_whitelisted() {
    # Check default exclusion packages
    for expkg in $EXCLUDED_PACKAGES; do
        if [ "$1" = "$expkg" ]; then
            return 0 # true
        fi
    done
    
    # Check user-configured whitelist
    if [ -f "$WHITELIST_FILE" ]; then
        if grep -q "^$1$" "$WHITELIST_FILE"; then
            return 0 # true
        fi
    fi
    return 1 # false
}

# Ensure whitelist file exists
touch "$WHITELIST_FILE"

if [ "$ACTION" = "list" ]; then
    # Return JSON containing only apps requesting overlay permission and their status
    echo "{"
    echo "  \"status\": \"success\","
    echo "  \"apps\": ["
    
    first=true
    # Query installed third-party apps
    pm list packages -3 | cut -d: -f2 | sort | while read -r pkg; do
        [ -z "$pkg" ] && continue
        
        # Only include apps that declare/request the overlay permission
        if dumpsys package "$pkg" 2>/dev/null | grep -q "android.permission.SYSTEM_ALERT_WINDOW"; then
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi
            
            # Check if whitelisted in our module
            if is_whitelisted "$pkg"; then
                whitelisted="true"
            else
                whitelisted="false"
            fi
            
            # Check if currently active/enabled in AppOps
            op_status=$(appops get "$pkg" SYSTEM_ALERT_WINDOW 2>/dev/null)
            if echo "$op_status" | grep -qE "ignore|deny"; then
                enabled="false"
            else
                enabled="true"
            fi
            
            echo "    { \"package\": \"$pkg\", \"whitelisted\": $whitelisted, \"enabled\": $enabled }"
        fi
    done
    
    echo "  ]"
    echo "}"

elif [ "$ACTION" = "toggle" ] && [ -n "$PACKAGE" ]; then
    # Toggle user-configured whitelist status for a package
    # Check if it is a system default package (cannot toggle/remove system packages)
    is_system=false
    for expkg in $EXCLUDED_PACKAGES; do
        if [ "$PACKAGE" = "$expkg" ]; then
            is_system=true
            break
        fi
    done
    
    if [ "$is_system" = false ]; then
        if grep -q "^$PACKAGE$" "$WHITELIST_FILE"; then
            # Remove from whitelist
            grep -v "^$PACKAGE$" "$WHITELIST_FILE" > "${WHITELIST_FILE}.tmp"
            mv "${WHITELIST_FILE}.tmp" "$WHITELIST_FILE"
            status="removed"
            # Immediately block overlays/bubbles (including custom MIUI pop-ups)
            appops set "$PACKAGE" SYSTEM_ALERT_WINDOW ignore >/dev/null 2>&1
            appops set "$PACKAGE" 10020 ignore >/dev/null 2>&1
            appops set "$PACKAGE" 10021 ignore >/dev/null 2>&1
        else
            # Add to whitelist
            echo "$PACKAGE" >> "$WHITELIST_FILE"
            status="added"
            # Immediately restore overlays/bubbles to default
            appops set "$PACKAGE" SYSTEM_ALERT_WINDOW default >/dev/null 2>&1
            appops set "$PACKAGE" 10020 default >/dev/null 2>&1
            appops set "$PACKAGE" 10021 default >/dev/null 2>&1
        fi
        echo "{ \"status\": \"success\", \"package\": \"$PACKAGE\", \"action\": \"$status\" }"
    else
        echo "{ \"status\": \"error\", \"message\": \"Cannot modify system default packages\" }"
    fi
else
    echo "{ \"status\": \"error\", \"message\": \"Invalid action or missing package parameters\" }"
fi
