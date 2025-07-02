#!/bin/bash
set -eo pipefail

# 切换到应用用户环境（双重确认）
if [ "$(whoami)" != "yjrszcq" ]; then
    exec sudo -u yjrszcq "$0" "$@"
    exit $?
fi

# 日志记录函数
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')][$(whoami)] $*"
}

# 指纹扫描函数
scan_hosts() {
    local known_hosts="$HOME/.ssh/known_hosts"
    
    log "开始扫描/etc/hosts中的主机记录"
    grep -vE '^#|^127.0.0.1|::1|^$' /etc/hosts | awk '{print $2,$1}' | while read host ip; do
        [[ -z "$host" || "$host" == "localhost" ]] && continue
        
        log "正在处理: $host ($ip)"
        {
            # 并发扫描（使用子shell后台处理）
            (ssh-keyscan -H -T 5 "$host" 2>/dev/null &)
            #(ssh-keyscan -H -T 5 "$ip" 2>/dev/null &)
            wait
        } | sort -u | tee -a "$known_hosts.tmp"
    done

    # 去重合并记录
    if [[ -f "$known_hosts.tmp" ]]; then
        touch "$known_hosts"
        cat "$known_hosts.tmp" "$known_hosts" | awk '!seen[$0]++' > "$known_hosts.new"
        mv "$known_hosts.new" "$known_hosts"
        rm -f "$known_hosts.tmp"
    fi

    # 设置严格权限
    chmod 600 ~/.ssh/*
}

# 主执行流程
main() {
    log "----- 启动容器初始化 -----"
    
    # 初始化SSH指纹库
    scan_hosts
    
    log "完成known_hosts配置，内容如下："
    cat ~/.ssh/known_hosts 2>/dev/null || true
    
    log "启动SSH守护进程及后续命令: $*"
    exec "$@"
}

# 异常处理
trap 'log "脚本异常退出 $?"' ERR
main "$@"
