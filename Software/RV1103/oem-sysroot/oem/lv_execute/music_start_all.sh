#!/bin/sh

# ==========================================================
# == Main Launcher Script (term_start_all.sh)
# == Launched by LVGL (non-TTY)
# ==========================================================

# 1. Stop LVGL (this frees /dev/input/event1)
/oem/usr/etc/init.d/S99lvgl stop

# 2. Unbind vtcon1 (clean up tty1)
if [ -e /sys/class/vtconsole/vtcon1/bind ]; then
     echo 0 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null
fi
# Switch to tty1 to ensure fbterm binds to the foreground screen
chvt 1
usleep 100000

# 3. --- Core: Launch FBTERM the correct way ---
#
# setsid: Create a new session, detached from LVGL
# sh -c: Run a shell
# exec fbterm: Replace the shell with fbterm
# -- /root/game_logic.sh: Tell fbterm what program to run after starting
# </dev/tty1 >/dev/tty1 2>&1: Bind fbterm's own I/O to tty1
#
# This command will "block" until fbterm and game_logic.sh have exited.
setsid sh -c "exec fbterm -- /oem/lv_execute/music_logic.sh </dev/tty1 >/dev/tty1 2>&1"

# 4. --- Flow has returned ---
# game_logic.sh has exited, fbterm has exited.
echo "fbterm session finished. Restoring TTY1..."

# 5. Restore tty1
if [ -e /sys/class/vtconsole/vtcon1/bind ]; then
     echo 1 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null
fi

# 6. Restart LVGL
/etc/init.d/S99lvgl start

exit 0
