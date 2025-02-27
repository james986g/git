#!/bin/bash

# 友好的帮助文档
show_help() {
    echo "用法: ./cf.sh [IP范围] [-a] [-i INTERVAL] [-p PORT] [-h]"
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

# 解析命令行选项
while getopts "a:i:p:h" opt; do
    case $opt in
        a) only_online=true ;;
        i) ping_interval=$OPTARG ;;
        p) port_to_check=$OPTARG ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

# 提示用户输入IP范围（支持CIDR或具体范围）
echo "请输入需要扫描的IP范围（例如 192.168.1.0/24 或 18.163.8.12-18.163.8.100）："
read ip_range

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

# 日志记录函数
log_message() {
    echo "$(date) - $1" >> scan.log
}

# 判断输入格式（CIDR 或 IP 范围）
if [[ $ip_range == */* ]]; then
    # 处理 CIDR 格式
    IFS='/' read -r network mask <<< "$ip_range"
    IFS='.' read -r i1 i2 i3 i4 <<< "$network"
    
    # 计算 IP 总数
    ip_count=$((2 ** (32 - mask)))

    # 获取起始 IP 和结束 IP
    start_int=$(ip_to_int "$network")
    end_int=$((start_int + ip_count - 1))

elif [[ $ip_range == *-* ]]; then
    # 处理 IP 范围格式
    IFS='-' read -r start_ip end_ip <<< "$ip_range"

    # 转换 IP 地址为整数
    start_int=$(ip_to_int $start_ip)
    end_int=$(ip_to_int $end_ip)

    # 计算 IP 总数
    ip_count=$((end_int - start_int + 1))

else
    echo "输入格式错误，请输入 CIDR（如 192.168.1.0/24）或 IP 范围（如 192.168.1.10-192.168.1.100）"
    exit 1
fi

# 创建存储在线 IP 地址的文件
output_file="online_ips.txt"
> $output_file  # 清空文件内容

# 是否只显示在线 IP
only_online=false

# 检查是否传入了 -a 参数
if [[ $1 == "-a" ]]; then
    only_online=true
    echo "只显示在线的 IP 地址"
fi

# 记录脚本开始的时间
start_time=$(date +%s)

# 显示进度条
echo "开始扫描，进度如下："

# 统计在线 IP 地址
online_count=0

# 并行Ping IP地址
for ((ip_int=$start_int; ip_int<=$end_int; ip_int++)); do
    target=$(int_to_ip $ip_int)

    # 使用xargs实现并行Ping
    echo $target | xargs -I {} -P 10 bash -c "
        # 执行 ping 命令
        ping -c 1 -W 1 {} > /dev/null
        if [[ \$? -eq 0 ]]; then
            echo -e '{} is online'
            log_message '{} is online'
            if $only_online; then
                echo {} >> $output_file
            fi
            online_ips+=('{}')
            ((online_count++))
        else
            echo -e '{} is offline'
            log_message '{} is offline'
        fi
        # 检查指定端口
        nc -z -w 1 {} $port_to_check &>/dev/null
        if [[ \$? -eq 0 ]]; then
            echo '{} has port $port_to_check open'
        fi
    " &
done

# 等待所有后台进程结束
wait

# 记录脚本结束的时间
end_time=$(date +%s)

# 计算总用时（秒）
total_time=$((end_time - start_time))

# 将总用时转换为分钟和秒
minutes=$((total_time / 60))
seconds=$((total_time % 60))

# 输出扫描统计
echo -e "\n总共扫描了 $ip_count 个 IP 地址。"
echo -e "其中有 $online_count 个 IP 地址在线。"
echo -e "扫描完成，总用时：${minutes}分钟${seconds}秒"

# 输出在线 IP
if $only_online; then
    echo -e "\n在线的 IP 地址已经保存到 $output_file 文件中。"
else
    echo -e "\n扫描完成。"
fi
