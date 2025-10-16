# Hadoop-HA

Docker环境下的高可用Hadoop集群搭建

## 快速启动

此项目的镜像已经上传至 [Docker Hub](https://hub.docker.com/r/szcq/hadoop)，您可以直接使用 `hadoop-start.sh -i` 创建并启动容器。

注意
- `hadoop-start.sh` 并不包含 NTP 服务器的搭建，若您需要本地的 NTP 服务，请自行搭建，相关 `docker-compose.yml` 已包含在本仓库中
- `hadoop-start.sh` 并不会自动生成节点的配置文件，请参考本仓库中的配置文件 `hadoop-env.conf` 自行配置节点
  - 详细的使用方法请从 **容器相关** 部分开始往后阅读

## 镜像搭建

您可以使用 `rebuild.sh` 快速搭建镜像

- 重建镜像也可以使用这个脚本
- 注意：hadoop，zookeeper，jdk需要提前下载到指定目录
  - `./software` ：hadoop，zookeeper
  - `./moudle` ：jdk
- hadoop 版本默认 2.7.7，如果需要更高的版本
  - 在 `Dockerfile` 内将 `HADOOP_VERSION` 修改为您需要的版本号
  - 可能需要修改 hadoop 的配置文件（与 2.7.7 版本不兼容的配置）
  - 可能需要修改 `./scripts/cluster-cmd.sh` （与 2.7.7 版本不兼容的命令）
  - 3.X 版本需要在 `./scripts/hadoop-set.sh` 中，将 `SLAVE_FILE` 的值修改为 `$HADOOP_CONF_DIR/workers`

## 容器相关

### 启动容器

您可以使用 `hadoop-start.sh -i` 创建并启动容器，或者使用 `hadoop-start.sh` 启动容器

- 注意：创建容器前，节点配置文件 `hadoop-env.conf` 必须要在与脚本相同的目录下

### 停止容器

您可以使用 `hadoop-stop.sh -r` 停止并删除容器，或者使用 `hadoop-stop.sh` 停止容器

## 配置相关

关于 `hadoop-env.conf` ，您可以在满足以下条件内，自由地分配节点的职责和数量

- 节点数目至少 3 个
  - 其实3个节点已经有些不稳定了，初步判断为高压下ZKFC心跳延迟导致的误触发主备切换和客户端访问漂移，容易出现 `Operation category READ is not supported in state standby` 错误
  - 在默认的配置下（即仓库中的配置），这种问题没有出现过

- 节点命名仅支持 hadoop + 数字，且必须连续
  - 这关乎到容器内 `/etc/hosts` 文件的字段配置
  - 如：hadoop3，hadoop11 等，但不能出现hadoop节点编号的空缺，节点有多少个，hadoop节点编号的最大值就是多少

- NTP服务器必须配置，但是可以选择自建或者使用公共的NTP服务器
  - 自建NTP的 `docker-compose.yml` 已经包含在仓库中（如果您修改了集群网络的网段，注意把NTP的 `docker-compose.yml` 的网段也一同修改）
  - 注意：公共的NTP节点有一定概率连不上，导致容器启动失败，这时您只需要 `docker start 启动失败的容器` 即可启动，如果没有启动成功，可以多重复几遍

- 多节点的配置，请用字符 `,` 分隔节点

- ZooKeeper 和 JournalNode 的节点数量按需配置，但最好是奇数个，且都在 3 个或以上

- JobHistoryServer，NameNode 的主备节点，ResourceManager 的主备节点各 1 个

- DataNode 和 NodeManager 暂时不支持分离配置，请确保这两种节点的配置相同，数量上至少 3 个
  - 启动脚本 `hadoop-start.sh` 由于 IP 配置方式，仅支持最多 250 个左右，需要更多请自行修改启动脚本

## 使用相关

以下是各主要节点的 Web 访问地址

- NameNode
```
http://localhost:50070/
```

- ResourceManager
```
http://localhost:8088/
```

- JobHistoryServer
```
http://localhost:19888/
```


