# Switch-Monitoring-telegram
# ssh or telnet 

## Overview
This script monitors the trunk ports of multiple network switches using SSH or Telnet, logs their status, and sends alerts via Telegram when changes occur. It helps network administrators keep track of trunk port statuses and detect any issues promptly.

## Features
- Supports both SSH and Telnet connections.
- Monitors trunk ports and logs their status.
- Detects changes in trunk port status and sends real-time alerts.
- Uses Telegram Bot API for notifications.
- Periodic checks to ensure continuous monitoring.

## Prerequisites
- Linux-based system (Ubuntu recommended).
- `sshpass` package installed for SSH authentication.
- `telnet` installed for Telnet-based switches.
- `curl` installed for Telegram API requests.
- Telegram bot with a valid **BOT_TOKEN**.
- A file `~/.switch_pass` containing the switch password.

## Installation & Setup
1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-repo/switch-monitoring.git
   cd switch-monitoring
   ```
2. **Make the script executable:**
   ```bash
   chmod +x switch_monitor.sh
   ```
3. **Edit the script to add your switch details:**
   - Update the `SWITCHES` dictionary with your switch IPs and connection methods.
   - Set your `USERNAME`.
   - Ensure your switch password is stored in `~/.switch_pass`.
   - Replace `TELEGRAM_BOT_TOKEN` and `CHAT_ID` with your Telegram bot credentials.

4. **Run the script manually:**
   ```bash
   ./switch_monitor.sh
   ```
5. **To run it as a background process (optional):**
   ```bash
   nohup ./switch_monitor.sh &
   ```

## How It Works
- The script loops through the defined switches and checks their trunk port statuses.
- If a switch is unreachable, an alert is sent.
- If any trunk port status changes (UP/DOWN), an alert is sent.
- Status logs are stored in `/var/log/switch_trunks_status.log`.

## Customization
- Modify the **sleep interval** (default: 30 seconds) for adjusting the frequency of checks.
- Change the **log file path** if needed.
- Add more parsing rules based on switch CLI output.

## Troubleshooting
- Ensure your switch supports `show interfaces status | include trunk`.
- Check SSH/Telnet access manually before running the script.
- Make sure `~/.switch_pass` has the correct password and proper file permissions.
- Review `/var/log/switch_trunks_status.log` for errors.
- The keys if you used old v 

![image](https://github.com/user-attachments/assets/7fc02dfe-e617-427c-9886-6a2d45636b0c)




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
                MESSAGE+="\n⛔️ Ports DOWN:\n$REMOVED_PORTS"
            fi

            if [[ -n "$ADDED_PORTS" ]]; then
                MESSAGE+="\n✅ Ports UP:\n$ADDED_PORTS"
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

h…]()
