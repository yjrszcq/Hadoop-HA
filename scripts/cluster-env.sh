#!/bin/bash

# 所有节点通用环境配置
CLUSTER_ENV="/opt/cluster.env"

# 创建配置文件并写入环境变量
cat << EOF > "${CLUSTER_ENV}"
# JDK配置
JAVA_HOME=${JAVA_HOME}
PATH=$JAVA_HOME/bin:$PATH
# Hadoop配置
HADOOP_HOME=${HADOOP_HOME}
HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH
# Zookeeper配置
ZOOKEEPER_HOME=${ZOOKEEPER_HOME}
PATH=$ZOOKEEPER_HOME/bin:$PATH
# 其他配置
LD_LIBRARY_PATH=${JAVA_HOME}/jre/lib/amd64/server:$LD_LIBRARY_PATH
EOF

# 设置文件权限（可选）
chmod 644 "${CLUSTER_ENV}"
chown -R yjrszcq:bigdata "${CLUSTER_ENV}"

echo "配置文件已生成：${CLUSTER_ENV}"
