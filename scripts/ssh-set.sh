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

# 用户权限检查
if [ "$(whoami)" != "yjrszcq" ]; then
    exec sudo -u yjrszcq "$0" "$@"
    exit
fi

# 生成SSH密钥
rm -rf ~/.ssh
ssh-keygen -t rsa -N '' -C "yjr217@qq.com" -f ~/.ssh/id_rsa -q

# 将公钥复制到授权密钥
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

