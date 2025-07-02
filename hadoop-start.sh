#!/bin/bash
# 文件名：hadoop-cluster.sh
# 功能：智能部署Hadoop容器集群，支持动态端口分配和高可用配置

# 启用严格错误检查
set -eo pipefail

# 配置颜色输出
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
NC='\033[0m'

# 全局配置
CONFIG_FILE=hadoop-env.conf
NETWORK_NAME="hadoop-ha-network"
IMAGE="szcq/hadoop:2.7.7-ha-beta"
PREFIX="172.23.0."
OFFSET=3
MAX_PORT_RETRY=15  # 单端口最大重试次数

# 服务端口定义
declare -A SERVICE_PORTS=(
    ["ZOO_SERVER"]="2181 2888 3888"
    ["JOURNAL_NODE"]="8485"
    ["ACTIVE_NAME_NODE"]="50070"
    ["STANDBY_NAME_NODE"]="50070"
    ["JOB_HISTORY_SERVER"]="19888" 
    ["ACTIVE_RESOURCE_MANAGER"]="8088"
    ["STANDBY_RESOURCE_MANAGER"]="8088"
)

# 错误处理函数
handle_error() {
    echo -e "${RED}错误发生在第${BASH_LINENO[0]}行，命令返回码：$?${NC}" >&2
    exit 1
}
trap 'handle_error' ERR

# 检查Docker运行环境
check_docker() {
    if ! systemctl is-active docker &>/dev/null; then
        echo -e "${RED}错误：Docker服务未运行${NC}" >&2
        exit 1
    fi
}

# 智能端口分配
declare -A PORT_MAP
allocate_port() {
    local original=$1
    local current=$original
    local attempt=0

    while (( attempt < MAX_PORT_RETRY )); do
        if ! ss -tuln | grep -q ":${current}\s" && [[ -z ${PORT_MAP[$current]} ]]; then
            PORT_MAP[$current]=1
            echo $current
            return
        fi
        ((current++))
        ((attempt++))
    done
    
    echo -e "${RED}无法为原始端口 ${original} 分配可用端口（最大尝试 ${MAX_PORT_RETRY} 次）${NC}" >&2
    exit 1
}

# 网络创建函数
safe_create_network() {
    echo -e "${BLUE}检查Docker网络...${NC}"
    if sudo docker network inspect $NETWORK_NAME &>/dev/null; then
        echo -e "${YELLOW}网络已存在，跳过创建${NC}"
        return
    fi

    echo -e "${GREEN}创建新网络 ${NETWORK_NAME}...${NC}"
    sudo docker network create \
        --driver=bridge \
        --subnet=${PREFIX}0/24 \
        $NETWORK_NAME
}

# 容器创建函数
create_container() {
    local host_num=$1
    local ip_suffix=$(($host_num + $OFFSET))
    local container_name="hadoop${host_num}"

    # 检查容器是否已存在
    if docker inspect $container_name &>/dev/null; then
        echo -e "${YELLOW}容器 ${container_name} 已存在，跳过创建${NC}"
        return
    fi

    # 生成端口映射
    local port_mappings=""
    declare -A handled_ports
    for role in ${ROLES[$host_num]}; do
        if [[ -n ${SERVICE_PORTS[$role]} ]]; then
            for port in ${SERVICE_PORTS[$role]}; do
                if [[ -z ${handled_ports[$port]} ]]; then
                    allocated=$(allocate_port $port)
                    port_mappings+=" -p ${allocated}:${port}"
                    handled_ports[$port]=$allocated
                fi
            done
        fi
    done

    # IP地址验证
    if (( ip_suffix > 254 )); then
        echo -e "${RED}错误：IP地址 ${PREFIX}${ip_suffix} 无效${NC}" >&2
        exit 1
    fi

    # 执行创建命令
    echo -e "${GREEN}创建容器 ${container_name} [IP: ${PREFIX}${ip_suffix}]${NC}"
    echo -e "映射端口：${port_mappings:-无}"
    
    sudo docker run -d \
        --name $container_name \
        --hostname $container_name \
        --net $NETWORK_NAME \
        --ip ${PREFIX}${ip_suffix} \
        --env-file hadoop-env.conf \
        $port_mappings \
        --privileged \
        $IMAGE
}

