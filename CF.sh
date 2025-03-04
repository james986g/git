#!/bin/bash

# 友好的帮助文档
show_help() {
    echo "用法: ./psh [-a] [-i INTERVAL] [-p PORT] [-h]"
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
ping_interval=0.5
port_to_check=80
last_ip_file="last_scanned_ip.txt"
last_range_file="last_scanned_range.txt"
list_file="list_ip.txt"
only_online=false

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
    echo "$last_ip" > "$last_ip_file"
    echo "$ip_range" > "$last_range_file"
    pkill -P $$  # 终止所有子进程
    exit 1
}

trap trap_save_last_ip SIGINT

# 从 list_ip.txt 读取 IP 范围
if [ ! -f "$list_file" ] || [ ! -s "$list_file" ]; then
    echo "错误: list_ip.txt 文件不存在或为空。"
    exit 1
fi

ip_range=$(head -n 1 "$list_file")
sed -i '1d' "$list_file"
echo "$ip_range" > "$last_range_file"

# 处理 IP 范围
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

output_file="online_ips.txt"
> "$output_file"
start_time=$(date +%s)
online_count=0

# 断点续扫
if [ -f "$last_ip_file" ]; then
    last_ip=$(cat "$last_ip_file")
    if [ -n "$last_ip" ]; then
        start_int=$(ip_to_int "$last_ip")
    fi
fi

echo "开始扫描 $ip_range..."

for ((ip_int=$start_int; ip_int<=$end_int; ip_int++)); do
    target=$(int_to_ip $ip_int)

    echo "$target" | xargs -I {} -P 10 bash -c "
        if ping -c 1 -W 0.7 {} > /dev/null; then
            echo '{} is online' | tee -a scan.log
            echo {} >> \"$output_file\"
            echo {} > \"$last_ip_file\"
        fi
    " &
done

wait  

echo -e "\n扫描完成！"
