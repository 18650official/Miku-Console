#!/bin/sh

# === 1. 定义 GPIO 编号 (基于官方文档公式计算) ===
# LATCH (PL): GPIO0_A4 -> Pin 4
# CLOCK (CP): GPIO1_C7 -> Pin 55
# DATA  (Q7): GPIO1_C6 -> Pin 54
PIN_LOAD=4
PIN_CLK=55
PIN_DATA=54

# === 2. 初始化 GPIO ===
setup_gpio() {
    echo "正在初始化 GPIO..."

    # 导出引脚
    for pin in $PIN_LOAD $PIN_CLK $PIN_DATA; do
        if [ ! -d /sys/class/gpio/gpio$pin ]; then
            echo $pin > /sys/class/gpio/export
        fi
    done

    # 设置方向
    echo out > /sys/class/gpio/gpio$PIN_LOAD/direction
    echo out > /sys/class/gpio/gpio$PIN_CLK/direction
    echo in  > /sys/class/gpio/gpio$PIN_DATA/direction

    # 初始状态：LOAD拉高，CLK拉低
    echo 1 > /sys/class/gpio/gpio$PIN_LOAD/value
    echo 0 > /sys/class/gpio/gpio$PIN_CLK/value
}

# === 3. 读取函数 (8位) ===
read_8bits() {
    # --- A. 锁存数据 (拍照) ---
    # 拉低 PL 再拉高，数据就被载入芯片内部寄存器
    echo 0 > /sys/class/gpio/gpio$PIN_LOAD/value
    echo 1 > /sys/class/gpio/gpio$PIN_LOAD/value

    VAL_STR=""

    # --- B. 循环移位读取 8 次 ---
    for i in $(seq 1 8); do
        # 1. 读当前位 (读 Q7)
        BIT=$(cat /sys/class/gpio/gpio$PIN_DATA/value)
        VAL_STR="$VAL_STR$BIT"

        # 2. 移位 (给一个时钟脉冲)
        # 74HC165 在时钟上升沿移位 (CP: 0 -> 1)
        echo 1 > /sys/class/gpio/gpio$PIN_CLK/value
        echo 0 > /sys/class/gpio/gpio$PIN_CLK/value
    done

    # 打印二进制结果 (例如: 11111110 代表第一个键被按下)
    echo "读取数据 [D0-D7]: $VAL_STR"
}

# === 主程序 ===
setup_gpio

echo "开始读取单片 74HC165 (8路)... Ctrl+C 退出"

while true; do
    read_8bits
    sleep 0.5
done