# 启动现有容器
start_existing() {
    local containers=($(sudo docker ps -aq --filter "name=^hadoop[0-9]+$"))
    
    if (( ${#containers[@]} == 0 )); then
        echo -e "${YELLOW}没有找到可启动的容器${NC}"
        return
    fi

    echo -e "${BLUE}发现 ${#containers[@]} 个待启动容器：${NC}"
    sudo docker ps -a --filter "name=^hadoop[0-9]+$" \
        --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    read -p "确认启动所有容器？(y/n) " -n 1 confirm
    echo
    [[ $confirm == "y" ]] || exit 0
    
    echo -e "${GREEN}启动容器中...${NC}"
    sudo docker start ${containers[@]}
}

# 解析配置文件
parse_config() {
    declare -gA ROLES
    local all_hosts=()

    while IFS= read -r line; do
        [[ $line =~ ^#|^$ ]] && continue
        IFS='=' read -r key value <<< "$line"
        [[ -z $key || -z $value ]] && continue

        IFS=',' read -ra hosts <<< "$value"
        for host in "${hosts[@]}"; do
            if [[ $host =~ hadoop([0-9]+) ]]; then
                local num=${BASH_REMATCH[1]}
                all_hosts+=($num)
                case $key in
                    ZOO_SERVER|JOURNAL_NODE|JOB_HISTORY_SERVER|ACTIVE_NAME_NODE| \
                    STANDBY_NAME_NODE|ACTIVE_RESOURCE_MANAGER|STANDBY_RESOURCE_MANAGER| \
                    DATA_NODE|NODE_MANAGER)
                        ROLES[$num]+=" $key"
                        ;;
                esac
            fi
        done
    done < "$CONFIG_FILE"

    NUM_CONTAINERS=$(printf "%s\n" "${all_hosts[@]}" | sort -nr | head -1)
    SORTED_HOSTS=($(printf "%s\n" "${all_hosts[@]}" | sort -nu))
}

# 显示Active NameNode访问方式
show_active_nn_access() {
    local active_nn=""
    # 遍历排序后的主机列表
    for host_num in "${SORTED_HOSTS[@]}"; do
        # 使用正则表达式匹配角色配置，注意保留前后空格防止子串误判
        if [[ " ${ROLES[$host_num]} " =~ " ACTIVE_NAME_NODE " ]]; then
            active_nn="hadoop${host_num}"
            break  # 找到第一个Active节点即退出
        fi
    done

    # 输出访问命令
    if [[ -n "$active_nn" ]]; then
        echo -e "\n${GREEN}可以使用以下命令进入Active NameNode容器：${NC}"
        echo -e "${BLUE}sudo docker exec -it ${active_nn} /bin/bash${NC}"
        echo -e "\n${GREEN}提示：使用 exit 命令可退出容器终端${NC}"
        echo -e "容器中初始化集群命令：${BLUE}cluster-init.sh${NC}"
        echo -e "容器中启动集群命令：${BLUE}cluster-start.sh${NC}"
        echo -e "\n${GREEN}提示：初始化集群脚本包含启动集群功能，无需在初始化后手动启动集群${NC}"
        echo -e "\n${GREEN}可以使用以下命令快速初始化集群${NC}"
        echo -e "${BLUE}sudo docker exec -it ${active_nn} cluster-init.sh${NC}"
    else
        echo -e "\n${YELLOW}警告：未检测到Active NameNode配置，请检查："
        echo -e "1. 配置文件中是否包含 ACTIVE_NAME_NODE 配置项"
        echo -e "2. 主机编号是否遵循 hadoop<数字> 格式${NC}"
    fi
}

# 主执行流程
main() {
    check_docker
    
    if (( $# == 0 )); then
        start_existing
        source $CONFIG_FILE
        echo -e "\n${GREEN}启动集群命令：${NC}"
        echo -e "${BLUE}sudo docker exec -it ${ACTIVE_NAME_NODE} cluster-start.sh${NC}"
        return
    fi

    # 初始化模式
    echo -e "${BLUE}初始化集群模式...${NC}"
    
    # 验证配置文件
    [[ -f $CONFIG_FILE ]] || {
        echo -e "${RED}错误：配置文件 $CONFIG_FILE 不存在${NC}" >&2
        exit 1
    }

    parse_config
    safe_create_network
    
    # 批量创建容器
    for host_num in "${SORTED_HOSTS[@]}"; do
        create_container $host_num
    done

    # 最终状态验证
    echo -e "${GREEN}容器状态检查：${NC}"
    sudo docker ps -a --filter "name=^hadoop[0-9]+$" \
        --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Networks}}"

    show_active_nn_access
}

# 执行主程序
main "$@"
