#!/bin/bash

# =================配置区域=================
REPO_URL="https://raw.githubusercontent.com/Sakimmoe/Sakim-Monitor/main"
SERVER_DIR="/opt/sakim-server"
AGENT_DIR="/opt/sakim-agent"
# ==========================================

# 1. 安装服务端 (面板)
install_server() {
    echo "=== 开始安装服务端 (Dashboard) ==="
    apt-get update -y && apt-get install -y python3 curl
    
    mkdir -p $SERVER_DIR
    echo "正在拉取服务端代码..."
    curl -s "$REPO_URL/server/server.py" -o $SERVER_DIR/server.py
    curl -s "$REPO_URL/server/index.html" -o $SERVER_DIR/index.html
    
    cat > /etc/systemd/system/sakim-server.service <<EOF
[Unit]
Description=Sakim Monitor Server
After=network.target

[Service]
Type=simple
WorkingDirectory=$SERVER_DIR
ExecStart=/usr/bin/python3 $SERVER_DIR/server.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sakim-server
    systemctl restart sakim-server
    
    echo "✅ 服务端安装完成！"
    echo "请在浏览器访问: http://你的服务器IP:3000"
}

# 2. 安装采集端 (Agent)
install_agent() {
    echo "=== 开始安装采集端 (Agent) ==="
    read -p "请输入这台服务器的名称 (如: Debian-01): " SERVER_ID
    read -p "请输入服务端的API地址 (如: http://1.2.3.4:3000/api/report): " API_URL
    
    apt-get update -y && apt-get install -y curl jq iproute2 bc
    
    mkdir -p $AGENT_DIR
    curl -s "$REPO_URL/agent/agent.sh" -o $AGENT_DIR/agent.sh
    chmod +x $AGENT_DIR/agent.sh
    
    sed -i "s|{SERVER_ID}|$SERVER_ID|g" $AGENT_DIR/agent.sh
    sed -i "s|{API_URL}|$API_URL|g" $AGENT_DIR/agent.sh
    
    cat > /etc/systemd/system/sakim-agent.service <<EOF
[Unit]
Description=Sakim Monitor Agent
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash $AGENT_DIR/agent.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sakim-agent
    systemctl restart sakim-agent
    
    echo "✅ 采集端安装完成！已在后台运行。"
}

# 菜单界面
clear
echo "================================="
echo "   Sakim-Monitor 探针一键安装"
echo "================================="
echo "1. 安装 面板端 (接收数据并展示网页)"
echo "2. 安装 采集端 (监控本机并发送数据)"
echo "0. 退出"
echo "================================="
read -p "请输入选项 (0-2): " choice

case $choice in
    1) install_server ;;
    2) install_agent ;;
    0) exit 0 ;;
    *) echo "无效输入!" ;;
esac
