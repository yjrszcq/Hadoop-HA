#!/bin/bash
set -ex

# ---------------------------------------------------------
# 初始化容器
# ---------------------------------------------------------

/scripts/cluster-conf.sh
/scripts/cluster-env.sh
/scripts/hadoop-set.sh
/scripts/zoo-set.sh
/scripts/hosts-set.sh
/scripts/ssh-host.sh

# ---------------------------------------------------------
# 修改entrypoint.sh文件
# ---------------------------------------------------------

# 取消注释配置hosts命令
sed -i 's|^#\(/scripts/hosts-set.sh\)|\1|' /scripts/entrypoint.sh
# 取消注释启动集群命令
#sed -i 's|^#\(/scripts/cluster-start.sh\)|\1|' /scripts/entrypoint.sh
# 注释掉启动自己的命令
sed -i '\|^\(.*/'"${0##*/}"'.*\)| s/^/#/' /scripts/entrypoint.sh

# ---------------------------------------------------------
# 初始化并启动集群
# ---------------------------------------------------------

#/scripts/cluster-init.sh
