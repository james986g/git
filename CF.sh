#!/bin/bash

# 友好的帮助文档
show_help() {
    echo "用法: ./psh [-a] [-i INTERVAL] [-p PORT] [-h] [IP范围]"
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

shift $((OPTIND - 1))
# 如果命令行中提供了IP范围，则使用它
if [ -z "$ip_range" ] && [ -n "$1" ]; then
    ip_range="$1"
fi

# 处理 Ctrl+C，保存最后扫描 IP
trap_save_last_ip() {
    echo "扫描中断，保存最后扫描的IP地址: $last_ip"
    echo "$last_ip" > "$last_ip_file"
    echo "$ip_range" > "$last_range_file"
    exit 1
}
trap trap_save_last_ip SIGINT

# 如果环境变量 SKIP_MENU 未设置，则让用户选择扫描方式
if [ -z "$SKIP_MENU" ]; then
    # 获取上次扫描的最后一个IP和IP范围（若存在）
    last_ip=""
    ip_range_saved=""
    if [ -f "$last_ip_file" ]; then
        last_ip=$(cat "$last_ip_file")
    fi
    if [ -f "$last_range_file" ]; then
        ip_range_saved=$(cat "$last_range_file")
    fi

    echo "请选择扫描方式："
    echo "1. 扫描 list_ip.txt 的内容"
    echo "2. 发现上次扫描记录，是否从上次停止的IP继续扫描？(y/n)"
    read -p "请输入选项 (1/2): " choice

    if [ "$choice" == "1" ]; then
        if [ -f "list_ip.txt" ]; then
            ip_list=($(cat list_ip.txt))
            for range in "${ip_list[@]}"; do
                echo "正在扫描 IP 段: $range"
                echo "$range" > "$last_range_file"
                # 递归调用自身，传递IP范围参数，并设置SKIP_MENU=1避免重复选择\n                SKIP_MENU=1 ./psh "$range"\n            done\n            exit 0\n        else\n            echo \"错误：list_ip.txt 文件不存在！\"\n            exit 1\n        fi\n    elif [ \"$choice\" == \"2\" ] && [ -n \"$last_ip\" ] && [ -n \"$ip_range_saved\" ]; then\n        read -p \"是否从上次停止的IP继续扫描？(y/n): \" continue_choice\n        if [ \"$continue_choice\" == \"y\" ]; then\n            echo \"从上次扫描的IP地址 $last_ip 继续扫描\"\n            ip_range=\"$ip_range_saved\"\n        else\n            echo \"从头开始扫描\"\n            last_ip=\"\"\n            ip_range=\"\"\n        fi\n    else\n        echo \"输入无效，退出程序\"\n        exit 1\n    fi\nfi

# 如果没有恢复 IP 范围，则提示用户输入
if [ -z "$ip_range" ]; then
    echo "请输入需要扫描的IP范围（例如 192.168.1.0/24 或 18.163.8.12-18.163.8.100）："
    read ip_range
    echo "$ip_range" > "$last_range_file"
fi

# 判断输入格式（CIDR 或 IP 范围）
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

# 记录脚本开始时间
start_time=$(date +%s)

# 统计在线 IP
online_count=0

echo "开始扫描..."

# 如果有上次停止的 IP 地址，跳过之前的 IP，重新开始扫描
if [ -n "$last_ip" ]; then
    start_int=$(ip_to_int "$last_ip")
fi

for ((ip_int=$start_int; ip_int<=$end_int; ip_int++)); do
    target=$(int_to_ip $ip_int)
    # 并行扫描，每个IP使用xargs调用子shell执行ping\n    echo \"$target\" | xargs -I {} -P 10 bash -c \"\n        if ping -c 1 -W 1 {} > /dev/null; then\n            echo '{} is online' | tee -a scan.log\n            echo {} >> \\\"$output_file\\\"\n            exit 0\n        fi\n        exit 1\n    \" &\n\n    # 保存最后扫描的 IP\n    last_ip=$target\n    echo $last_ip > $last_ip_file\n    # 根据自定义间隔等待\n    sleep $ping_interval\ndone

# 等待所有后台进程完成
wait

# 记录脚本结束时间
end_time=$(date +%s)
total_time=$((end_time - start_time))
minutes=$((total_time / 60))
seconds=$((total_time % 60))

# 统计在线IP
online_count=$(wc -l < "$output_file")

echo -e \"\\n总共扫描了 $ip_count 个 IP 地址。\"
echo -e \"其中有 $online_count 个 IP 地址在线。\"
echo -e \"扫描完成，总用时：${minutes}分钟${seconds}秒\"

if $only_online; then
    echo -e \"\\n在线的 IP 地址已经保存到 $output_file 文件中。\"\nelse\n    cat \"$output_file\"\nfi" }
