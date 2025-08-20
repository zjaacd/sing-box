#!/bin/bash
# install.sh - 一键安装 Xray Reality VLESS 节点

set -e

# ====== 固定参数 ======
XRAY_VERSION="v25.8.3"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/usr/local/etc/xray"
LOG_DIR="/var/log/xray"
UUID="33d0237c-2355-42c3-be86-54219aab8c6e"
PORT=40218
PRIVATE_KEY="replace_with_your_private_key"
PUBLIC_KEY="Ej_2eEwk8EjlQhPzK3uP70lKnb-1L9zytQ8bkhuQkhI"
SHORT_ID="1234567890abcdef"
SNI="www.ebay.com"

# ====== 安装依赖 ======
apt update -y
apt install -y wget curl unzip

# ====== 安装 Xray ======
mkdir -p $CONFIG_DIR $LOG_DIR
wget -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip
unzip -o /tmp/xray.zip -d /tmp/xray
install -m 755 /tmp/xray/xray $INSTALL_DIR/xray
rm -rf /tmp/xray*

# ====== 生成 systemd 服务 ======
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=$INSTALL_DIR/xray run -config $CONFIG_DIR/config.json
Restart=on-failure
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# ====== 写入配置文件 ======
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

# ====== 重启服务 ======
systemctl daemon-reexec
systemctl enable xray
systemctl restart xray

echo "✅ Xray Reality 安装完成！"
echo "服务器已启动，节点信息如下："
echo "--------------------------------------------------"
echo "vless://$UUID@$(curl -s ifconfig.me):$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SNI&fp=chrome&pbk=$PUBLIC_KEY&type=tcp&headerType=none#Reality-Node"
echo "--------------------------------------------------"
