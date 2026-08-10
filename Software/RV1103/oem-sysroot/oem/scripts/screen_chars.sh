#!/bin/sh

# === 配置区域 ===
# 单个字符配置
CHAR_EN="A"
CHAR_CN="中"
CHAR_EM="��"

# 行内容配置 (为了方便观察行数，行模式下我会带上当前的行号)
# 这里的 "一行" 指的是输出内容并强制换行
get_line_en() { printf "--- English Line %d ---\n" $1; }
get_line_cn() { printf "--- 中文测试行 %d ---\n" $1; }
get_line_em() { printf "--- �� Emoji Line %d ---\n" $1; }

# === 逻辑区域 ===

# 保存当前的终端设置，以便退出时恢复
OLD_TTY=$(stty -g)

# 初始化计数器
COUNT=0

# 定义退出函数 (捕获 Ctrl+C)
cleanup() {
    # 恢复终端设置
    stty $OLD_TTY
    # 换行，防止最后的数字跟在字符后面
    echo ""
    echo ""
    # 输出最终统计结果
    echo ">>> FINAL COUNT: $COUNT"
    # 同时返回这个数字作为退出码 (最大支持255，超过则看屏幕打印)
    exit $COUNT
}

# 捕获 SIGINT (Ctrl+C)
trap cleanup INT TERM

# 设置终端为 Raw 模式：无回显、无缓冲、读取一个字符即返回
stty -echo -icanon min 1 time 0

# 循环读取按键
while true; do
    # 读取 1 个字节的输入
    # 注意：在某些极简的嵌入式sh中，read -n 1 可能不支持，
    # 所以这里使用 dd 来读取按键，兼容性最强。
    KEY=$(dd bs=1 count=1 2>/dev/null)

    case "$KEY" in
        1)
            # 输出一个英文字符
            printf "%s" "$CHAR_EN"
            COUNT=$((COUNT + 1))
            ;;
        2)
            # 输出一个中文字符
            printf "%s" "$CHAR_CN"
            COUNT=$((COUNT + 1))
            ;;
        3)
            # 输出一个 Emoji
            printf "%s" "$CHAR_EM"
            COUNT=$((COUNT + 1))
            ;;
        4)
            # 输出一行英文
            # 只有按下一行指令时，我们才增加计数，这样你可以专门用来测行数
            COUNT=$((COUNT + 1))
            get_line_en $COUNT
            ;;
        5)
            # 输出一行中文
            COUNT=$((COUNT + 1))
            get_line_cn $COUNT
            ;;
        6)
            # 输出一行 Emoji
            COUNT=$((COUNT + 1))
            get_line_em $COUNT
            ;;
        *)
            # 其他按键忽略，或者你也可以用来重置计数
            # COUNT=0
            ;;
    esac
done

