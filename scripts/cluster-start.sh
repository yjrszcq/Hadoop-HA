#!/bin/bash

if [ "$(hostname)" != "${ACTIVE_NAME_NODE}" ]; then
    exit $?
fi

if [ "$(whoami)" != "yjrszcq" ]; then
    exec sudo -u yjrszcq "$0" "$@"
    exit $?
fi

parse_config() {
  source /opt/cluster.conf
  source /opt/cluster.env
  ZOO_SERVERS=(${ZOO_SERVER//,/ })
  JOURNAL_NODES=(${JOURNAL_NODE//,/ })
  DATA_NODES=(${DATA_NODE//,/ })
  NODE_MANAGERS=(${NODE_MANAGER//,/ })
}

ZK_HOME=${ZOOKEEPER_HOME}
HD_HOME=${HADOOP_HOME}

MAX_RETRIES=10  # 最大重试次数
RETRY_INTERVAL=10  # 重试间隔（秒）

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

start_services() {
  echo "启动ZooKeeper服务..."
  for server in ${ZOO_SERVERS[@]}; do
    ssh $server "/scripts/cluster-cmd.sh zookeeper start"
  done

  echo "启动JournalNodes..."
  for jnode in ${JOURNAL_NODES[@]}; do
    ssh $jnode "/scripts/cluster-cmd.sh hdfs start journalnode"
  done

  sleep 3

  echo "唤醒NameNodes..."
  ssh $ACTIVE_NAME_NODE "/scripts/cluster-cmd.sh hdfs start namenode"
  ssh $STANDBY_NAME_NODE "/scripts/cluster-cmd.sh hdfs start namenode"

  echo "唤醒ZKFC进程..."
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

# 主流程
parse_config
check_hosts_alive
start_services

echo "集群日常启动完成!"
echo "运行状态检查："
echo "容器内：cluster-status.sh"
echo "容器外：sudo docker exec -it ${ACTIVE_NAME_NODE} cluster-status.sh"
