#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查是否安装了 iptables
function check_firewall_installed() {
    if sudo iptables -V >/dev/null 2>&1; then
        echo -e "${GREEN}iptables 已安装，继续执行脚本...${NC}"
    elif sudo nft -v 2>&1; then
        echo -e "${RED}本脚本不适用 nftables，请安装 iptables.${NC}"
        exit 1
    else
        echo -e "${YELLOW}iptables 和 nftables 都未安装，正在安装 iptables...${NC}"
        sudo apt update
        sudo apt install -y iptables
        if sudo iptables -V >/dev/null 2>&1; then
            echo -e "${GREEN}iptables 安装完成，继续执行脚本...${NC}"
        else
            echo -e "${RED}安装 iptables 失败，请检查系统配置！${NC}"
            exit 1
        fi
    fi
}

# 显示所有Docker容器及其暴露的端口
function show_docker_ports() {
    echo -e "${GREEN}正在列出所有Docker容器及其暴露的端口...${NC}"
    docker ps --format "table {{.Names}}\t{{.Ports}}" | while read line; do
        echo "$line" | sed -r 's/([0-9]+)\/tcp/\033[1;33m\1\/tcp\033[0m/'
    done
}

# 显示当前防火墙入站规则
function show_firewall_rules() {
    echo -e "${GREEN}当前防火墙入站规则：${NC}"
    # 使用 iptables -L -n -v 显示规则
    sudo iptables -L INPUT -n -v | sed -r 's/([0-9]+)\/tcp/\033[1;33m\1\/tcp\033[0m/' | column -t
}

# 配置防火墙（增加端口）
function configure_firewall() {
    local ip="$1"
    local port_range="$2"
    echo -e "${GREEN}正在配置防火墙规则...${NC}"
    sudo iptables -A INPUT -s "$ip" -p tcp --dport "$port_range" -j ACCEPT
}

# 配置防火墙（阻止端口）
function block_firewall() {
    local ip="$1"
    local port_range="$2"
    echo -e "${GREEN}正在阻止端口...${NC}"
    sudo iptables -A INPUT -s "$ip" -p tcp --dport "$port_range" -j DROP
}

# 删除防火墙规则（删除开放端口）
function delete_firewall_rule() {
    local port_range="$1"
    echo -e "${GREEN}正在删除防火墙规则...${NC}"
    sudo iptables -D INPUT -p tcp --dport "$port_range" -j ACCEPT
}

# 删除防火墙规则（删除阻止端口）
function delete_block_rule() {
    local port_range="$1"
    echo -e "${GREEN}正在删除端口阻止规则...${NC}"
    sudo iptables -D INPUT -p tcp --dport "$port_range" -j DROP
}

# 调换防火墙规则的优先级顺序
function swap_rule_priority() {
    local rule_id1="$1"
    local rule_id2="$2"
    echo -e "${GREEN}iptables 不支持如 nftables 的规则 swap 功能，请手动编辑规则优先级。${NC}"
}

# 主流程
check_firewall_installed

while true; do
    show_docker_ports
    show_firewall_rules

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
            read -p "请输入要删除的开放端口范围: " port_range
            delete_firewall_rule "$port_range"
            show_firewall_rules
            ;;
        2)
            read -p "请输入需要开放的端口范围: " port_range
            read -p "请输入需要该端口开放的IP: " ip
            configure_firewall "$ip" "$port_range"
            show_firewall_rules
            ;;
        3)
            read -p "请输入需要阻止的端口范围: " port_range
            read -p "请输入需要阻止端口的IP: " ip
            block_firewall "$ip" "$port_range"
            show_firewall_rules
            ;;
        4)
            read -p "请输入要删除的端口阻止范围: " port_range
            delete_block_rule "$port_range"
            show_firewall_rules
            ;;
        5)
            read -p "请输入要调换的规则ID1: " rule_id1
            read -p "请输入要调换的规则ID2: " rule_id2
            swap_rule_priority "$rule_id1" "$rule_id2"
            show_firewall_rules
            ;;
        0)
            echo "退出程序..."
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选项，请重新选择。${NC}"
            ;;
    esac
done