```
pkg install wget -y
```
```
pkg install pv
```
```
wget -O psh "https://raw.githubusercontent.com/james986g/git/refs/heads/main/CF.sh"
```
```
chmod +x psh
```
```
./psh
```
开始使用
./cf.sh 例如 192.168.1.0/24 或 18.160.0.0/15）：192.168.1.0/24
# 查看结果：脚本会对该网络段内的每个IP进行ping操作，输出类似以下的内容：
```
正在ping 192.168.1.1
192.168.1.1 is online
正在ping 192.168.1.2
192.168.1.2 is offline
正在ping 192.168.1.3
192.168.1.3 is online
...
```
使用方法：
# 只显示在线的IP并保存到文件
```./cf.sh -a```

# 提示输入网络段
请输入需要扫描的网络段（例如 192.168.1.0/24 或 18.160.0.0/15）：
```192.168.1.0/24```

# 输出在线IP和离线IP，并将在线IP写入文件 online_ips.txt
扫描完成，共有 5 个在线 IP 地址。
在线的IP地址已经保存到 online_ips.txt 文件中。
总共扫描了 254 个 IP 地址
