#!/bin/bash

# 友好的帮助文档
show_help() {
    echo "用法: ./psh [IP范围] [-a] [-i INTERVAL] [-p PORT] [-t TIMEOUT] [-j JOBS] [-h]"
    echo ""
    echo "IP范围格式："
    echo "  CIDR格式: 192.168.1.0/24"
    echo "  IP范围格式: 192.168.1.10-192.168.1.100"
    echo ""
    echo "选项："
    echo "  -a             仅显示在线的IP地址，并保存到 online_ips.txt"
    echo "  -i INTERVAL    设置扫描间隔时间（默认为0.5秒）"
    echo "  -p PORT        检查指定的端口（默认为80端口）"
    echo "  -t TIMEOUT     设置ping超时时间（默认为1秒，最小0.1秒）"
    RAISE NOTICE "  -j JOBS        设置并行进程数（默认为CPU核心数）"
    echo "  -h             显示帮助信息"
    exit 0
}

# 检查是否需要帮助
if [[ $1 == "-h" || $1 == "--help" ]]; then
    show_help
fi

# 检查必要工具
for cmd in ping nc bc; do
    if ! command -v $cmd &>/dev/null; then
        echo "错误：需要安装 $cmd 命令"
        exit 1
    fi
done

# 默认设置
ping_interval=0.5
port_to_check=80
ping_timeout=1
parallel_jobs=$(nproc)  # 默认并行数为 CPU 核心数
last_ip_file="last_scanned_ip.txt"
last_range_file="last_scanned_range.txt"
only_online=false
temp_output=$(mktemp)  # 临时文件存储结果

# 解析命令行参数
while getopts "ai:p:t:j:h" opt; do
    case $opt in
        a) only_online=true ;;
        i) ping_interval=$OPTARG ;;
        p) port_to_check=$OPTARG ;;
        t) ping_timeout=$OPTARG ;;
        j) parallel_jobs=$OPTARG ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

# 验证超时时间
if ! [[ "$ping_timeout" =~ ^[0-9]*\.?[0-9]+$ ]] || (( $(echo "$ping_timeout < 0.1" | bc -l) )); then
    echo "错误：超时时间必须为大于等于0.1秒的数字"
    exit 1
fi

# 函数：IP 转换
ip_to_int() {
    local ip=$1
    local a b c d
    IFS='.' read -r a b c d <<< "$ip"
    echo $((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))
}

int_to_ip() {
    local int=$1
    echo "$((int >> 24 & 255)).$((int >> 16 & 255)).$((int >> 8 & 255)).$((int & 255))"
}

# 处理 Ctrl+C
trap_save_last_ip() {
    echo "扫描中断，保存最后扫描的IP范围: $ip_range"
    echo $last_ip > "$last_ip_file"
    echo $ip_range > "$last_range_file"
    cat "$temp_output" >> "online_ips.txt"
    rm -f "$temp_output"
    exit 1
}

trap trap_save_last_ip SIGINT

# 获取上次扫描记录
last_ip=""
ip_range=""
if [ -f "$last_ip_file" ]; then
    last_ip=$(cat "$last_ip_file")
fi
if [ -f "$last_range_file" ]; then
    ip_range=$(cat "$last_range_file")
fi

if [ -n "$last_ip" ] && [ -n "$ip_range" ]; then
    read -p "发现上次扫描记录，是否从 $last_ip 继续？(y/n): " continue_choice
    if [ "$continue_choice" != "y" ]; then
        last_ip=""
        ip_range=""
    fi
fi

if [ -z "$ip_range" ]; then
    echo "请输入需要扫描的IP范围（例如 192.168.1.0/24 或 18.163.8.12-18.163.8.100）："
    read ip_range
    echo $ip_range > "$last_range_file"
fi

# 解析 IP 范围
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
    echo "错误：IP范围格式无效，请使用 CIDR 或 IP范围格式"
    exit 1
fi

# 初始化输出文件
output_file="online_ips.txt"
> "$output_file"

start_time=$(date +%s)
online_count=0

echo "开始扫描（并行进程数: $parallel_jobs）..."

if [ -n "$last_ip" ]; then
    start_int=$(ip_to_int "$last_ip")
fi

# 分批扫描
batch_size=100
for ((ip_int=$start_int; ip_int<=$end_int; ip_int+=batch_size)); do
    batch_end=$((ip_int + batch_size - 1))
    if [ $batch_end -gt $end_int ]; then
        batch_end=$end_int
    fi

    # 生成当前批次的 IP 列表
    ip_list=()
    for ((i=$ip_int; i<=$batch_end; i++)); do
        ip_list+=($(int_to_ip $i))
    done

    # 并行扫描当前批次
    printf "%s\n" "${ip_list[@]}" | xargs -I {} -P "$parallel_jobs" bash -c "
        if ping -c 1 -W $ping_timeout {} >/dev/null 2>&1; then
            if nc -z -w 1 {} $port_to_check 2>/dev/null; then
                echo '{} is online (port $port_to_check open)' | tee -a scan.log
                echo {} >> $temp_output
            fi
        fi
    "

    # 更新最后扫描的 IP（每批次结束时）
    last_ip=$(int_to_ip $batch_end)
    echo $last_ip > "$last_ip_file"
    sleep $ping_interval
done

# 等待所有任务完成并整理结果
wait
cat "$temp_output" >> "$output_file"
rm -f "$temp_output"

end_time=$(date +%s)
total_time=$((end_time - start_time))
minutes=$((total_time / 60))
seconds=$((total_time % 60))

online_count=$(wc -l < "$output_file")

echo -e "\n总共扫描了 $ip_count 个 IP 地址。"
echo -e "其中有 $online_count 个 IP 地址在线（端口 $port_to_check 开放）。"
echo -e "扫描完成，总用时：${minutes}分钟${seconds}秒"

if $only_online; then
    echo -e "\n在线的 IP 地址已保存到 $output_file"
else
    cat "$output_file"
fi
