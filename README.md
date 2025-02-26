```
wget -O cf.sh "https://raw.githubusercontent.com/james986g/git/refs/heads/main/CF.sh
```
```
chmod +x cf.sh
./cf.sh
```
开始使用
./cf.sh 例如 192.168.1.0/24 或 18.160.0.0/15）：192.168.1.0/24
# 查看结果：脚本会对该网络段内的每个IP进行ping操作，输出类似以下的内容：
正在ping 192.168.1.1
192.168.1.1 is online
正在ping 192.168.1.2
192.168.1.2 is offline
正在ping 192.168.1.3
192.168.1.3 is online
...
注意事项：

    这个脚本仅依赖于本地 ping 命令，因此确保你的终端环境中有安装 ping 命令。
    如果扫描的IP段过大，执行时间可能会比较长。你可以使用不同的 -c 参数控制每次ping的数量（例如，-c 3 表示每个IP ping三次）。
    网络段内的每个IP都可能会被防火墙或其他安全策略阻止ping请求，因此即使IP处于活动状态，ping 可能也会失败。


