#!/bin/bash
# =========================================================
# Realm 转发规则管理器终结版 (TOML)
# 功能：
#  - 可选择监听 IP（0.0.0.0/127.0.0.1/本机公网 IP）
#  - 双重校验端口是否占用
#  - 支持循环添加多条规则
#  - 配置文件为 TOML 格式
#  - 自动备份配置文件
#  - 查看/删除规则，日志记录
# =========================================================

CONFIG_PATH="/etc/realm/config.toml"
REALM_SERVICE="realm"
RULE_LOG="/var/log/realm_rules.log"

# 创建日志文件
[ ! -f "$RULE_LOG" ] && touch "$RULE_LOG" && chmod 644 "$RULE_LOG"

# 检查配置文件可写
if [ ! -w "$CONFIG_PATH" ]; then
    echo "❌ 错误：无法写入 $CONFIG_PATH。请使用 root 权限运行。"
    exit 1
fi

# 端口检查函数
check_port() {
    netstat -tuln 2>/dev/null | grep -q ":$1[ \t]" && return 0 || return 1
}

# IP 是否属于本机接口
validate_ip() {
    local ip=$1
    [[ "$ip" == "0.0.0.0" || "$ip" == "127.0.0.1" ]] && return 0
    local ips
    ips=$(ip -o -4 addr show | awk '{print $4}' | cut -d/ -f1)
    echo "$ips" | grep -Fxq "$ip" && return 0 || return 1
}

# 远端格式校验
validate_remote() {
    local remote=$1
    [[ "$remote" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]{1,5}$ ]] || \
    [[ "$remote" =~ ^[a-zA-Z0-9.-]+:[0-9]{1,5}$ ]]
}

# 日志记录
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$RULE_LOG"
}

# 端口双重校验
validate_port() {
    local ip=$1
    local port=$2
    ss -tuln | grep -qE "0\.0\.0\.0:$port" && return 1
    ss -tuln | grep -qE "$ip:$port" && return 1
    return 0
}

# 创建规则
create_rule() {
    while true; do
        read -rp "规则名称（例如：hongkong_forward）： " rule_tag
        rule_tag=$(echo "$rule_tag" | tr -d '" ' | tr -s '\t')
        [ -z "$rule_tag" ] && { echo "❌ 规则名称不能为空"; continue; }
        grep -q "tag = \"$rule_tag\"" "$CONFIG_PATH" && { echo "❌ 规则名称已存在"; continue; }
        break
    done

    # 选择监听 IP
    while true; do
        read -rp "监听 IP（0.0.0.0 / 127.0.0.1 / 本机IP）： " listen_ip
        listen_ip=$(echo "$listen_ip" | tr -d ' ')
        if validate_ip "$listen_ip"; then
            break
        else
            echo "❌ 输入的监听 IP $listen_ip 不属于本机"
            echo "ℹ️ 本机有效 IPv4："
            ip -o -4 addr show | awk '{print "   - " $4}' | cut -d/ -f1
        fi
    done

    # 选择监听端口
    while true; do
        read -rp "监听端口（1-65535）： " listen_port
        listen_port=$(echo "$listen_port" | tr -d ' ')
        if ! [[ "$listen_port" =~ ^[0-9]+$ ]] || [ "$listen_port" -lt 1 ] || [ "$listen_port" -gt 65535 ]; then
            echo "❌ 无效端口"
            continue
        fi
        if validate_port "$listen_ip" "$listen_port"; then
            break
        else
            echo "❌ 端口 $listen_port 在 $listen_ip 或 0.0.0.0 已被占用"
        fi
    done

    # 远端地址
    while true; do
        read -rp "远端地址:端口（例如：1.1.1.1:7777 或 ddns.com:8888）： " remote
        remote=$(echo "$remote" | tr -d ' ')
        validate_remote "$remote" && break || echo "❌ 格式错误"
    done

    # 备份配置
    cp "$CONFIG_PATH" "${CONFIG_PATH}.bak"

    # 添加规则到 TOML
    cat <<EOF >> "$CONFIG_PATH"

[[endpoints]]
tag = "$rule_tag"
listen = "$listen_ip:$listen_port"
remote = "$remote"
EOF

    # 重启服务
    if systemctl restart "$REALM_SERVICE" 2>/dev/null; then
        echo "✅ 规则已添加：$rule_tag -> $listen_ip:$listen_port -> $remote"
        log_action "添加规则 [$rule_tag] - 监听: $listen_ip:$listen_port -> $remote"
    else
        echo "❌ 无法重启 $REALM_SERVICE，恢复备份"
        mv "${CONFIG_PATH}.bak" "$CONFIG_PATH"
        exit 1
    fi
}

# 查看规则
list_rules() {
    echo "📋 当前规则："
    if ! grep -q '\[\[endpoints\]\]' "$CONFIG_PATH"; then
        echo "未配置任何规则"
    else
        awk '
        BEGIN { RS="\\[\\[endpoints\\]\\]"; ORS=""; i=0 }
        NR > 1 {
            i++
            match($0, /tag *= *"([^"]+)"/, t)
            match($0, /listen *= *"([^"]+)"/, l)
            match($0, /remote *= *"([^"]+)"/, r)
            printf("%d) [%s]\n   监听: %s\n   远程: %s\n--------------------------\n", i, t[1], l[1], r[1])
        }
        ' "$CONFIG_PATH"
    fi
    read -rp "按回车返回菜单..."
}

# 删除规则
delete_rule() {
    mapfile -t LINE_NUMS < <(grep -n '\[\[endpoints\]\]' "$CONFIG_PATH" | cut -d: -f1)
    total=${#LINE_NUMS[@]}
    [ $total -eq 0 ] && { echo "⚠️ 无可删除规则"; read -rp "按回车返回..."; return; }

    echo "🗑️ 可删除规则："
    for i in "${!LINE_NUMS[@]}"; do
        idx=$((i+1))
        line=${LINE_NUMS[$i]}
        tag=$(sed -n "$((line+1))p" "$CONFIG_PATH" | grep 'tag' | cut -d'"' -f2)
        echo "$idx) $tag"
    done
    echo "0) 取消"
    read -rp "输入要删除规则编号： " num
    if [ "$num" = "0" ]; then return; fi
    [[ ! "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "$total" ] && { echo "❌ 无效"; read -rp "按回车返回..."; return; }

    # 备份配置
    cp "$CONFIG_PATH" "${CONFIG_PATH}.bak"

    start=${LINE_NUMS[$((num-1))]}
    end=$(( num==total ? $(wc -l < "$CONFIG_PATH") : ${LINE_NUMS[$num]} -1 ))
    sed -i "${start},${end}d" "$CONFIG_PATH"

    if systemctl restart "$REALM_SERVICE" 2>/dev/null; then
        echo "✅ 已删除规则 $num"
        log_action "删除规则 [$num]"
    else
        echo "❌ 无法重启服务，恢复备份"
        mv "${CONFIG_PATH}.bak" "$CONFIG_PATH"
        read -rp "按回车返回..."
    fi
}

# 主菜单
while true; do
    clear
    echo "=== Realm 转发规则管理器 v2.5 ==="
    echo "1) 创建规则"
    echo "2) 查看规则"
    echo "3) 删除规则"
    echo "0) 退出"
    echo "============================="
    read -rp "请选择操作： " choice
    case "$choice" in
        1) create_rule ;;
        2) list_rules ;;
        3) delete_rule ;;
        0) exit 0 ;;
        *) echo "❌ 无效选项"; read -rp "按回车继续..." ;;
    esac
done
