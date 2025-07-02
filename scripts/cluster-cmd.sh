#!/bin/bash
# Hadoop全版本服务管理脚本
# 兼容Hadoop 2.x/3.x版本

set -eo pipefail

set -a
source /opt/cluster.env
set +a

SCRIPT_NAME=$(basename "$0")

show_usage() {
    echo "Hadoop全版本集群管理工具"
    echo "使用方法: $SCRIPT_NAME <服务类型> <操作> [组件]"
    echo "服务类型支持:"
    echo "  hdfs       - HDFS分布式文件系统"
    echo "  yarn       - YARN资源管理器"
    echo "  zookeeper  - Zookeeper协调服务"
    echo "  mapred     - MapReduce历史服务"
    echo "操作命令支持:"
    echo "  init    - 初始化服务元数据"
    echo "  start   - 启动守护进程"
    echo "  stop    - 停止守护进程"
    echo "  status  - 查看运行状态"
    exit 1
}

hadoop_daemon() {
    local service=$1
    local action=$2
    local component=$3

    # 自动识别新旧版本命令
    if [[ -f "$HADOOP_HOME/sbin/${service}-daemon.sh" ]]; then
        "$HADOOP_HOME/sbin/${service}-daemon.sh" "$action" "$component"
    elif [[ -f "$HADOOP_HOME/sbin/hadoop-daemon.sh" ]]; then
        "$HADOOP_HOME/sbin/hadoop-daemon.sh" "$action" "$component"
    else
        "$HADOOP_HOME/bin/hdfs" --daemon "$action" "$component"
    fi
}

yarn_daemon() {
    local action=$1
    local component=$2

    if [[ -f "$HADOOP_HOME/sbin/yarn-daemon.sh" ]]; then
        "$HADOOP_HOME/sbin/yarn-daemon.sh" "$action" "$component"
    else
        "$HADOOP_HOME/bin/yarn" --daemon "$action" "$component"
    fi
}

execute_hdfs() {
    case "$2" in
    init)
        case "$3" in
        namenode)
            "$HADOOP_HOME/bin/hdfs" namenode -format -force -nonInteractive
            ;;
        zkfc)
            "$HADOOP_HOME/bin/hdfs" zkfc -formatZK -force
            ;;
        standby)
            "$HADOOP_HOME/bin/hdfs" namenode -bootstrapStandby -force
            ;;
        *) echo "HDFS初始化支持: namenode/zkfc/standby"; exit 2 ;;
        esac
        ;;
    start|stop|status)
        [[ -z "$3" ]] && { echo "需要指定组件: journalnode/namenode/zkfc/datanode"; exit 3; }
        hadoop_daemon hdfs "$2" "$3"
        ;;
    *) show_usage ;;
    esac
}

execute_yarn() {
    case "$2" in
    start|stop|status)
        [[ -z "$3" ]] && { echo "需要指定组件: resourcemanager/nodemanager"; exit 4; }
        yarn_daemon "$2" "$3"
        ;;
    *) show_usage ;;
    esac
}

execute_zookeeper() {
    case "$2" in
    start|stop|status)
        "zkServer.sh" "$2"
        ;;
    *) show_usage ;;
    esac
}

execute_mapred() {
    case "$2" in
    start|stop|status)
        ${HADOOP_HOME}/sbin/mr-jobhistory-daemon.sh "$2" historyserver
        #"$HADOOP_HOME/bin/mapred" --daemon "$2" historyserver
        ;;
    *) show_usage ;;
    esac
}

main() {
    [[ $# -lt 2 ]] && show_usage
    case "$1" in
    hdfs|yarn|zookeeper|mapred) ;;
    *) echo "无效服务类型: $1"; show_usage ;;
    esac

    case "$1" in
    hdfs)     execute_hdfs "$@" ;;
    yarn)     execute_yarn "$@" ;;
    zookeeper) execute_zookeeper "$@" ;;
    mapred)   execute_mapred "$@" ;;
    *)        show_usage ;;
    esac
}

main "$@"
