#!/bin/bash
set -ex

# ---------------------------------------------------------
# core-site.xml
# ---------------------------------------------------------

sed -i "s#\${HADOOP_HOME}#${HADOOP_HOME}#g" ${HADOOP_CONF_DIR}/core-site.xml
# 更新core-site.xml中的ZooKeeper地址
ZOO_QUORUM=$(echo "$ZOO_SERVER" | sed 's/,/:2181,/g'):2181
sed -i "s#\${ZOO_SERVER}#${ZOO_QUORUM}#g" ${HADOOP_CONF_DIR}/core-site.xml

# ---------------------------------------------------------
# hdfs-site.xml
# ---------------------------------------------------------

sed -i "s#\${HADOOP_HOME}#${HADOOP_HOME}#g" ${HADOOP_CONF_DIR}/hdfs-site.xml
sed -i "s#\${ACTIVE_NAME_NODE}#${ACTIVE_NAME_NODE}#g" ${HADOOP_CONF_DIR}/hdfs-site.xml
sed -i "s#\${STANDBY_NAME_NODE}#${STANDBY_NAME_NODE}#g" ${HADOOP_CONF_DIR}/hdfs-site.xml
# 更新hdfs-site.xml中的JournalNode地址
QJOURNAL=$(echo "$JOURNAL_NODE" | sed 's/,/:8485;/g'):8485
sed -i "s#\${JOURNAL_NODE}#${QJOURNAL}#" ${HADOOP_CONF_DIR}/hdfs-site.xml

# ---------------------------------------------------------
# mapred-site.xml
# ---------------------------------------------------------

sed -i "s#\${HADOOP_HOME}#${HADOOP_HOME}#g" ${HADOOP_CONF_DIR}/mapred-site.xml
sed -i "s#\${JOB_HISTORY_SERVER}#${JOB_HISTORY_SERVER}#g" ${HADOOP_CONF_DIR}/mapred-site.xml

# ---------------------------------------------------------
# yarn-site.xml
# ---------------------------------------------------------

sed -i "s#\${HADOOP_HOME}#${HADOOP_HOME}#g" ${HADOOP_CONF_DIR}/yarn-site.xml
sed -i "s#\${JAVA_HOME}#${JAVA_HOME}#g" ${HADOOP_CONF_DIR}/yarn-site.xml
sed -i "s#\${ACTIVE_RESOURCE_MANAGER}#${ACTIVE_RESOURCE_MANAGER}#g" ${HADOOP_CONF_DIR}/yarn-site.xml
sed -i "s#\${STANDBY_RESOURCE_MANAGER}#${STANDBY_RESOURCE_MANAGER}#g" ${HADOOP_CONF_DIR}/yarn-site.xml
# 更新yarn-site.xml中的ZooKeeper地址
ZOO_QUORUM=$(echo "$ZOO_SERVER" | sed 's/,/:2181,/g'):2181
sed -i "s#\${ZOO_SERVER}#${ZOO_QUORUM}#" ${HADOOP_CONF_DIR}/yarn-site.xml

# ---------------------------------------------------------
# slaves
# ---------------------------------------------------------

# Slave
SLAVE_FILE="$HADOOP_CONF_DIR/slaves"
# 将逗号分隔的 SLAVE 转换为换行分隔，并清理空格/空行
gosu yjrszcq echo "$DATA_NODE" | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' > "$SLAVE_FILE"

# DataNode
DATA_NODE_FILE="$HADOOP_CONF_DIR/datanodes"
# 将逗号分隔的 SLAVE 转换为换行分隔，并清理空格/空行
gosu yjrszcq echo "$DATA_NODE" | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' > "$DATA_NODE_FILE"
# NodeManager
NODE_MANAGER_FILE="$HADOOP_CONF_DIR/nodemanagers"
# 将逗号分隔的 SLAVE 转换为换行分隔，并清理空格/空行
gosu yjrszcq echo "$NODE_MANAGER" | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' > "$NODE_MANAGER_FILE"

#mv $HADOOP_CONF_DIR/slaves{,.bak}

