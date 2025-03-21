#!/bin/bash

# 帮助文档
show_help() {
    echo "用法: $0 [IP范围] [-a] [-p] [-t] [-j] [-u] [-h]"
    echo "IP范围格式: 192.168.1.0/24 或 192.168.1.10-192.168.1.100"
    echo "选项:"
    echo "  -a      仅显示在线IP并保存到 online_ips.txt"
    echo "  -p      检查指定端口（默认只用80）"
    echo "  -t      设置ping超时（默认1秒）"
    echo "  -j      设置并行进程数（默认6）"
    echo "  -u      卸载脚本、相关文件及依赖（保留scan.log）"
    echo "  -h      显示帮助"
    exit 0
}

# 卸载函数
uninstall_script() {
    echo "开始卸载脚本、相关文件及依赖..."
    script_path=$(realpath "$0")
    files_to_remove=(
        "last_scanned_ip.txt"
        "last_scanned_range.txt"
        "online_ips.txt"
    )
    
    # 删除生成的文件
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            echo "已删除: $file"
        fi
    done
    
    # 检测包管理器并卸载依赖
    if command -v apt >/dev/null 2>&1; then
        echo "检测到 apt 包管理器，尝试卸载依赖..."
        sudo apt remove -y iputils-ping netcat-openbsd
        sudo apt autoremove -y
        echo "依赖已卸载（iputils-ping 和 netcat-openbsd）"
    elif command -v yum >/dev/null 2>&1; then
        echo "检测到 yum 包管理器，尝试卸载依赖..."
        sudo yum remove -y iputils nc
        echo "依赖已卸载（iputils 和 nc）"
    else
        echo "警告：未检测到支持的包管理器（apt/yum），请手动卸载 ping 和 nc"
    fi
    
    # 删除脚本本身
    if [ -f "$script_path" ]; then
        rm -f "$script_path"
        echo "已删除脚本本身: $script_path"
    fi
    
    echo "卸载完成（scan.log 已保留）"
    exit 0
}

# 默认设置
port_to_check="80"
ping_timeout=1
parallel_jobs=6
only_online=false
last_ip_file="last_scanned_ip.txt"
last_range_file="last_scanned_range.txt"
output_file="online_ips.txt"
temp_output=$(mktemp)

# 解析参数
while getopts "ap:t:j:uh" opt; do
    case $opt in
        a) only_online=true ;;
        p) port_to_check=$OPTARG ;;
        t) ping_timeout=$OPTARG ;;
        j) parallel_jobs=$OPTARG ;;
        u) uninstall_script ;;
        h) show_help ;;
        *) show_help ;;
    esac
done
shift $((OPTIND-1))

# 检查工具
if ! command -v ping &>/dev/null; then
    echo "错误：需要安装 ping"
    if command -v apt >/dev/null 2>&1; then
        echo "尝试使用 apt 安装 iputils-ping..."
        sudo apt update && sudo apt install -y iputils-ping
    elif command -v yum >/dev/null 2>&1; then
        echo "尝试使用 yum 安装 iputils..."
        sudo yum install -y iputils
    else
        echo "请手动安装 ping"
        exit 1
    fi
fi
if [ -n "$port_to_check" ] && ! command -v nc &>/dev/null; then
    echo "警告：未安装 nc，尝试安装..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt install -y netcat-openbsd
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y nc
    else
        echo "请手动安装 nc 以启用端口检查"
        port_to_check=""
    fi
fi

# IP 转换函数
ip_to_int() {
    local ip=$1
    IFS='.' read -r a b c d <<< "$ip"
    echo $((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))
}

int_to_ip() {
    local int=$1
    echo "$((int >> 24 & 255)).$((int >> 16 & 255)).$((int >> 8 & 255)).$((int & 255))"
}

# 中断处理
trap_save_last_ip() {
    echo "扫描中断，保存最后扫描IP: $last_ip"
    echo "$last_ip" > "$last_ip_file"
    echo "$ip_range" > "$last_range_file"
    cat "$temp_output" >> "$output_file"
    rm -f "$temp_output"
    exit 1
}

trap trap_save_last_ip SIGINT

# 获取上次记录
last_ip=""
ip_range="$1"
if [ -f "$last_ip_file" ] && [ -f "$last_range_file" ]; then
    last_ip=$(cat "$last_ip_file")
    ip_range=$(cat "$last_range_file")
    read -p "从 $last_ip 继续？(y/n): " choice
    [ "$choice" != "y" ] && { last_ip=""; ip_range="$1"; }
fi

if [ -z "$ip_range" ]; then
    echo "请输入IP范围（例: 192.168.1.0/24 或 192.168.1.10-192.168.1.100）："
    read ip_range
fi
echo "$ip_range" > "$last_range_file"

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
    echo "错误：无效IP范围格式"
    exit 1
fi

[ -n "$last_ip" ] && start_int=$(ip_to_int "$last_ip")

# 开始扫描
> "$output_file"
start_time=$(date +%s)
echo "开始扫描（并行数: $parallel_jobs）..."

# 生成并扫描 IP
if [ -n "$port_to_check" ]; then
    for ((ip_int=$start_int; ip_int<=$end_int; ip_int++)); do
        target=$(int_to_ip $ip_int)
        echo "$target" | xargs -I {} -P "$parallel_jobs" bash -c "
            last_ip={}
            if ping -c 1 -W $ping_timeout {} >/dev/null 2>&1; then
                if nc -z -w 1 {} $port_to_check >/dev/null 2>&1; then
                    echo '{} is online (port $port_to_check open)' | tee -a scan.log
                    echo {} >> $temp_output
                else
                    echo '{} ping ok but port $port_to_check closed' >&2  # 调试信息
                fi
            fi
        " &
        last_ip=$target
    done
else
    for ((ip_int=$start_int; ip_int<=$end_int; ip_int++)); do
        target=$(int_to_ip $ip_int)
        echo "$target" | xargs -I {} -P "$parallel_jobs" bash -c "
            last_ip={}
            if ping -c 1 -W $ping_timeout {} >/dev/null 2>&1; then
                echo '{} is online' | tee -a scan.log
                echo {} >> $temp_output
            fi
        " &
        last_ip=$target
    done
fi

wait

cat "$temp_output" >> "$output_file"
rm -f "$temp_output"

end_time=$(date +%s)
total_time=$((end_time - start_time))
minutes=$((total_time / 60))
seconds=$((total_time % 60))
online_count=$(wc -l < "$output_file")

echo -e "\n扫描完成，总共 $ip_count 个IP"
[ -n "$port_to_check" ] && echo "在线: $online_count 个（端口 $port_to_check）" || echo "在线: $online_count 个"
echo "用时: ${minutes}分${seconds}秒"

$only_online && echo "在线IP已保存到 $output_file" || cat "$output_file"
