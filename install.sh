#!/bin/bash

# 定义颜色
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

# 安装路径与仓库地址
INSTALL_DIR="/opt/sakim-monitor"
SERVICE_FILE="/etc/systemd/system/sakim-agent.service"
# 这里已经替换为你自己的 GitHub 仓库 RAW 地址
REPO_URL="https://raw.githubusercontent.com/Sakimmoe/Sakim-Monitor/main"

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}请使用 root 权限运行此脚本 (sudo bash install.sh)${RESET}"
  exit 1
fi

install_agent() {
    echo -e "${GREEN}=== 开始安装 Sakim-Monitor Agent ===${RESET}"
    
    # 交互式获取配置
    read -p "请输入这台服务器的标识 (例如: US-Debian-01): " SERVER_ID
    read -p "请输入接收数据的 API 地址 (例如: http://1.2.3.4:3000/api/report): " API_URL
    
    if [ -z "$SERVER_ID" ] || [ -z "$API_URL" ]; then
        echo -e "${RED}服务器标识和 API 地址不能为空！${RESET}"
        exit 1
    fi

    # 安装依赖包 (兼容 Debian 11)
    echo -e "${YELLOW}正在安装必要依赖...${RESET}"
    apt-get update -y && apt-get install -y curl jq iproute2 bc
    
    # 创建目录并拉取脚本
    mkdir -p $INSTALL_DIR
    echo -e "${YELLOW}正在从 GitHub 拉取 Agent 脚本...${RESET}"
    curl -s "$REPO_URL/agent/agent.sh" -o $INSTALL_DIR/agent.sh
    chmod +x $INSTALL_DIR/agent.sh
    
    # 替换脚本中的占位符配置
    sed -i "s|{SERVER_ID}|$SERVER_ID|g" $INSTALL_DIR/agent.sh
    sed -i "s|{API_URL}|$API_URL|g" $INSTALL_DIR/agent.sh
    
    # 写入 Systemd 守护服务
    echo -e "${YELLOW}配置守护进程...${RESET}"
    cat > $SERVICE_FILE <<EOF
[Unit]
Description=Sakim Monitor Agent
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash $INSTALL_DIR/agent.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    # 启动服务
    systemctl daemon-reload
    systemctl enable sakim-agent
    systemctl restart sakim-agent
    
    echo -e "${GREEN}安装完成！探针 Agent 已在后台持续运行。${RESET}"
    echo -e "可以使用命令 ${YELLOW}systemctl status sakim-agent${RESET} 查看运行状态。"
}

uninstall_agent() {
    echo -e "${RED}正在卸载 Agent...${RESET}"
    systemctl stop sakim-agent
    systemctl disable sakim-agent
    rm -f $SERVICE_FILE
    systemctl daemon-reload
    rm -rf $INSTALL_DIR
    echo -e "${GREEN}卸载清理完成！${RESET}"
}

update_agent() {
    echo -e "${YELLOW}正在更新 Agent...${RESET}"
    curl -s "$REPO_URL/agent/agent.sh" -o $INSTALL_DIR/agent.sh
    chmod +x $INSTALL_DIR/agent.sh
    
    # 因为更新覆盖了脚本，为了防止配置丢失，这里需要提示（高级版本可以用配置文件分离，小白版先简单处理）
    echo -e "${YELLOW}注意：更新后如果 API 地址有变，请重新执行安装步骤覆盖配置。${RESET}"
    
    systemctl restart sakim-agent
    echo -e "${GREEN}更新成功并已重启服务！${RESET}"
}

# 绘制主菜单
clear
echo -e "${GREEN}=====================================${RESET}"
echo -e "${YELLOW}   Sakim-Monitor 探针一键管理脚本    ${RESET}"
echo -e "${GREEN}=====================================${RESET}"
echo "1. 安装 Agent (数据采集端)"
echo "2. 卸载 Agent"
echo "3. 升级 Agent 代码"
echo "0. 退出"
echo -e "${GREEN}=====================================${RESET}"
read -p "请输入数字 (0-3): " choice

case $choice in
    1) install_agent ;;
    2) uninstall_agent ;;
    3) update_agent ;;
    0) exit 0 ;;
    *) echo -e "${RED}无效输入!${RESET}" ;;
esac
