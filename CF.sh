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

# 显示进度条
echo "开始扫描，进度如下："

# 统计在线 IP 地址
online_count=0

# 遍历 IP 地址范围并 Ping
for ((ip_int=$start_int; ip_int<=$end_int; ip_int++)); do
    target=$(int_to_ip $ip_int)
    
    # 执行 ping 命令
    ping -c 1 -W 1 $target > /dev/null
    
    # 如果 IP 地址在线
    if [[ $? -eq 0 ]]; then
        echo "$target is online"
        # 只保存在线 IP
        if $only_online; then
            echo "$target" >> $output_file
        fi
        online_ips+=("$target")
        ((online_count++))
    else
        echo "$target is offline"
    fi

    # 进度条
    echo -n "." | pv -n -s $ip_count > /dev/null
done

# 输出在线 IP
if $only_online; then
    echo -e "\n在线的 IP 地址已经保存到 $output_file 文件中。"
else
    echo -e "\n扫描完成。"
fi

# 显示扫描统计
echo -e "\n总共扫描了 $ip_count 个 IP 地址。"
echo -e "其中有 $online_count 个 IP 地址在线。"
