#!/bin/bash

# 确保环境变量存在
if [ -z "$ZOO_SERVER" ]; then
    echo "ERROR: ZOO_SERVER environment variable is not set" >&2
    exit 1
fi

# 转成数组
IFS=',' read -ra ZOO_NODES <<< "$ZOO_SERVER"

# ---------------------------------------------------------
# 任务1：生成myid文件
# ---------------------------------------------------------
CURRENT_HOST=$(hostname -s)  # 获取短主机名（非FQDN）

# 在节点列表中查找当前主机的位置
MY_ID=-1
for i in "${!ZOO_NODES[@]}"; do
    if [[ "${ZOO_NODES[$i]}" == "$CURRENT_HOST" ]]; then
        MY_ID=$((i + 1))  # ZooKeeper ID从1开始
        break
    fi
done

# 写入myid
if [ "$MY_ID" -ne -1 ]; then
    ZOO_DATA_DIR="${ZOOKEEPER_HOME}/zoo_data"
    mkdir -p "$ZOO_DATA_DIR"
    echo "$MY_ID" > "${ZOO_DATA_DIR}/myid"
    echo "Created myid: $MY_ID in ${ZOO_DATA_DIR}/myid"
else
    echo "WARNING: Current host $CURRENT_HOST not found in ZOO_SERVER, skip myid creation" >&2
fi

# ---------------------------------------------------------
# 任务2：生成zoo.cfg配置
# ---------------------------------------------------------
ZOO_CFG="${ZOOKEEPER_HOME}/conf/zoo.cfg"

# 清理旧配置（删除所有server.*行）
sed -i '/^server\.[0-9]\+=/d' "$ZOO_CFG"

# 追加新配置
for i in "${!ZOO_NODES[@]}"; do
    server_id=$((i + 1))
    echo "server.${server_id}=${ZOO_NODES[$i]}:2888:3888" >> "$ZOO_CFG"
done
echo "Updated zoo.cfg with ${#ZOO_NODES[@]} servers"

# ---------------------------------------------------------
# 任务3：更新zoo.cfg配置
# ---------------------------------------------------------
sed -i "s#\${ZOOKEEPER_HMOE}#${ZOOKEEPER_HOME}#g" ${ZOOKEEPER_HOME}/conf/zoo.cfg

mv ${ZOOKEEPER_HOME}/conf/zoo_sample.cfg{,.bak}
