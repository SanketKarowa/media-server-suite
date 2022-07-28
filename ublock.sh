#!/bin/bash
set -e

sleep 10
if [ `rfkill --output SOFT --noheadings list 0` != "unblocked" -o `rfkill --output HARD --noheadings list 0` != "unblocked" ]
then
   ip link set dev wlan0 down
   rfkill unblock all
   ip link set dev wlan0 up
   systemctl restart wpa_supplicant.service
   systemctl restart networking.service
fi
