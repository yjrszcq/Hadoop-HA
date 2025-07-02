#!/bin/bash
# 保存为 hadoop-stop.sh

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

show_usage() {
    echo -e "${BLUE}使用方法:${RESET}"
    echo "  没有参数：停止所有hadoop容器"
    echo "  -r 参数 ：停止并删除所有hadoop容器"
    echo -e "\n示例:"
    echo "  $0     # 仅停止容器"
    echo "  $0 -r  # 停止并删除容器"
    exit 1
}

# 检查参数合法性
if [ $# -gt 1 ] || ([ $# -eq 1 ] && [ "$1" != "-r" ]); then
    echo -e "${RED}错误：无效参数${RESET}"
    show_usage
fi

# 获取所有hadoop容器ID
container_ids=$(sudo docker ps -aq --filter "name=^hadoop[0-9]+$" 2>/dev/null)

# 无容器存在时的处理
if [ -z "$container_ids" ]; then
    echo -e "${YELLOW}没有找到任何hadoop容器${RESET}"
    exit 0
fi

# 获取容器列表
echo -e "${BLUE}目标容器列表：${RESET}"
sudo docker ps -a --filter "name=^hadoop[0-9]+$" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 停止所有容器
stop_containers() {
    echo -e "\n${YELLOW}正在停止容器...${RESET}"
    sudo docker stop $container_ids
}

# 删除容器函数
delete_containers() {
    echo -e "\n${YELLOW}确认要删除容器吗？${RESET}"
    read -p "这将删除所有hadoop容器！(y/n) " confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo -e "${RED}正在删除容器...${RESET}"
        sudo docker rm $container_ids
        echo -e "${GREEN}所有容器已删除${RESET}"
    else
        echo -e "${GREEN}取消删除操作${RESET}"
    fi
}

# 根据参数执行操作
if [ "$1" == "-r" ]; then
    stop_containers
    delete_containers
else
    stop_containers
    echo -e "\n${GREEN}所有容器已停止${RESET}"
    echo -e "${BLUE}当前容器状态：${RESET}"
    sudo docker ps -a --filter "name=^hadoop[0-9]+$" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
fi

# 检查进程残留
echo -e "\n${BLUE}检查残留进程（正常应无输出）：${RESET}"
ps -ef | grep -E 'JournalNode|NameNode|ResourceManager|DataNode|NodeManager|QuorumPeerMain'
