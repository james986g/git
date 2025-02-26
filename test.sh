#!/bin/bash

# 捕获 ctrl+c 中断信号
trap "echo -e '\n用户中断了程序'; exit 0" SIGINT

# 提示用户输入 IP 范围
echo "请输入需要扫描的 IP 范围（例如 18.161.8.12-18.161.9.12）："
read ip_range

# 解析输入的IP范围，获取起始和结束的IP地址
IFS='-' read -r start_ip end_ip <<< "$ip_range"

# 将起始和结束 IP 地址分解为四个部分
IFS='.' read -r s1 s2 s3 s4 <<< "$start_ip"
IFS='.' read -r e1 e2 e3 e4 <<< "$end_ip"

# 将 IP 地址转换为十进制数（便于比较）
ip_to_decimal() {
    local ip=$1
    IFS='.' read -r i1 i2 i3 i4 <<< "$ip"
    echo $((i1 * 256 * 256 * 256 + i2 * 256 * 256 + i3 * 256 + i4))
}

# 将起始 IP 和结束 IP 转换为十进制数
start_decimal=$(ip_to_decimal "$start_ip")
end_decimal=$(ip_to_decimal "$end_ip")

# 创建文件存储在线 IP 地址
output_file="online_ips.txt"
> $output_file # 清空文件内容

# 计算总 IP 数
total_ips=$((end_decimal - start_decimal + 1))

# 是否只显示在线 IP 的标志
only_online=false

# 检查是否传入了 -a 参数
if [[ $1 == "-a" ]]; then
    only_online=true
    echo "只显示在线的 IP 地址"
fi

# 显示进度条
echo "开始扫描，进度如下："

# 统计在线 IP 地址的计数器
online_count=0

# 循环逐个 ping 所有 IP 地址
for ((decimal_ip=$start_decimal; decimal_ip<=$end_decimal; decimal_ip++)); do
    # 将十进制 IP 转换回点分十进制格式
    ip=$(printf "%d.%d.%d.%d" \
        $((decimal_ip >> 24 & 255)) \
        $((decimal_ip >> 16 & 255)) \
        $((decimal_ip >> 8 & 255)) \
        $((decimal_ip & 255)))

    # 执行 ping 命令
    ping -c 1 -w 1 $ip > /dev/null

    # 如果 IP 地址在线
    if [[ $? -eq 0 ]]; then
        echo "$ip is online"
        # 如果 -a 参数被传入，且只显示在线的 IP
        if $only_online; then
            echo "$ip" >> $output_file  # 将在线 IP 地址写入文件
        fi
        # 增加在线 IP 计数
        ((online_count++))
    else
        echo "$ip is offline"
    fi

    # 更新进度条
    echo -n "." | pv -n -s $total_ips > /dev/null
done

# 输出在线 IP 列表
if $only_online; then
    echo -e "\n在线的 IP 地址已经保存到 $output_file 文件中。"
else
    echo -e "\n扫描完成。"
fi

# 输出总共扫描的 IP 地址和在线的 IP 数量
echo -e "\n总共扫描了 $total_ips 个 IP 地址。"
echo -e "其中有 $online_count 个 IP 地址在线。"
