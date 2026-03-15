#!/bin/sh
# This script could use nmcli to get ESSID or use a separate menu utility

if command -v nmcli &> /dev/null
then
    ESSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
    if [ -n "$ESSID" ]; then
        echo "%{A1:nm-connection-editor &:}📶 $ESSID%{A}"
    else
        echo "%{A1:nm-connection-editor &:}Disconnected%{A}"
    fi
else
    echo "Install NetworkManager"
fi
