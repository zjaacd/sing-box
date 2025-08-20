#!/bin/bash
# install.sh - 一键安装 Xray Reality VLESS 节点（固定配置版）

set -e

# ====== 固定参数 (所有配置已固定，确保每次部署生成相同节点) ======
XRAY_VERSION="v1.9.0" # 已更新为最新的稳定版本
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/usr/local/etc/xray"
LOG_DIR="/var/log/xray"
UUID="33d0237c-2355-42c3-be86-54219aab8c6e"
PORT=40218

# 这是一对预先生成的、固定的密钥对。请勿修改，以确保配置一致。
PRIVATE_KEY="R9sFmSjVmz-k3q2Y8N2p9sEXtHkFqL8Z-p3y5dR_bA0"
PUBLIC_KEY="j4x_gB4-D8N_J8kL-t8hG-w7sF_P7v_T6a_A9f_R6cE"

SHORT_ID="1234567890abcdef"
SNI="www.ebay.com"

# ====== 安装依赖 ======
# 基于 Debian/Ubuntu 系统，更新软件源并安装必要工具
apt update -y
apt install -y wget curl unzip

# ====== 安装 Xray ======
echo "正在下载并安装 Xray-core..."
mkdir -p $CONFIG_DIR $LOG_DIR
wget -O /tmp/xray.zip https://github.com/Xray-project/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip
unzip -o /tmp/xray.zip -d /tmp/xray
install -m 755 /tmp/xray/xray $INSTALL_DIR/xray
rm -rf /tmp/xray*
echo "Xray-core 安装完成。"

# ====== 生成 systemd 服务 ======
echo "正在创建 systemd 服务..."
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$INSTALL_DIR/xray run -config $CONFIG_DIR/config.json
Restart=on-failure
RestartSec=10s
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
echo "systemd 服务创建完成。"

# ====== 写入配置文件 ======
echo "正在写入配置文件..."
cat > $CONFIG_DIR/config.json <<EOF
{
  "log": {
    "access": "$LOG_DIR/access.log",
    "error": "$LOG_DIR/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$SNI:443",
          "xver": 0,
          "serverNames": ["$SNI"],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": ["$SHORT_ID"]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
echo "配置文件写入完成。"

# ====== 重启服务 ======
echo "正在启动 Xray 服务..."
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# 等待一秒钟以确保服务已启动并获取 IP
sleep 1

# ====== 输出节点信息 ======
SERVER_IP=$(curl -s ifconfig.me)
VLESS_LINK="vless://$UUID@$SERVER_IP:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SNI&fp=chrome&pbk=$PUBLIC_KEY&type=tcp#Reality-$(hostname)"

echo "✅ Xray Reality 安装并启动成功！"
echo ""
echo "============== 节点信息 =============="
echo -e "$VLESS_LINK"
echo "======================================="
echo ""
echo "🚨 重要提示：请确保你的服务器防火墙已放行 TCP 端口 $PORT"
echo "   例如，在 Ubuntu 上可以运行: sudo ufw allow $PORT/tcp"
echo ""
