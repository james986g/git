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

# 默认设置
ping_interval=0.5    # 默认Ping间隔时间
port_to_check=80     # 默认端口
last_ip_file="last_scanned_ip.txt"
only_online=false    # 默认显示所有IP
ip_list_file="待扫描ip.txt"

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
    exit 1
}
trap trap_save_last_ip SIGINT

# 检查是否有未完成的扫描
last_ip=""
if [ -f "$last_ip_file" ]; then
    last_ip=$(cat "$last_ip_file")
    if [ -n "$last_ip" ]; then
        read -p "发现上次扫描记录，是否继续扫描？(y/n): " continue_choice
        if [ "$continue_choice" != "y" ]; then
            last_ip=""  # 清空记录，重新扫描
        fi
    fi
fi

# 读取待扫描IP列表
if [ ! -f "$ip_list_file" ]; then
    echo "错误: 未找到 $ip_list_file 文件，请创建并添加IP段后重试。"
    exit 1
fi

# 创建存储在线 IP 地址的文件
output_file="online_ips.txt"
> "$output_file"

# 记录脚本开始时间
start_time=$(date +%s)

# 开始扫描
while IFS= read -r ip_range; do
    # 跳过空行或注释行
    [[ -z "$ip_range" || "$ip_range" =~ ^# ]] && continue
    
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
        echo "输入格式错误：$ip_range"
        continue
    fi
    
    if [ -n "$last_ip" ]; then
        last_int=$(ip_to_int "$last_ip")
        if (( last_int > start_int && last_int <= end_int )); then
            start_int=$last_int
        fi
    fi
    
    for ((ip_int=$start_int; ip_int<=$end_int; ip_int++)); do
        target=$(int_to_ip "$ip_int")
        
        echo "$target" | xargs -I {} -P 10 bash -c "
            if ping -c 1 -W 1 {} > /dev/null; then
                echo '{} is online' | tee -a scan.log
                echo {} >> "$output_file"
                exit 0
            fi
            exit 1
        " &
        
        last_ip=$target
    done
    wait

done < "$ip_list_file"

# 记录结束时间
end_time=$(date +%s)

total_time=$((end_time - start_time))
minutes=$((total_time / 60))
seconds=$((total_time % 60))

online_count=$(wc -l < "$output_file")

echo -e "\n扫描完成，总共扫描了 $online_count 个在线 IP。"
echo -e "总用时：${minutes}分钟${seconds}秒"

if $only_online; then
    echo "在线的 IP 地址已保存到 $output_file 文件中。"
else
    cat "$output_file"
fi
