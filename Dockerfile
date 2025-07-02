FROM ubuntu:25.10

RUN apt-get clean && apt-get update && apt-get install -y \
    wget \
    openssh-server \
    net-tools \
    rsync \
    vim \
    curl \
    sudo \
    gosu \
    expect \
    ntpdate \
    cron \
    psmisc \
    netcat-openbsd && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ARG JAVA_VERSION=1.8.0_191
ARG HADOOP_VERSION=2.7.7
ARG ZOOKEEPER_VERSION=3.5.7

ARG JAVA_PACKAGE=jdk-8u191-linux-x64.tar.gz
ARG HADOOP_PACKAGE=hadoop-${HADOOP_VERSION}.tar.gz
ARG ZOOKEEPER_PACKAGE=apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz

RUN groupadd -g 1124 bigdata && useradd -m -u 1124 -g bigdata yjrszcq
RUN echo "yjrszcq:1234" | chpasswd
RUN echo "yjrszcq ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

ENV SCRIPTS_PATH /scripts
ENV JAVA_HOME /opt/moudle/jdk${JAVA_VERSION}
ENV JRE_HOME ${JAVA_HOME}/jre
ENV CLASSPATH ${JAVA_HOME}/lib:${JRE_HOME}/lib
ENV HADOOP_HOME /opt/software/hadoop-${HADOOP_VERSION}
ENV HADOOP_CONF_DIR ${HADOOP_HOME}/etc/hadoop
ENV ZOOKEEPER_HOME /opt/software/apache-zookeeper-${ZOOKEEPER_VERSION}-bin
ENV PATH ${JAVA_HOME}/bin:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${ZOOKEEPER_HOME}/bin:${SCRIPTS_PATH}:$PATH

RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

RUN rm -f /etc/ssh/ssh_host_*_key* && \
    ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N "" -q && \
    ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N "" -q && \
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" -q

RUN mkdir -p /opt/software && mkdir -p /opt/moudle

ADD moudle/${JAVA_PACKAGE} /opt/moudle
ADD software/${HADOOP_PACKAGE} /opt/software
ADD software/${ZOOKEEPER_PACKAGE} /opt/software

RUN mkdir -p ${HADOOP_HOME}/data && \
    mkdir -p ${HADOOP_HOME}/data/hdfs && \
    mkdir -p ${HADOOP_HOME}/data/hdfs/tmp && \
    mkdir -p ${HADOOP_HOME}/data/hdfs/namenode && \
    mkdir -p ${HADOOP_HOME}/data/hdfs/namenode/data && \
    mkdir -p ${HADOOP_HOME}/data/hdfs/namenode/edits && \
    mkdir -p ${HADOOP_HOME}/data/hdfs/datanode && \
    mkdir -p ${HADOOP_HOME}/data/hdfs/datanode/data1 && \
    mkdir -p ${HADOOP_HOME}/data/hdfs/datanode/data2 && \
    mkdir -p ${HADOOP_HOME}/data/hdfs/datanode/data3 && \
    mkdir -p ${HADOOP_HOME}/data/hdfs/journalnode && \
    mkdir -p ${HADOOP_HOME}/data/yarn && \
    mkdir -p ${HADOOP_HOME}/data/yarn/apps && \
    mkdir -p ${HADOOP_HOME}/data/yarn/log-dirs && \
    mkdir -p ${HADOOP_HOME}/data/yarn/local-dirs && \
    mkdir -p ${ZOOKEEPER_HOME}/zoo_data && \
    mkdir -p ${ZOOKEEPER_HOME}/zoo_logs

RUN sed -i "s#export JAVA_HOME=\${JAVA_HOME}#export JAVA_HOME=${JAVA_HOME}#" ${HADOOP_CONF_DIR}/hadoop-env.sh && \
    sed -i "s#export HADOOP_CONF_DIR=\${HADOOP_CONF_DIR:-\"/etc/hadoop\"}#export HADOOP_CONF_DIR=${HADOOP_CONF_DIR}#" ${HADOOP_CONF_DIR}/hadoop-env.sh && \
    echo "export HADOOP_LOG_DIR=${HADOOP_HOME}/logs" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh

COPY config/core-site.xml ${HADOOP_CONF_DIR}
COPY config/hdfs-site.xml ${HADOOP_CONF_DIR}
COPY config/mapred-site.xml ${HADOOP_CONF_DIR}
COPY config/yarn-site.xml ${HADOOP_CONF_DIR}
COPY config/zoo.cfg ${ZOOKEEPER_HOME}/conf

RUN mkdir -p /scripts
COPY scripts /scripts
RUN chmod +x /scripts/hosts-set.sh && \
    chmod +x /scripts/ssh-set.sh && \
    chmod +x /scripts/ssh-host.sh && \
    chmod +x /scripts/init.sh && \
    chmod +x /scripts/zoo-set.sh && \
    chmod +x /scripts/hadoop-set.sh && \
    chmod +x scripts/cluster-cmd.sh && \
    chmod +x /scripts/cluster-env.sh && \
    chmod +x /scripts/cluster-conf.sh && \
    chmod +x /scripts/cluster-init.sh && \
    chmod +x /scripts/cluster-start.sh && \
    chmod +x /scripts/cluster-status.sh && \
    chmod +x /scripts/entrypoint.sh

RUN chown -R yjrszcq:bigdata /opt/moudle && \
    chown -R yjrszcq:bigdata /opt/software

RUN /scripts/ssh-set.sh

ENV DEFAULT_HOME /opt
WORKDIR $DEFAULT_HOME
USER yjrszcq
EXPOSE 22

ENTRYPOINT ["sudo","-E","/scripts/entrypoint.sh"]
