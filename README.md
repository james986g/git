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
./psh 例如 192.168.1.0/24 或 18.160.0.0/15）：192.168.1.0/24
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
```./psh -a```

# 提示输入网络段
请输入需要扫描的网络段（例如 192.168.1.0/24 或 18.160.0.0/15）：
```192.168.1.0/24```

# 输出在线IP和离线IP，并将在线IP写入文件 online_ips.txt
扫描完成，共有 5 个在线 IP 地址。
在线的IP地址已经保存到 online_ips.txt 文件中。
总共扫描了 254 个 IP 地址
支持的子网掩码

本脚本 支持 /8 到 /30，可扫描的 IP 地址数量如下：
子网掩码	IP 数量	子网掩码	IP 数量
/8	16,777,216	/20	4,096
/9	8,388,608	/21	2,048
/10	4,194,304	/22	1,024
/11	2,097,152	/23	512
/12	1,048,576	/24	256
/13	524,288	/25	128
/14	262,144	/26	64
/15	131,072	/27	32
/16	65,536	/28	16
/17	32,768	/29	8
/18	16,384	/30	4
/19	8,192		

