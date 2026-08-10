#!/bin/sh

# ==========================================================
# == Main Boot Tasks (Will only run on the 2nd execution)
# ==========================================================
# 准备逻辑：关闭光标，清屏
echo -e "\033[?25l" 
clear

# 检查是否包含 USB 音频设备
if ! grep -qi "USB" /proc/asound/cards; then
    echo -e "\n\n\n\n\n\n"
    echo -e "\033[1;31m        ========================================\033[0m"
    echo -e "\033[1;31m        ||                                    ||\033[0m"
    echo -e "\033[1;31m        ||       警告: 未检测到 USB 耳机!     ||\033[0m"
    echo -e "\033[1;31m        ||                                    ||\033[0m"
    echo -e "\033[1;31m        ========================================\033[0m"
    echo -e "\n\033[1;33m                     按任意键退出...\033[0m"
    
    read -n 1 -s 
else
    # 【核心修改】通过 2>/dev/null 彻底屏蔽动态库的 stderr 报错，同时保留标准输入
    /oem/usr/bin/music_player 2>/dev/null
fi

# ==========================================================
# Exit the sub-script, and wait to restart the GUI
# ==========================================================
echo -e "\033[?25h\033[0m"
clear

echo "Program exited..."
sleep 0.5
cd $HOME
exit 0