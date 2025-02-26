```
pkg install pv

```
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
运行脚本后，它会扫描指定的网络段并 ping 每个 IP 地址。
所有在线的 IP 地址都会被写入到 online_ips.txt 文件。
运行结束后，你可以查看文件 online_ips.txt，里面会列出所有在线的 IP 地址。

output_file="online_ips.txt"：定义保存在线 IP 地址的文件。
```> $output_file```：清空文件内容，以免每次运行时附加旧的在线 IP 地址。
echo "$target" >> $output_file：如果某个 IP 地址在线，就将其添加到 online_ips.txt 文件中。

