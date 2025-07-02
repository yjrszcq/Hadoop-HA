#!/bin/bash
set -ex

# 后台启动SSHD（保留进程ID）
/usr/sbin/sshd -D &
SSHD_PID=$!

# 等待SSH端口就绪（最多等待10秒）
timeout=10
while ! nc -z localhost 22 && [ $timeout -gt 0 ]; do
    sleep 1
    timeout=$((timeout-1))
done

# 检测端口是否就绪
if [ $timeout -le 0 ]; then
    echo "SSH服务启动超时"
    exit 1
fi

# 时间同步
(crontab -l 2>/dev/null; echo "*/10 * * * * /usr/sbin/ntpdate ${NTP_SERVER}") | crontab - \
&& /usr/sbin/ntpdate ${NTP_SERVER}

# 修复hosts
#/scripts/hosts-set.sh

# 启动集群
#/scripts/cluster-start.sh

# 创建时初始化容器
/scripts/init.sh

# 保持容器运行（监控SSHD进程）
wait $SSHD_PID
