#!/bin/bash

if [ "$(hostname)" != "${ACTIVE_NAME_NODE}" ]; then
    exit $?
fi

# 切换到应用用户环境
if [ "$(whoami)" != "yjrszcq" ]; then
    exec sudo -u yjrszcq "$0" "$@"
    exit $?
fi

# 配置解析函数
parse_config() {
  source /opt/cluster.conf
  source /opt/cluster.env
  ZOO_SERVERS=(${ZOO_SERVER//,/ })
  JOURNAL_NODES=(${JOURNAL_NODE//,/ })
  DATA_NODES=(${DATA_NODE//,/ })
  NODE_MANAGERS=(${NODE_MANAGER//,/ })
}

# 检测安装路径
ZK_HOME=${ZOOKEEPER_HOME}
HD_HOME=${HADOOP_HOME}

# 主机存活检查函数
MAX_RETRIES=10  # 最大重试次数
RETRY_INTERVAL=10  # 重试间隔（秒）

# 存活检查函数
check_hosts_alive() {
  all_hosts=(
    ${ZOO_SERVERS[@]} 
    ${JOURNAL_NODES[@]} 
    $JOB_HISTORY_SERVER 
    $ACTIVE_NAME_NODE $STANDBY_NAME_NODE
    $ACTIVE_RESOURCE_MANAGER $STANDBY_RESOURCE_MANAGER
    ${DATA_NODES[@]}
    ${NODE_MANAGERS[@]}
  )
  
  echo "开始持续节点存活检测..."
  
  for host in ${all_hosts[@]}; do
    attempt=1
    until check_host_ssh $host; do
      if [ $attempt -ge $MAX_RETRIES ]; then
        echo "错误: 节点 $host 超过最大重试次数仍未就绪!"
        exit 1
      fi
      echo "等待 $host 上线 ($attempt/$MAX_RETRIES)..."
      sleep $RETRY_INTERVAL
      ((attempt++))
    done
  done
  echo "所有节点已确认在线"
}

# 使用SSH检测
check_host_ssh() {
  local host=$1
  # 排除本地节点的SSH检查
  if [ "$host" == "$(hostname)" ]; then
    return 0
  fi
  
  ssh -o ConnectTimeout=5 -q $host exit
  if [ $? -eq 0 ]; then
    return 0
  else
    return 1
  fi
}

# Zookeeper初始化函数
init_zookeeper() {
  echo "初始化Zookeeper集群..."
  
  for server in ${ZOO_SERVERS[@]}; do
    echo "在 $server 初始化Zookeeper..."
    ssh $server "/scripts/cluster-cmd.sh zookeeper start"
  done
  sleep 2
  # 验证初始化状态
  for server in ${ZOO_SERVERS[@]}; do
    ssh $server "/scripts/cluster-cmd.sh zookeeper status" | grep -E "Mode: leader|Mode: follower"
    if [ $? -ne 0 ]; then
      echo "警告：$server 节点Zookeeper状态异常"
      exit 1
    fi
  done

}


# HDFS初始化函数
init_hdfs() {
  echo "格式化ZookeeperFC..."
  ssh $ACTIVE_NAME_NODE "/scripts/cluster-cmd.sh hdfs init zkfc"

  echo "格式化NameNode..."
  ssh $ACTIVE_NAME_NODE "/scripts/cluster-cmd.sh hdfs init namenode"

  echo "启动NameNodes..."
  ssh $ACTIVE_NAME_NODE "/scripts/cluster-cmd.sh hdfs start namenode"

  echo "同步元数据到Standby NN..."
  ssh $STANDBY_NAME_NODE "/scripts/cluster-cmd.sh hdfs init standby"

  echo "启动Standby NN..."
  ssh $STANDBY_NAME_NODE "/scripts/cluster-cmd.sh hdfs start namenode"
}

# 服务启动主流程
start_services() {
  echo "初始化ZooKeeper服务..."
  init_zookeeper

  echo "启动JournalNodes..."
  for jnode in ${JOURNAL_NODES[@]}; do
    ssh $jnode "/scripts/cluster-cmd.sh hdfs start journalnode"
  done

  sleep 5  # 等待JN服务初始化

  echo "初始化HDFS服务..."
  init_hdfs

  echo "启动ZKFC守护进程..."
  ssh $ACTIVE_NAME_NODE "/scripts/cluster-cmd.sh hdfs start zkfc"
  ssh $STANDBY_NAME_NODE "/scripts/cluster-cmd.sh hdfs start zkfc"

  echo "启动ResourceManagers..."
  ssh $ACTIVE_RESOURCE_MANAGER "/scripts/cluster-cmd.sh yarn start resourcemanager"
  ssh $STANDBY_RESOURCE_MANAGER "/scripts/cluster-cmd.sh yarn start resourcemanager"

  echo "启动DataNodes..."
  for dnode in ${DATA_NODES[@]}; do
    ssh $dnode "/scripts/cluster-cmd.sh hdfs start datanode"
  done

  echo "启动NodeManagers..."
  for nnode in ${NODE_MANAGERS[@]}; do
    ssh $nnode "/scripts/cluster-cmd.sh yarn start nodemanager"
  done

  echo "启动JobHistoryServer..."
  ssh $JOB_HISTORY_SERVER "/scripts/cluster-cmd.sh mapred start historyserver"
}

# 主执行流程
parse_config
check_hosts_alive
start_services

echo "集群首次启动完成!"
echo "验证命令："
echo "容器内：cluster-status.sh"
echo "容器外：sudo docker exec -it ${ACTIVE_NAME_NODE} cluster-status.sh"
