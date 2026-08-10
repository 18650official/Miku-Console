#!/bin/sh

# Script: nes_start.sh
# Function: Stop LVGL, launch the NES emulator, and restart LVGL afterwards

# 1. Get the game ROM path from the first argument
GAME_PATH="$1"

# 2. Check if the path is provided
if [ -z "$GAME_PATH" ]; then
    echo "nes_start.sh: Error - No game path provided." > /dev/kmsg
    exit 1
fi

# 3. Stop the LVGL service
sleep 0.5
echo "nes_start.sh: Stopping LVGL..." > /dev/kmsg
/oem/usr/etc/init.d/S99lvgl stop
sleep 0.1

# 4. Launch the NES emulator wrapper script
echo "nes_start.sh: Starting game: $GAME_PATH" > /dev/kmsg
echo "Executed command: /oem/usr/bin/nesemu \"$GAME_PATH\""
/bin/sh -c "/oem/usr/bin/nesemu \"$GAME_PATH\""

# 5. Game exited, restart LVGL
echo "nes_start.sh: Game exited. Restarting LVGL." > /dev/kmsg
/oem/usr/etc/init.d/S99lvgl restart

