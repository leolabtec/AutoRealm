#!/bin/bash

CONFIG_PATH="/etc/realm/config.toml"
REALM_SERVICE="realm"
RULE_LOG="/var/log/realm_rules.log"

# Ensure log file exists and has proper permissions
[ ! -f "$RULE_LOG" ] && touch "$RULE_LOG" && chmod 644 "$RULE_LOG"

# Check if file is writable
if [ ! -w "$CONFIG_PATH" ]; then
    echo "❌ Error: Cannot write to $CONFIG_PATH. Please run with sufficient permissions."
    exit 1
fi

check_port() {
    netstat -tuln 2>/dev/null | grep -q ":$1[ \t]" && return 0 || return 1
}

validate_ip_port() {
    # Validates IP:port or hostname:port format
    [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]{1,5}$ ]] || 
    [[ "$1" =~ ^[a-zA-Z0-9.-]+:[0-9]{1,5}$ ]]
}

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$RULE_LOG"
}

create_rule() {
    while true; do
        read -rp "Rule name (e.g., hongkong_forward): " rule_tag
        # Sanitize input: remove quotes and spaces, ensure non-empty
        rule_tag=$(echo "$rule_tag" | tr -d '" ' | tr -s '\t')
        [ -z "$rule_tag" ] && { echo "❌ Rule name cannot be empty"; continue; }
        # Check if rule tag already exists
        grep -q "tag = \"$rule_tag\"" "$CONFIG_PATH" && { echo "❌ Rule name already exists"; continue; }
        break
    done

    while true; do
        read -rp "Listen port (e.g., 8765): " listen_port
        listen_port=$(echo "$listen_port" | tr -d ' ')
        # Validate port number
        if ! [[ "$listen_port" =~ ^[0-9]{1,5}$ ]] || [ "$listen_port" -lt 1 ] || [ "$listen_port" -gt 65535 ]; then
            echo "❌ Invalid port number (must be 1-65535)"
            continue
        fi
        check_port "$listen_port" && { echo "❌ Port $listen_port is already in use"; continue; }
        break
    done

    while true; do
        read -rp "Remote address:port (e.g., 1.1.1.1:7777 or ddns.com:8888): " remote
        remote=$(echo "$remote" | tr -d ' ')
        validate_ip_port "$remote" && break || echo "❌ Invalid format. Use IP:port or hostname:port"
    done

    # Backup config before modification
    cp "$CONFIG_PATH" "${CONFIG_PATH}.bak"

    # Append new rule
    cat <<EOF >> "$CONFIG_PATH"

[[endpoints]]
tag = "$rule_tag"
listen = "0.0.0.0:$listen_port"
remote = "$remote"
EOF

    # Verify service restart
    if systemctl restart "$REALM_SERVICE" 2>/dev/null; then
        echo "✅ Rule added: $rule_tag -> Listen: $listen_port, Remote: $remote"
        log_action "Added rule [$rule_tag] - Listen: $listen_port -> $remote"
    else
        echo "❌ Failed to restart $REALM_SERVICE"
        mv "${CONFIG_PATH}.bak" "$CONFIG_PATH"
        exit 1
    fi
}

list_rules() {
    echo "📋 Current rules:"
    if ! grep -q '\[\[endpoints\]\]' "$CONFIG_PATH"; then
        echo "No rules configured"
    else
        awk '
        BEGIN { RS="\\[\\[endpoints\\]\\]"; ORS=""; i=0 }
        NR > 1 {
            i++
            match($0, /tag *= *"([^"]+)"/, t)
            match($0, /listen *= *"([^"]+)"/, l)
            match($0, /remote *= *"([^"]+)"/, r)
            printf("%d) [%s]\n   Listen: %s\n   Remote: %s\n--------------------------\n", i, t[1], l[1], r[1])
        }
        ' "$CONFIG_PATH"
    fi
    read -rp "Press Enter to return to menu..."
}

delete_rule() {
    mapfile -t LINE_NUMS < <(grep -n '\[\[endpoints\]\]' "$CONFIG_PATH" | cut -d: -f1)
    total=${#LINE_NUMS[@]}
    if [ $total -eq 0 ]; then
        echo "⚠️ No rules to delete"
        read -rp "Press Enter to return to menu..."
        return
    fi

    echo "🗑️ Available rules to delete:"
    for i in "${!LINE_NUMS[@]}"; do
        idx=$((i+1))
        line=${LINE_NUMS[$i]}
        tag=$(sed -n "$((line+1))p" "$CONFIG_PATH" | grep 'tag' | cut -d'"' -f2)
        echo "$idx) $tag"
    done
    echo "0) Cancel"
    read -rp "Enter rule number to delete: " num

    if [ "$num" = "0" ]; then
        return
    elif ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "$total" ]; then
        echo "❌ Invalid selection"
        read -rp "Press Enter to return to menu..."
        return
    fi

    # Backup config before modification
    cp "$CONFIG_PATH" "${CONFIG_PATH}.bak"

    start=${LINE_NUMS[$((num-1))]}
    if [ "$num" -eq "$total" ]; then
        end=$(wc -l < "$CONFIG_PATH")
    else
        end=$(( ${LINE_NUMS[$num]} - 1 ))
    fi

    # Delete rule
    sed -i "${start},${end}d" "$CONFIG_PATH"

    # Verify service restart
    if systemctl restart "$REALM_SERVICE" 2>/dev/null; then
        echo "✅ Rule $num deleted"
        log_action "Deleted rule [$num]"
    else
        echo "❌ Failed to restart $REALM_SERVICE"
        mv "${CONFIG_PATH}.bak" "$CONFIG_PATH"
        read -rp "Press Enter to return to menu..."
    fi
}

# Main menu loop
while true; do
    clear
    echo "=== Realm Forwarding Rule Manager ==="
    echo "1) Create rule"
    echo "2) List rules"
    echo "3) Delete rule"
    echo "0) Exit"
    echo "===================================="
    read -rp "Select an option: " choice
    case "$choice" in
        1) create_rule ;;
        2) list_rules ;;
        3) delete_rule ;;
        0) exit 0 ;;
        *) echo "❌ Invalid option"; read -rp "Press Enter to continue..." ;;
    esac
done
