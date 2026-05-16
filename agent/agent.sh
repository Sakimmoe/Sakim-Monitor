#!/bin/bash

# 这两个变量会被 install.sh 自动替换，请勿手动修改这里的占位符
API_URL="{API_URL}"
SERVER_ID="{SERVER_ID}"

# 获取静态信息
OS_NAME=$(cat /etc/os-release | grep "PRETTY_NAME" | cut -d '"' -f 2)
ARCH=$(uname -m)
VIRT=$(systemd-detect-virt 2>/dev/null || echo "unknown")

# 主循环
while true; do
    # 1. CPU & 负载
    LOAD=$(cat /proc/loadavg | awk '{print $1}')
    
    # 2. 内存 & Swap
    MEM_TOTAL=$(free -m | awk 'NR==2{print $2}')
    MEM_USED=$(free -m | awk 'NR==2{print $3}')
    SWAP_TOTAL=$(free -m | awk 'NR==3{print $2}')
    SWAP_USED=$(free -m | awk 'NR==3{print $3}')
    
    # 3. 硬盘占用 (只看根目录)
    DISK_TOTAL=$(df -h / | awk 'NR==2{print $2}')
    DISK_USED=$(df -h / | awk 'NR==2{print $3}')
    
    # 4. 进程数 & 连接数
    PROCESS_COUNT=$(ps -e | wc -l)
    CONN_COUNT=$(ss -ant | wc -l)
    
    # 5. 运行时间
    UPTIME=$(awk '{print $1}' /proc/uptime)
    
    # 6. 计算网络实时速度 (寻找默认路由网卡)
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
    if [ -n "$INTERFACE" ] && [ -d "/sys/class/net/$INTERFACE/statistics" ]; then
        RX1=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
        TX1=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
        sleep 1 # 间隔1秒
        RX2=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
        TX2=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
        
        # KB/s
        RX_SPEED=$(( (RX2 - RX1) / 1024 ))
        TX_SPEED=$(( (TX2 - TX1) / 1024 ))
        
        # 自开机以来的总流量消耗 (GB)
        TOTAL_RX=$(echo "scale=2; $RX2 / 1024 / 1024 / 1024" | bc)
        TOTAL_TX=$(echo "scale=2; $TX2 / 1024 / 1024 / 1024" | bc)
    else
        sleep 1
        RX_SPEED=0; TX_SPEED=0; TOTAL_RX=0; TOTAL_TX=0
    fi
    
    # 7. Ping 延迟 (三大运营商，超时设为1秒)
    # 电信: 114.114.114.114, 联通: 119.29.29.29, 移动: 223.5.5.5
    PING_CT=$(ping -c 1 -W 1 114.114.114.114 | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}' || echo "0")
    PING_CU=$(ping -c 1 -W 1 119.29.29.29 | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}' || echo "0")
    PING_CM=$(ping -c 1 -W 1 223.5.5.5 | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}' || echo "0")

    # 组装 JSON 数据
    JSON_PAYLOAD=$(cat <<EOF
{
  "server_id": "$SERVER_ID",
  "os": "$OS_NAME",
  "arch": "$ARCH",
  "virt": "$VIRT",
  "uptime": $UPTIME,
  "load": "$LOAD",
  "memory": {"total": $MEM_TOTAL, "used": $MEM_USED},
  "swap": {"total": $SWAP_TOTAL, "used": $SWAP_USED},
  "disk": {"total": "$DISK_TOTAL", "used": "$DISK_USED"},
  "network": {
     "rx_speed_kb": $RX_SPEED, 
     "tx_speed_kb": $TX_SPEED,
     "total_rx_gb": $TOTAL_RX,
     "total_tx_gb": $TOTAL_TX
  },
  "connections": $CONN_COUNT,
  "processes": $PROCESS_COUNT,
  "ping": {
     "telecom": "$PING_CT",
     "unicom": "$PING_CU",
     "mobile": "$PING_CM"
  }
}
EOF
)

    # 发生请求到 API，静默模式忽略输出
    curl -s -X POST -H "Content-Type: application/json" -d "$JSON_PAYLOAD" $API_URL > /dev/null
    
    # 额外等待1秒，控制整体上报频率约为每 2~3 秒一次
    sleep 1
done
