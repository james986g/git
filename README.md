```
wget -O cf.sh "https://raw.githubusercontent.com/james986g/git/refs/heads/main/CF.sh"
```
```
chmod +x cf.sh
./cf.sh
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
普通扫描：
默认扫描时，会显示在线和离线的 IP 地址：
```
./cf.sh 192.168.1.0/24
```
只显示在线的 IP 地址：
如果你只想显示在线的 IP 地址，可以使用 -a 参数：
```
./cf.sh -a 192.168.1.0/24
```

