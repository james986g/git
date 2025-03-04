#!/bin/bash

# 友好的帮助文档
show_help() {
    echo "用法: ./psh [IP范围] [-a] [-i INTERVAL] [-p PORT] [-h]"
    echo ""
    echo "IP范围格式："
    echo "  CIDR格式: 192.168.1.0/24"
    echo "  IP范围格式: 192.168.1.10-192.168.1.100"
    echo ""
    echo "选项："
    echo "  -a             仅显示在线的IP地址，并保存到 online_ips.txt"
    echo "  -i INTERVAL    设置扫描间隔时间（默认为0.5秒）"
    echo "  -p PORT        检查指定的端口（默认为80端口）"
    echo "  -h             显示帮助信息"
    exit 0
}

# 检查是否需要帮助
if [[ $1 == "-h" || $1 == "--help" ]]; then
    show_help
fi

# 默认设置
ping_interval=0.5    # 默认Ping间隔时间
port_to_check=80     # 默认端口为80
last_ip_file="last_scanned_ip.txt"
last_range_file="last_scanned_range.txt"
only_online=false    # 默认显示所有IP，不仅仅是在线IP

# 解析命令行参数
while getopts "ai:p:h" opt; do
    case $opt in
        a) only_online=true ;;
        i) ping_interval=$OPTARG ;;
        p) port_to_check=$OPTARG ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

# 函数：将IP地址转换为整数
ip_to_int() {
    local ip=$1
    local a b c d
    IFS='.' read -r a b c d <<< "$ip"
    echo $((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))
}

# 函数：将整数转换为IP地址
int_to_ip() {
    local int=$1
    echo "$((int >> 24 & 255)).$((int >> 16 & 255)).$((int >> 8 & 255)).$((int & 255))"
}

# 处理 Ctrl+C，保存最后扫描 IP
trap_save_last_ip() {
    echo "扫描中断，保存最后扫描的IP地址: $last_ip"
    echo $last_ip > $last_ip_file
    echo $ip_range > $last_range_file
    exit 1
}

# 注册 Ctrl+C 信号捕获
trap trap_save_last_ip SIGINT

# 获取上次扫描的最后一个IP和IP范围
last_ip=""
ip_range=""
if [ -f "$last_ip_file" ]; then
    last_ip=$(cat "$last_ip_file")
fi
if [ -f "$last_range_file" ]; then
    ip_range=$(cat "$last_range_file")
fi

if [ -n "$last_ip" ] && [ -n "$ip_range" ]; then
    read -p "发现上次扫描记录，是否从上次停止的IP继续扫描？(y/n): " continue_choice
    if [ "$continue_choice" == "y" ]; then
        echo "从上次扫描的IP地址 $last_ip 继续扫描"
    else
        echo "从头开始扫描"
        last_ip=""
        ip_range=""
    fi
fi

# 如果没有恢复 IP 范围，则提示用户输入
if [ -z "$ip_range" ]; then
    echo "请输入需要扫描的IP范围（例如 192.168.1.0/24 或 18.163.8.12-18.163.8.100）："
    read ip_range
    echo $ip_range > $last_range_file
fi

# 判断输入格式（CIDR 或 IP 范围）
if [[ $ip_range == */* ]]; then
    IFS='/' read -r network mask <<< "$ip_range"
    start_int=$(ip_to_int "$network")
    ip_count=$((2 ** (32 - mask)))
    end_int=$((start_int + ip_count - 1))
elif [[ $ip_range == *-* ]]; then
    IFS='-' read -r start_ip end_ip <<< "$ip_range"
    start_int=$(ip_to_int $start_ip)
    end_int=$(ip_to_int $end_ip)
    ip_count=$((end_int - start_int + 1))
else
    echo "输入格式错误，请输入 CIDR 或 IP 范围"
    exit 1
fi

# 创建存储在线 IP 地址的文件
output_file="online_ips.txt"
> "$output_file"

# 记录脚本开始时间
start_time=$(date +%s)

# 统计在线 IP
online_count=0

# 开始扫描
echo "开始扫描..."

# 如果有上次停止的 IP 地址，跳过之前的 IP，重新开始扫描
if [ -n "$last_ip" ]; then
    start_int=$(ip_to_int "$last_ip")
fi

for ((ip_int=$start_int; ip_int<=$end_int; ip_int++)); do
    target=$(int_to_ip $ip_int)

    # 并行扫描
    echo "$target" | xargs -I {} -P 15 bash -c "
        if ping -c 1 -W 0.7 {} > /dev/null; then
            echo '{} is online' | tee -a scan.log
            echo {} >> \"$output_file\"
            exit 0
        fi
        exit 1
    " &

    # 保存最后扫描的 IP
    last_ip=$target
    echo $last_ip > $last_ip_file
done

# 等待所有进程完成
wait

# 记录结束时间
end_time=$(date +%s)

# 计算总用时
total_time=$((end_time - start_time))
minutes=$((total_time / 60))
seconds=$((total_time % 60))

# 统计在线IP
online_count=$(wc -l < "$output_file")

# 输出结果
echo -e "\n总共扫描了 $ip_count 个 IP 地址。"
echo -e "其中有 $online_count 个 IP 地址在线。"
echo -e "扫描完成，总用时：${minutes}分钟${seconds}秒"

# 如果选择 -a 选项，则仅显示在线IP
if $only_online; then
    echo -e "\n在线的 IP 地址已经保存到 $output_file 文件中。"
else
    cat "$output_file"
fi
