#!/bin/bash

# 捕获 Ctrl+C (SIGINT) 信号
trap 'echo "程序已中断"; exit' SIGINT

# 解析命令行参数
show_online_only=false

while getopts "a" opt; do
    case $opt in
        a)
            show_online_only=true
            ;;
        *)
            echo "用法: ./cf.sh [-a] <IP段>"
            exit 1
            ;;
    esac
done

# 提示用户输入网络段（例如 192.168.1.0/24 或 18.160.0.0/15）
shift $((OPTIND - 1)) # 移动位置参数
if [ -z "$1" ]; then
    echo "请输入需要扫描的网络段（例如 192.168.1.0/24 或 18.160.0.0/15）："
    read ip_range
else
    ip_range=$1
fi

# 提取网络地址和子网掩码
IFS='/' read -r network mask <<< "$ip_range"

# 将网络地址转换为四个整数
IFS='.' read -r i1 i2 i3 i4 <<< "$network"

# 计算IP的范围，起始地址和结束地址根据子网掩码来确定
function calculate_ip_range {
    local mask=$1
    local network="$2.$3.$4.$5"

    # 将掩码转换为网络前缀长度（32 - 子网掩码）
    local subnet_bits=$((32 - mask))

    # 计算IP范围
    local start_ip=1
    local end_ip=254
    
    # 对不同子网掩码进行不同的处理
    case $subnet_bits in
        8)
            end_ip=255
            start_ip=1
            ;;
        16)
            end_ip=255
            start_ip=1
            ;;
        24)
            end_ip=254
            start_ip=1
            ;;
        15)
            end_ip=254
            start_ip=1
            ;;
        21)
            end_ip=254
            start_ip=255
            ;;
        *)
            end_ip=254
            start_ip=1
    esac

    echo $start_ip $end_ip
}

# 通过掩码计算范围
range=$(calculate_ip_range $mask $i1 $i2 $i3 $i4)
start_ip=$(echo $range | cut -d ' ' -f1)
end_ip=$(echo $range | cut -d ' ' -f2)

# 循环对所有IP段逐一ping
for ip in $(seq $start_ip $end_ip); do
    target="$i1.$i2.$i3.$ip"
    echo "正在ping $target"
    ping -c 1 -w 1 $target > /dev/null
    if [[ $? -eq 0 ]]; then
        # 如果是-a选项，只有在线IP才会显示
        if $show_online_only; then
            echo "$target is online"
        else
            echo "$target is online"
        fi
    elif ! $show_online_only; then
        # 如果没有 -a 选项，显示 offline 的信息
        echo "$target is offline"
    fi
done
