#!/bin/sh

# ==========================================================
# == Main Boot Tasks (Shell Tier 1 Menu)
# ==========================================================

echo "Set the USB mode to peripheral..."
echo "Now OTG mode is:$(otgmode -q)"
sleep 0.5

echo "Turning off the OTG-watchdog daemon..."
/oem/usr/etc/init.d/S85otgwatcher stop
sleep 0.5

# ---------------------------------------------------------
# Tier 1 Menu: Select USB Mode (Interactive TUI for Handhelds)
# ---------------------------------------------------------
selected=1

while true; do
    clear
    echo "==============================="
    echo "      SELECT USB MODE          "
    echo "==============================="
    if [ "$selected" -eq 1 ]; then echo " -> 1) DIRECT  (Keyboard Mode)    "; else echo "    1) DIRECT  (Keyboard Mode)    "; fi
    if [ "$selected" -eq 2 ]; then echo " -> 2) DINPUT  (Gamepad Mode)     "; else echo "    2) DINPUT  (Gamepad Mode)     "; fi
    if [ "$selected" -eq 3 ]; then echo " -> 3) Exit                       "; else echo "    3) Exit                       "; fi
    echo "==============================="
    echo "Use W/S to move, ENTER to select"

    # 使用 stty 和 dd 在嵌入式环境下实现无回车单字符读取
    old_stty=$(stty -g)
    stty raw -echo min 1 time 0
    char=$(dd bs=1 count=1 2>/dev/null)
    stty "$old_stty"

            case "$char" in
        w|W)
            selected=$((selected - 1))
            if [ "$selected" -lt 1 ]; then selected=3; fi
            ;;
        s|S)
            selected=$((selected + 1))
            if [ "$selected" -gt 3 ]; then selected=1; fi
            ;;
        "$(printf '\r')" | "$(printf '\n')" | "f" | "F" | " ")
            # 捕获回车键(\r 或 \n)、掌机A键(如果在C里映射为了F)、或空格作为确认键
            break
            ;;
        *)
            # 忽略其他无关按键
            ;;
    esac
done

choice=$selected

case "$choice" in
    1)
        MODE_ARG="direct"
        DESC_TYPE="keyboard"
        ;;
    2)
        MODE_ARG="dinput"
        DESC_TYPE="gamepad"
        ;;
    *)
        echo "Exiting..."
        /oem/usr/etc/init.d/S85otgwatcher start
        exit 0
        ;;
esac

# ---------------------------------------------------------
# USB Gadget ConfigFS Setup (Dynamic based on mode)
# ---------------------------------------------------------
echo "Configuring USB Gadget HID ($DESC_TYPE)..."
CONFIGFS_DIR="/sys/kernel/config/usb_gadget/rockchip"

# Unbind existing gadget first
echo "" > $CONFIGFS_DIR/UDC 2>/dev/null

# Create HID function
mkdir -p $CONFIGFS_DIR/functions/hid.usb0

if [ "$DESC_TYPE" = "keyboard" ]; then
    # Standard Keyboard Descriptor (8 bytes)
    echo 1 > $CONFIGFS_DIR/functions/hid.usb0/protocol
    echo 1 > $CONFIGFS_DIR/functions/hid.usb0/subclass
    echo 8 > $CONFIGFS_DIR/functions/hid.usb0/report_length
    echo -ne \\x05\\x01\\x09\\x06\\xa1\\x01\\x05\\x07\\x19\\xe0\\x29\\xe7\\x15\\x00\\x25\\x01\\x75\\x01\\x95\\x08\\x81\\x02\\x95\\x01\\x75\\x08\\x81\\x03\\x95\\x05\\x75\\x01\\x05\\x08\\x19\\x01\\x29\\x05\\x91\\x02\\x95\\x01\\x75\\x03\\x91\\x03\\x95\\x06\\x75\\x08\\x15\\x00\\x25\\x65\\x05\\x07\\x19\\x00\\x29\\x65\\x81\\x00\\xc0 > $CONFIGFS_DIR/functions/hid.usb0/report_desc
else
    # Standard Gamepad / Joystick Descriptor
    # Standard Gamepad Descriptor (8 bytes: X, Y, RX, RY, 32 Buttons)
    echo 0 > $CONFIGFS_DIR/functions/hid.usb0/protocol
    echo 0 > $CONFIGFS_DIR/functions/hid.usb0/subclass
    echo 8 > $CONFIGFS_DIR/functions/hid.usb0/report_length
    # 替换为你全新的 8 字节完美对齐描述符：
    # echo -ne \\x05\\x01\\x09\\x05\\xa1\\x01\\xa1\\x00\\x05\\x01\\x09\\x30\\x09\\x31\\x09\\x32\\x09\\x35\\x15\\x00\\x26\\xff\\x00\\x75\\x08\\x95\\x04\\x81\\x02\\x05\\x09\\x19\\x01\\x29\\x20\\x15\\x00\\x25\\x01\\x75\\x01\\x95\\x20\\x81\\x02\\xc0\\xc0 > $CONFIGFS_DIR/functions/hid.usb0/report_desc
    echo -ne \\x05\\x01\\x09\\x05\\xa1\\x01\\x09\\x01\\xa1\\x00\\x05\\x01\\x09\\x30\\x09\\x31\\x09\\x32\\x09\\x33\\x15\\x00\\x26\\xff\\x00\\x75\\x08\\x95\\x04\\x81\\x02\\x05\\x09\\x19\\x01\\x29\\x20\\x15\\x00\\x25\\x01\\x75\\x01\\x95\\x20\\x81\\x02\\xc0\\xc0 > $CONFIGFS_DIR/functions/hid.usb0/report_desc
fi

# Bind HID function to rockchip configuration (b.1)
ln -s $CONFIGFS_DIR/functions/hid.usb0 $CONFIGFS_DIR/configs/b.1/ 2>/dev/null

# Enable USB Gadget
ls /sys/class/udc > $CONFIGFS_DIR/UDC

sleep 0.5
echo "USB HID set OK. /dev/hidg0 ready for mode: $MODE_ARG"
# ---------------------------------------------------------

# Launch C program with mode parameter
APP_PATH="/oem/usr/bin/joystick_app"

if [ -x "$APP_PATH" ]; then
    $APP_PATH -m "$MODE_ARG"
else
    echo "Error: $APP_PATH not found or not executable."
    sleep 3
fi

clear

# ---------------------------------------------------------
# USB Gadget Cleanup
# ---------------------------------------------------------
echo "Cleaning up USB Gadget..."
echo "" > $CONFIGFS_DIR/UDC 2>/dev/null
rm -f $CONFIGFS_DIR/configs/b.1/hid.usb0
ls /sys/class/udc > $CONFIGFS_DIR/UDC
# ---------------------------------------------------------

echo "Turning the OTG-watcher daemon on..."
/oem/usr/etc/init.d/S85otgwatcher start
sleep 0.5
echo "OTG mode is $(otgmode -q)"

sleep 0.5
cd $HOME
exit 0