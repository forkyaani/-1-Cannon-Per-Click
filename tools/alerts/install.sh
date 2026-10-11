#!/bin/sh
# Installs the alerts on this Mac: copies the script to ~/.ctd-alerts and has launchd run it every 5 minutes.
# The webhook URL goes in ~/.ctd-alerts/webhook_url first (one line, never in git).
set -e
HOME_DIR="$HOME/.ctd-alerts"
PLIST="$HOME/Library/LaunchAgents/com.astralcrafts.ctd-alerts.plist"
mkdir -p "$HOME_DIR"
[ -s "$HOME_DIR/webhook_url" ] || { echo "Put the webhook URL in $HOME_DIR/webhook_url first"; exit 1; }
chmod 600 "$HOME_DIR/webhook_url"
cp "$(dirname "$0")/ctd_alerts.py" "$HOME_DIR/ctd_alerts.py"
cat > "$PLIST" <<PLIST_END
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.astralcrafts.ctd-alerts</string>
    <key>ProgramArguments</key>
    <array><string>/usr/bin/python3</string><string>$HOME_DIR/ctd_alerts.py</string></array>
    <key>StartInterval</key><integer>300</integer>
    <key>RunAtLoad</key><true/>
    <key>StandardOutPath</key><string>$HOME_DIR/log.txt</string>
    <key>StandardErrorPath</key><string>$HOME_DIR/log.txt</string>
</dict>
</plist>
PLIST_END
launchctl bootout "gui/$(id -u)/com.astralcrafts.ctd-alerts" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed: every 5 minutes. Log: $HOME_DIR/log.txt. Remove: launchctl bootout gui/$(id -u)/com.astralcrafts.ctd-alerts"
