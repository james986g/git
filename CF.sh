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

# 默认设置
ping_interval=0.5
port_to_check=80
last_ip_file="last_scanned_ip.txt"
last_range_file="last_scanned_range.txt"
only_online=false
max_jobs=10  # 控制并发扫描数量

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

# 处理 Ctrl+C，保存最后扫描 IP 并终止所有子进程
trap_save_last_ip() {
    echo "扫描中断，保存最后扫描的IP地址: $last_ip"
    echo "$last_ip" > "$last_ip_file"
    echo "$ip_range" > "$last_range_file"
    pkill -P $$  # 终止所有子进程
    exit 1
}
trap trap_save_last_ip SIGINT

# 选择合适的 ping 命令
if command -v fping &> /dev/null; then
    scan_cmd="fping -c1 -t700"
else
    scan_cmd="ping -c1 -W0.7"
fi

# 获取扫描范围
if [ -f "$last_ip_file" ]; then
    last_ip=$(cat "$last_ip_file")
fi
if [ -f "$last_range_file" ]; then
    ip_range=$(cat "$last_range_file")
fi

if [ -n "$last_ip" ] && [ -n "$ip_range" ]; then
    read -p "发现上次扫描记录，是否从上次停止的IP继续扫描？(y/n): " continue_choice
    if [ "$continue_choice" != "y" ]; then
        last_ip=""
        ip_range=""
    fi
fi

if [ -z "$ip_range" ]; then
    echo "请输入需要扫描的IP范围（例如 192.168.1.0/24 或 18.163.8.12-18.163.8.100）："
    read ip_range
    echo "$ip_range" > "$last_range_file"
fi

# 解析 IP 范围
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

# 端口扫描函数
scan_port() {
    local ip=$1
    local port=$2
    (echo > /dev/tcp/$ip/$port) &>/dev/null && echo "$ip:$port is open" | tee -a scan.log
}

# 开始扫描
output_file="online_ips.txt"
> "$output_file"
echo "开始扫描..."

if [ -n "$last_ip" ]; then
    start_int=$(ip_to_int "$last_ip")
fi

count=0
for ((ip_int=$start_int; ip_int<=$end_int; ip_int++)); do
    target=$(int_to_ip $ip_int)
    {
        if $scan_cmd "$target" > /dev/null; then
            echo "$target is online" | tee -a scan.log
            echo "$target" >> "$output_file"
            if [[ $port_to_check -ne 80 ]]; then
                scan_port "$target" "$port_to_check"
            fi
        fi
    } &
    ((count++))
    if ((count >= max_jobs)); then
        wait
        count=0
    fi
    last_ip=$target
    echo "$last_ip" > "$last_ip_file"
done
wait

echo "扫描完成。在线IP已保存到 $output_file"
