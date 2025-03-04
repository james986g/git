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
    echo "  -p PORT        检查指定的端口（默认为空，不进行端口扫描）"
    echo "  -h             显示帮助信息"
    exit 0
}

# 默认设置
ping_interval=0.5
port_to_check=""
last_ip_file="last_scanned_ip.txt"
last_range_file="last_scanned_range.txt"
only_online=false
max_parallel=50  # 最大并发进程数

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
    local a b c d
    IFS='.' read -r a b c d <<< "$1"
    echo $((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))
}

# 函数：将整数转换为IP地址
int_to_ip() {
    local int=$1
    echo "$((int >> 24 & 255)).$((int >> 16 & 255)).$((int >> 8 & 255)).$((int & 255))"
}

# 处理 Ctrl+C，终止所有子进程
trap "echo '扫描中断，清理进程...'; kill 0; exit 1" SIGINT

# 获取上次扫描的IP范围
last_ip=""
ip_range=""
if [ -f "$last_ip_file" ]; then last_ip=$(cat "$last_ip_file"); fi
if [ -f "$last_range_file" ]; then ip_range=$(cat "$last_range_file"); fi

if [ -n "$last_ip" ] && [ -n "$ip_range" ]; then
    read -p "发现上次扫描记录，是否从上次停止的IP继续扫描？(y/n): " continue_choice
    if [ "$continue_choice" != "y" ]; then
        last_ip=""
        ip_range=""
    fi
fi

if [ -z "$ip_range" ]; then
    read -p "请输入需要扫描的IP范围（CIDR格式或 IP-范围格式）：" ip_range
    echo "$ip_range" > "$last_range_file"
fi

# 解析IP范围
if [[ $ip_range == */* ]]; then
    IFS='/' read -r network mask <<< "$ip_range"
    start_int=$(ip_to_int "$network")
    ip_count=$((2 ** (32 - mask)))
    end_int=$((start_int + ip_count - 1))
elif [[ $ip_range == *-* ]]; then
    IFS='-' read -r start_ip end_ip <<< "$ip_range"
    start_int=$(ip_to_int "$start_ip")
    end_int=$(ip_to_int "$end_ip")
    ip_count=$((end_int - start_int + 1))
else
    echo "输入格式错误，请输入 CIDR 或 IP 范围"
    exit 1
fi

# 创建存储在线 IP 地址的文件
output_file="online_ips.txt"
> "$output_file"

start_time=$(date +%s)

# 并发管理
running_jobs=0

echo "开始扫描..."
if [ -n "$last_ip" ]; then
    start_int=$(ip_to_int "$last_ip")
fi

for ((ip_int=$start_int; ip_int<=$end_int; ip_int++)); do
    target=$(int_to_ip $ip_int)
    (
        if ping -c 1 -W 0.8 "$target" > /dev/null; then
            echo "$target is online" | tee -a scan.log
            echo "$target" >> "$output_file"
            if [ -n "$port_to_check" ]; then
                nc -z -w1 "$target" "$port_to_check" && echo "Port $port_to_check is open on $target" >> scan.log
            fi
        fi
    ) &
    running_jobs=$((running_jobs + 1))
    
    if ((running_jobs >= max_parallel)); then
        wait -n
        running_jobs=$((running_jobs - 1))
    fi

    echo "$target" > "$last_ip_file"
done

wait

end_time=$(date +%s)
total_time=$((end_time - start_time))
minutes=$((total_time / 60))
seconds=$((total_time % 60))

online_count=$(wc -l < "$output_file")

echo -e "\n总共扫描了 $ip_count 个 IP 地址。"
echo -e "其中有 $online_count 个 IP 地址在线。"
echo -e "扫描完成，总用时：${minutes}分钟${seconds}秒"

if $only_online; then
    echo -e "\n在线的 IP 地址已保存到 $output_file 文件中。"
else
    cat "$output_file"
fi
