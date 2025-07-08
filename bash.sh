#!/bin/bash

# 定义目标目录和文件路径
DEST_DIR="/etc/bash"
INSTALL_SH="$DEST_DIR/install.sh"
MAIN_SH="$DEST_DIR/main.sh"
INSTALL_URL="https://raw.githubusercontent.com/leolabtec/AutoRealm/refs/heads/main/install.sh"
MAIN_URL="https://raw.githubusercontent.com/leolabtec/AutoRealm/refs/heads/main/main.sh?token=GHSAT0AAAAAADFMHY5K23JTNQH2FTHJROOM2DIV4MQ"

# 检查是否以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ 错误：请以 root 权限运行此脚本（使用 sudo）。"
    exit 1
fi

# 检查并安装 curl
if ! command -v curl &>/dev/null; then
    echo "⏳ 检测到 curl 未安装，正在尝试安装..."
    if command -v apt-get &>/dev/null; then
        apt-get update
        apt-get install curl -y
    elif command -v yum &>/dev/null; then
        yum install curl -y
    elif command -v apk &>/dev/null; then
        apk add curl
    else
        echo "❌ 错误：无法自动安装 curl，请手动安装 curl。"
        exit 1
    fi
fi

# 验证 curl 是否安装成功
if ! command -v curl &>/dev/null; then
    echo "❌ 错误：curl 安装失败，请手动安装 curl。"
    exit 1
fi

# 检查并安装 gawk
if ! command -v gawk &>/dev/null; then
    echo "⏳ 检测到 gawk 未安装，正在尝试安装..."
    if command -v apt-get &>/dev/null; then
        apt-get update
        apt-get install gawk -y
    elif command -v yum &>/dev/null; then
        yum install gawk -y
    elif command -v apk &>/dev/null; then
        apk add gawk
    else
        echo "❌ 错误：无法自动安装 gawk，请手动安装 gawk。"
        exit 1
    fi
fi

# 验证 gawk 是否安装成功
if ! command -v gawk &>/dev/null; then
    echo "❌ 错误：gawk 安装失败，请手动安装 gawk。"
    exit 1
fi

# 创建目标目录（如果不存在）
mkdir -p "$DEST_DIR"
if [ ! -d "$DEST_DIR" ]; then
    echo "❌ 错误：无法创建目录 $DEST_DIR。"
    exit 1
fi

# 下载 install.sh
echo "⏳ 正在下载 install.sh ..."
if ! curl -s -o "$INSTALL_SH" "$INSTALL_URL"; then
    echo "❌ 错误：无法下载 install.sh。"
    exit 1
fi

# 下载 main.sh
echo "⏳ 正在下载 main.sh ..."
if ! curl -s -o "$MAIN_SH" "$MAIN_URL"; then
    echo "❌ 错误：无法下载 main.sh。"
    exit 1
fi

# 检查文件是否下载成功
if [ ! -f "$INSTALL_SH" ] || [ ! -f "$MAIN_SH" ]; then
    echo "❌ 错误：文件下载失败。"
    exit 1
fi

# 设置文件执行权限
chmod +x "$INSTALL_SH" "$MAIN_SH"
echo "✅ 文件权限已设置。"

# 执行 install.sh
echo "⏳ 正在执行 install.sh ..."
if ! bash "$INSTALL_SH"; then
    echo "❌ 错误：install.sh 执行失败。"
    exit 1
fi
echo "✅ install.sh 执行完成。"

# 设置快捷键 alias r
BASHRC="$HOME/.bashrc"
ALIAS_LINE='alias r="bash /etc/bash/main.sh"'

# 检查是否已存在 alias r
if grep -Fx "$ALIAS_LINE" "$BASHRC" > /dev/null; then
    echo "ℹ️ 快捷键 alias r 已存在，跳过设置。"
else
    echo "$ALIAS_LINE" >> "$BASHRC"
    echo "✅ 已添加快捷键 alias r 到 $BASHRC。"
fi

# 刷新 .bashrc 并直接执行 main.sh
echo "⏳ 正在刷新 .bashrc 并启动 main.sh ..."
echo 'alias r="bash /etc/bash/main.sh"' >> ~/.bashrc && source ~/.bashrc && bash /etc/bash/main.sh
echo "✅ 设置完成！您现在可以使用 'r' 命令唤醒转发规则管理器。"
