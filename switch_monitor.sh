#!/bin/bash

SWITCHES=(
    ["192.xx.xx.xx"]="telnet"
    ["192.xx.xx.xx"]="ssh"
    ["192.xx.xx.xx"]="ssh"
)

USERNAME="islam"
PASSWORD=$(cat ~/.switch_pass)

LOG_FILE="/var/log/switch_trunks_status.log"
TEMP_FILE="/tmp/switch_trunks_output.txt"

TELEGRAM_BOT_TOKEN="TOKEN"
CHAT_ID="CHAT_ID"

send_telegram_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$message"
}

check_switch() {
    local SWITCH_IP="$1"
    local METHOD="$2"
    local LAST_STATUS_FILE="/tmp/last_trunks_status_$SWITCH_IP.txt"

    echo "[$(date)] Checking Switch: $SWITCH_IP using $METHOD" | tee -a "$LOG_FILE"

    if ! ping -c 4 "$SWITCH_IP" > /dev/null 2>&1; then
        MESSAGE="🚨 ALERT: Switch $SWITCH_IP is DOWN! 🚨"
        echo "$MESSAGE" | tee -a "$LOG_FILE"
        send_telegram_message "$MESSAGE"
        return
    fi

    if [[ "$METHOD" == "telnet" ]]; then
        {
            sleep 2
            echo "$USERNAME"
            sleep 2
            echo "$PASSWORD"
            sleep 2
            echo "show interfaces status | include trunk"
            sleep 2
            echo "exit"
        } | telnet "$SWITCH_IP" > "$TEMP_FILE"

    elif [[ "$METHOD" == "ssh" ]]; then
        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$SWITCH_IP" \
            "show interfaces status | include trunk" > "$TEMP_FILE"
    fi

    TRUNK_STATUS=$(awk '/trunk/ {print $1, $(NF-1)}' "$TEMP_FILE")
    #TRUNK_STATUS=$(grep "trunk" "$TEMP_FILE" | awk '{print $1, $2}')

    echo "[$(date)] Switch $SWITCH_IP Trunk Ports Status:" | tee -a "$LOG_FILE"
    echo "$TRUNK_STATUS" | tee -a "$LOG_FILE"
    echo "----------------------------------" | tee -a "$LOG_FILE"

    if [[ -f "$LAST_STATUS_FILE" ]]; then
    ADDED_PORTS=$(comm -13 <(sort "$LAST_STATUS_FILE") <(echo "$TRUNK_STATUS" | sort))
    REMOVED_PORTS=$(comm -23 <(sort "$LAST_STATUS_FILE") <(echo "$TRUNK_STATUS" | sort))

        if [[ -n "$ADDED_PORTS" || -n "$REMOVED_PORTS" ]]; then
            MESSAGE="⚠️ Trunk change detected on Switch: $SWITCH_IP"

            if [[ -n "$REMOVED_PORTS" ]]; then
                MESSAGE+="⛔️ Ports DOWN:$REMOVED_PORTS"
            fi

            if [[ -n "$ADDED_PORTS" ]]; then
                MESSAGE+="✅ Ports UP:$ADDED_PORTS"
            fi

            echo "$MESSAGE" | tee -a "$LOG_FILE"
            send_telegram_message "$MESSAGE"
        fi
    fi

    echo "$TRUNK_STATUS" > "$LAST_STATUS_FILE"
}

while true; do
    for SWITCH_IP in "${!SWITCHES[@]}"; do
        check_switch "$SWITCH_IP" "${SWITCHES[$SWITCH_IP]}"
    done
    sleep 30
done

