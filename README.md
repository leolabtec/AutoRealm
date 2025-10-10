使用下面命令开始你的转发规则吧

```sh
bash <(wget -qO- https://raw.githubusercontent.com/leolabtec/AutoRealm/refs/heads/main/bash.sh)
```
ss-rust
```sh
bash <(curl -fsSL https://raw.githubusercontent.com/leolabtec/AutoRealm/refs/heads/main/ss-rust)
```
查看节点状态
```sh
systemctl status shadowsocks-rust-节点名称
```

# ss-server
```sh
bash <(curl -fsSL https://raw.githubusercontent.com/leolabtec/AutoRealm-ss/refs/heads/main/ss-server)
```

查看运行状态的命令
```
systemctl status ss-server
```
查看当前节点列表
```
ls /etc/shadowsocks-libev | grep node-
```
查看节点运行状态
```
ps -ef | grep ss-server | grep -v grep
```

