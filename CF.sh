#!/bin/bash

# 捕获 ctrl+c 中断信号
trap "echo -e '\n用户中断了程序'; exit 0" SIGINT

# 提示用户输入网络段（例如 192.168.1.0/24 或 18.160.0.0/15）
echo "请输入需要扫描的网络段（例如 192.168.1.0/24 或 18.160.0.0/15）："
read ip_range

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
            end_ip=16777214
            start_ip=1
            ;;
        16)
            end_ip=65534
            start_ip=1
            ;;
        24)
            end_ip=254
            start_ip=1
            ;;
        15)
            end_ip=32766
            start_ip=1
            ;;
        21)
            end_ip=2047
            start_ip=255
            ;;
        *)
            end_ip=254
            start_ip=1
    esac

    echo $start_ip $end_ip
}

# 通过掩码计算范围
read start_ip end_ip <<< $(calculate_ip_range $mask)

# 创建文件存储在线IP地址
output_file="online_ips.txt"
> $output_file # 清空文件内容

# 计算总IP数
total_ips=$((end_ip - start_ip + 1))

# 是否只显示在线IP的标志
only_online=false

# 检查是否传入了 -a 参数
if [[ $1 == "-a" ]]; then
    only_online=true
    echo "只显示在线的 IP 地址"
fi

# 显示进度条
echo "开始扫描，进度如下："

# 统计在线IP地址的计数器
online_count=0

# 循环对所有IP段逐一ping
for ip in $(seq $start_ip $end_ip); do
    target="$i1.$i2.$i3.$ip"
    
    # 执行ping命令
    ping -c 1 -w 1 $target > /dev/null
    
    # 如果IP地址在线
    if [[ $? -eq 0 ]]; then
        echo "$target is online"
        # 如果 -a 参数被传入，且只显示在线的 IP
        if $only_online; then
            echo "$target" >> $output_file  # 将在线IP地址写入文件
        fi
        # 增加在线IP计数
        ((online_count++))
    else
        echo "$target is offline"
    fi

    # 更新进度条
    echo -n "." | pv -n -s $total_ips > /dev/null
done

# 输出在线IP列表
if $only_online; then
    echo -e "\n在线的IP地址已经保存到 $output_file 文件中。"
else
    echo -e "\n扫描完成。"
fi

# 输出总共扫描的IP地址和在线的IP数量
echo -e "\n总共扫描了 $total_ips 个IP地址。"
echo -e "其中有 $online_count 个IP地址在线。"
