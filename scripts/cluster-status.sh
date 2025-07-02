#!/bin/bash

if [ "$(whoami)" != "yjrszcq" ]; then
    exec sudo -u yjrszcq "$0" "$@"
    exit $?
fi

source /opt/cluster.conf
source /opt/cluster.env
ZOO_SERVERS=(${ZOO_SERVER//,/ })
JOURNAL_NODES=(${JOURNAL_NODE//,/ })
DATA_NODES=(${DATA_NODE//,/ })
NODE_MANAGERS=(${NODE_MANAGER//,/ })

all_hosts=(
    ${ZOO_SERVERS[@]}
    ${JOURNAL_NODES[@]}
    $JOB_HISTORY_SERVER
    $ACTIVE_NAME_NODE $STANDBY_NAME_NODE
    $ACTIVE_RESOURCE_MANAGER $STANDBY_RESOURCE_MANAGER
    ${DATA_NODES[@]}
    ${NODE_MANAGERS[@]}
)

declare -A host_set
unique_hosts=()
for host in "${all_hosts[@]}"; do
    if [[ ! "${host_set[$host]+_}" ]]; then
        unique_hosts+=("$host")
        host_set[$host]=1
    fi
done

IFS=$'\n'
sorted_hosts=($(sort -V <<<"${unique_hosts[*]}")) # 关键修改点：增加 -V 参数
unset IFS

echo "开始检测..."
echo ""

echo "========== JPS =========="
echo ""
for host in ${sorted_hosts[@]}; do
    echo "---------- $host ----------"
    ssh $host $JAVA_HOME/bin/jps
done
echo ""

echo "========== ZooKeeper =========="
echo ""
for host in ${ZOO_SERVERS[@]}; do
    echo "---------- $host ----------"
    nc -zv $host 2181
    ssh $host "/scripts/cluster-cmd.sh zookeeper status"
done
echo ""

echo "========== JournalNode =========="
echo ""
for host in ${JOURNAL_NODES[@]}; do
    echo "---------- $host ----------"
    nc -zv $host 8485
done
echo ""

echo "========== NameNode =========="
echo ""
echo "---------- $ACTIVE_NAME_NODE ----------"
ssh $ACTIVE_NAME_NODE $HADOOP_HOME/bin/hdfs haadmin -getServiceState nn1
echo "---------- $STANDBY_NAME_NODE ----------"
ssh $STANDBY_NAME_NODE $HADOOP_HOME/bin/hdfs haadmin -getServiceState nn2
echo ""

echo "========== ResourceManager =========="
echo ""
echo "---------- $ACTIVE_RESOURCE_MANAGER ----------"
ssh $ACTIVE_RESOURCE_MANAGER $HADOOP_HOME/bin/yarn rmadmin -getServiceState rm1
echo "---------- $STANDBY_RESOURCE_MANAGER ----------"
ssh $ACTIVE_RESOURCE_MANAGER $HADOOP_HOME/bin/yarn rmadmin -getServiceState rm2
echo ""

echo "========== DataNode =========="
echo ""
ssh $ACTIVE_NAME_NODE $HADOOP_HOME/bin/hdfs dfsadmin -report
echo ""

echo "========== NodeManager =========="
echo ""
ssh $ACTIVE_NAME_NODE $HADOOP_HOME/bin/yarn node -list -all
echo ""
