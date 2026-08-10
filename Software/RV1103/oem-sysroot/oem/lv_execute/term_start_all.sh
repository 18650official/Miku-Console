#!/bin/sh

# ==========================================================
# == Main Launcher Script (term_start_all.sh)
# == Launched by LVGL (non-TTY)
# ==========================================================

# 0. 检查传入参数
if [ -z "$1" ]; then
    echo "未检测到参数，默认启动 game_logic.sh"
    TARGET_APP="/oem/lv_execute/game_logic.sh"
    
    # 如果你希望在没有参数时直接退出，请删除上面两行，并取消下面两行的注释：
    # echo "用法: $0 <可执行程序路径>"
    # exit 1
else
    TARGET_APP="$1"
fi

# 检查目标程序是否存在且具有可执行权限 (-x)
if [ ! -x "$TARGET_APP" ]; then
    echo "错误: 目标程序 $TARGET_APP 不存在或没有可执行权限!"
    # 如果是开发板环境，可能需要给执行权限，例如: chmod +x $TARGET_APP
    exit 1
fi

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
# -- $TARGET_APP: Tell fbterm what program to run after starting
# </dev/tty1 >/dev/tty1 2>&1: Bind fbterm's own I/O to tty1
#
# This command will "block" until fbterm and TARGET_APP have exited.
setsid sh -c "exec fbterm -- $TARGET_APP </dev/tty1 >/dev/tty1 2>&1"

# 4. --- Flow has returned ---
# TARGET_APP has exited, fbterm has exited.
echo "fbterm session finished. Restoring TTY1..."

# 5. Restore tty1
if [ -e /sys/class/vtconsole/vtcon1/bind ]; then
     echo 1 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null
fi

# 6. Restart LVGL
/etc/init.d/S99lvgl start

exit 0

