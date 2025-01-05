#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查是否安装了 nftables 或 iptables
function check_firewall_installed() {
    # 检查 nftables 是否已安装
    if sudo nft -v >/dev/null 2>&1; then
        echo -e "${GREEN}nftables 已安装，继续执行脚本...${NC}"
    elif sudo iptables -V 2>&1; then
        echo -e "${RED}本脚本不适用 iptables，请安装 nftables.${NC}"
        exit 1
    else
        echo -e "${YELLOW}nftables 和 iptables 都未安装，正在安装 nftables...${NC}"
        sudo apt update
        sudo apt install -y nftables
        if sudo nft -v >/dev/null 2>&1; then
            echo -e "${GREEN}nftables 安装完成，继续执行脚本...${NC}"
        else
            echo -e "${RED}安装 nftables 失败，请检查系统配置！${NC}"
            exit 1
        fi
    fi
}


# 显示所有Docker容器及其暴露的端口
function show_docker_ports() {
    echo -e "${GREEN}正在列出所有Docker容器及其暴露的端口...${NC}"
    docker ps --format "table {{.Names}}\t{{.Ports}}" | while read line; do
        echo "$line" | sed -r 's/([0-9]+)\/tcp/\033[1;33m\1\/tcp\033[0m/' # 高亮显示端口
    done
}

# 显示当前防火墙入站规则
function show_firewall_rules() {
    echo -e "${GREEN}当前防火墙入站规则：${NC}"
    sudo nft list ruleset | grep -A 10 'chain input' | sed -r 's/([0-9]+)\/tcp/\033[1;33m\1\/tcp\033[0m/' | column -t
}

# 配置防火墙（增加端口）
function configure_firewall() {
    local ip="$1"
    local port_range="$2"
    # 根据 IP 和端口范围来设置防火墙规则
    echo -e "${GREEN}正在配置防火墙规则...${NC}"
    sudo nft add rule inet filter input ip saddr $ip tcp dport $port_range accept
}

# 配置防火墙（阻止端口）
function block_firewall() {
    local ip="$1"
    local port_range="$2"
    # 根据 IP 和端口范围来设置防火墙规则
    echo -e "${GREEN}正在阻止端口...${NC}"
    sudo nft add rule inet filter input ip saddr $ip tcp dport $port_range drop
}

# 删除防火墙规则（删除开放端口）
function delete_firewall_rule() {
    local port_range="$1"
    echo -e "${GREEN}正在删除防火墙规则...${NC}"
    sudo nft delete rule inet filter input tcp dport $port_range accept
}

# 删除防火墙规则（删除阻止端口）
function delete_block_rule() {
    local port_range="$1"
    echo -e "${GREEN}正在删除端口阻止规则...${NC}"
    sudo nft delete rule inet filter input tcp dport $port_range drop
}

# 调换防火墙规则的优先级顺序
function swap_rule_priority() {
    local rule_id1="$1"
    local rule_id2="$2"
    echo -e "${GREEN}正在调换防火墙规则优先级顺序...${NC}"
    sudo nft swap rule inet filter input handle $rule_id1 handle $rule_id2
}

# 主流程
check_firewall_installed  # 检查防火墙软件是否安装

while true; do
    # 1. 显示所有Docker容器及其暴露的端口
    show_docker_ports

    # 2. 显示当前防火墙的入站规则
    show_firewall_rules

    # 3. 提示用户选择操作
    echo -e "${YELLOW}请选择要执行的操作:${NC}"
    echo "1: 删除端口开放配置"
    echo "2: 增加端口开放配置"
    echo "3: 增加端口阻止配置"
    echo "4: 删除端口阻止配置"
    echo "5: 调换防火墙优先级顺序"
    echo "0: 退出"
    read -p "请输入操作编号: " action

    case "$action" in
        1)
            # 删除端口开放配置
            read -p "请输入要删除的开放端口范围（如 8080 或 8080-8090 或 8080,8090）： " port_range
            delete_firewall_rule "$port_range"
            show_firewall_rules
            ;;
        2)
            # 增加端口开放配置
            read -p "请输入需要开放的端口范围（如 8080 或 8080-8090 或 8080,8090）： " port_range
            read -p "请输入需要该端口开放的IP（如 0.0.0.0/0, 192.168.1.100, fd00::/64）： " ip
            configure_firewall "$ip" "$port_range"
            show_firewall_rules
            ;;
        3)
            # 增加端口阻止配置
            read -p "请输入需要阻止的端口范围（如 8080 或 8080-8090 或 8080,8090）： " port_range
            read -p "请输入需要阻止端口的IP（如 0.0.0.0/0, 192.168.1.100, fd00::/64）： " ip
            block_firewall "$ip" "$port_range"
            show_firewall_rules
            ;;
        4)
            # 删除端口阻止配置
            read -p "请输入要删除的端口阻止范围（如 8080 或 8080-8090 或 8080,8090）： " port_range
            delete_block_rule "$port_range"
            show_firewall_rules
            ;;
        5)
            # 调换防火墙优先级顺序
            read -p "请输入要调换的规则ID1: " rule_id1
            read -p "请输入要调换的规则ID2: " rule_id2
            swap_rule_priority "$rule_id1" "$rule_id2"
            show_firewall_rules
            ;;
        0)
            # 退出
            echo "退出程序..."
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选项，请重新选择。${NC}"
            ;;
    esac
done

