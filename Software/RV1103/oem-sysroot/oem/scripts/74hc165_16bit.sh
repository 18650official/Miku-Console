#!/bin/sh

# === 1. 定义 GPIO 编号 ===
# 根据手册公式计算得出 [cite: 260]
PIN_LOAD=4   # GPIO0_A4
PIN_CLK=55   # GPIO1_C7
PIN_DATA=54  # GPIO1_C6

# === 2. 初始化函数 ===
setup_gpio() {
    echo "正在初始化 GPIO..."

    # 导出 GPIO (如果已导出则忽略错误)
    # 路径参考手册 2.3 节 [cite: 271]
    if [ ! -d /sys/class/gpio/gpio$PIN_LOAD ]; then
        echo $PIN_LOAD > /sys/class/gpio/export
    fi
    if [ ! -d /sys/class/gpio/gpio$PIN_CLK ]; then
        echo $PIN_CLK > /sys/class/gpio/export
    fi
    if [ ! -d /sys/class/gpio/gpio$PIN_DATA ]; then
        echo $PIN_DATA > /sys/class/gpio/export
    fi

    # 设置方向 [cite: 292, 293, 294]
    # LOAD 和 CLK 是输出 (out)
    # DATA 是输入 (in)
    echo out > /sys/class/gpio/gpio$PIN_LOAD/direction
    echo out > /sys/class/gpio/gpio$PIN_CLK/direction
    echo in  > /sys/class/gpio/gpio$PIN_DATA/direction

    # 初始化电平状态
    echo 1 > /sys/class/gpio/gpio$PIN_LOAD/value # 锁存平时拉高
    echo 0 > /sys/class/gpio/gpio$PIN_CLK/value  # 时钟平时拉低
}

# === 3. 读取逻辑 ===
read_165() {
    # 1. 锁存数据 (Load)
    # 拉低 PL 引脚，将并行数据装入芯片
    echo 0 > /sys/class/gpio/gpio$PIN_LOAD/value
    # 稍微延时（Shell脚本本身很慢，不需要额外 sleep）
    echo 1 > /sys/class/gpio/gpio$PIN_LOAD/value

    # 准备变量存储 16 位数据
    VAL_STR=""

    # 2. 循环读取 16 次 (两个芯片级联)
    for i in $(seq 1 16); do
        # 读取当前 DATA 引脚的值 [cite: 313]
        BIT=$(cat /sys/class/gpio/gpio$PIN_DATA/value)
        
        # 拼接到字符串
        VAL_STR="$VAL_STR$BIT"

        # 发送时钟脉冲 (Shift)
        # 上升沿移位：低 -> 高 -> 低
        echo 1 > /sys/class/gpio/gpio$PIN_CLK/value
        echo 0 > /sys/class/gpio/gpio$PIN_CLK/value
    done

    echo "读取值 (Bin): $VAL_STR"
}

# === 主程序 ===

# 配置环境
setup_gpio

echo "开始读取 (按 Ctrl+C 退出)..."

while true; do
    read_165
    sleep 0.5
done

