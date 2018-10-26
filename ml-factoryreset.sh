#!/bin/bash
# This script is distributed with Maratona Linux under the terms of GPLv2

export PATH="/bin:/usr/bin:/sbin:/usr/sbin"

whiptail --backtitle "Maratona Linux FACTORY RESET" --inputbox "ATTENTION: This operation in IRREVERSIBLE! All data will be lost. Are you sure? Write 'I am sure' if you are sure" 15 70 2>/tmp/choice

RESP="$(< /tmp/choice)"

if [[ "$RESP" != "I am sure" ]]; then
  whiptail --msgbox "FACTORY RESET ABORTED. System will now reboot" 10 70
  exit 3
fi
sleep 1
exit 0
