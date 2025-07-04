#!/bin/bash
set -e

REALM_DIR="/etc/realm"               # ✅ 一定要有！
REALM_BIN="$REALM_DIR/realm"
CONFIG_PATH="$REALM_DIR/config.toml"
SERVICE_PATH="/etc/systemd/system/realm.service"
ARCH=$(uname -m)

# Step 1: 创建目录
mkdir -p "$REALM_DIR"

# Step 2: 下载 Realm 可执行文件（x86_64）
echo "[信息] 正在下载 Realm..."
wget -qO "$REALM_DIR/realm.tar.gz" \
  https://github.com/zhboner/realm/releases/download/v2.1.4/realm-x86_64-unknown-linux-gnu.tar.gz

# Step 3: 解压
echo "[信息] 正在解压..."
tar -zxvf "$REALM_DIR/realm.tar.gz" -C "$REALM_DIR"
chmod +x "$REALM_BIN"

# ✅ [新增] 初始化空配置文件
if [ ! -f "$CONFIG_PATH" ]; then
  echo "[信息] 正在创建初始配置文件 config.toml ..."
  cat <<EOF > "$CONFIG_PATH"
[network]
no_tcp = false
use_udp = true
EOF
  echo "[信息] 已创建默认配置文件：$CONFIG_PATH"
fi

# Step 4: 创建 systemd 服务
echo "[信息] 正在创建 systemd 服务..."
cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=Realm Port Forwarding
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Type=simple
User=root
WorkingDirectory=$REALM_DIR
ExecStart=$REALM_BIN -c $CONFIG_PATH
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Step 5: 启用 & 启动服务
echo "[信息] 启用开机自启并启动 Realm..."
systemctl daemon-reload
systemctl enable realm
systemctl restart realm

echo -e "\n✅ Realm 安装完成！"
echo "👉 配置文件路径: $CONFIG_PATH"
echo "👉 编辑后请执行：systemctl restart realm"
