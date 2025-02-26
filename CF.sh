#!/bin/bash

# 捕获 ctrl+c 中断信号
trap 'echo -e "\n用户中断了程序"; 
      if [ ${#online_ips[@]} -gt 0 ]; then
        echo "正在保存在线的IP地址..."
        for ip in "${online_ips[@]}"; do
          echo $ip >> online_ips.txt
        done
        echo -e "在线IP地址已经保存到 online_ips.txt"
      else
        echo "没有在线的IP地址，文件不会保存。"
      fi
      exit 0' SIGINT

# 提示用户输入IP范围（支持CIDR或具体范围）
echo "请输入需要扫描的IP范围（例如 192.168.1.0/24 或 18.163.8.12-18.163.8.20）："
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

# 判断输入格式（CIDR 或 范围）
if [[ $ip_range == */* ]]; then
    # 输入是 CIDR 格式
    IFS='/' read -r network mask <<< "$ip_range"
    IFS='.' read -r i1 i2 i3 i4 <<< "$network"
    
    # 计算IP范围
    start_ip=1
    end_ip=254
    
    # 获取网络前缀长度
    subnet_bits=$((32 - mask))

    # 根据子网掩码设置范围
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
        *)
            end_ip=254
            start_ip=1
    esac

elif [[ $ip_range == *-* ]]; then
    # 输入是 IP 范围格式
    IFS='-' read -r start_ip end_ip <<< "$ip_range"

    # 将起始和结束IP转换为整数
    start_int=$(ip_to_int $start_ip)
    end_int=$(ip_to_int $end_ip)

else
    echo "不支持的输入格式"
    exit 1
fi

# 创建文件存储在线IP地址
output_file="online_ips.txt"
> $output_file # 清空文件内容

# 计算总IP数
if [[ -n "$start_int" && -n "$end_int" ]]; then
    total_ips=$((end_int - start_int + 1))
else
    total_ips=$((end_ip - start_ip + 1))
fi

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
if [[ -n "$start_int" && -n "$end_int" ]]; then
    for ((ip_int=$start_int; ip_int<=$end_int; ip_int++)); do
        target=$(int_to_ip $ip_int)
        
        # 执行ping命令
        ping -c 1 -w 1 $target > /dev/null
        
        # 如果IP地址在线
        if [[ $? -eq 0 ]]; then
            echo "$target is online"
            # 如果 -a 参数被传入，且只显示在线的 IP
            if $only_online; then
                echo "$target" >> $output_file  # 将在线IP地址写入文件
            fi
            # 将在线IP添加到数组
            online_ips+=("$target")
            # 增加在线IP计数
            ((online_count++))
        else
            echo "$target is offline"
        fi

        # 更新进度条
        echo -n "." | pv -n -s $total_ips > /dev/null
    done
else
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
fi

# 输出在线IP列表
if $only_online; then
    echo -e "\n在线的IP地址已经保存到 $output_file 文件中。"
else
    echo -e "\n扫描完成。"
fi

# 输出总共扫描的IP地址和在线的IP数量
echo -e "\n总共扫描了 $total_ips 个IP地址。"
echo -e "其中有 $online_count 个IP地址在线。"
