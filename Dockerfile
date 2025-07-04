# 第一阶段：基础系统和Java环境
FROM centos:centos7.9.2009 AS base

ENV DOWNLOAD_LINK="https://repo.huaweicloud.com/java/jdk/8u181-b13/jdk-8u181-linux-x64.tar.gz"

COPY docker/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo
COPY docker/gosu /usr/local/bin/gosu

# 安装基础系统组件
RUN \
    /bin/cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo 'root:Otter!123' | chpasswd && \
    groupadd -r admin && useradd -g admin admin && \
    yum install -y man && \
    yum install -y dstat && \
    yum install -y unzip && \
    yum install -y nc && \
    yum install -y openssh-server && \
    yum install -y tar && \
    yum install -y which && \
    yum install -y wget && \
    yum install -y perl && \
    yum install -y file && \
    ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key && \
    ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key && \
    sed -ri 's/session    required     pam_loginuid.so/#session    required     pam_loginuid.so/g' /etc/pam.d/sshd && \
    sed -i -e 's/^#Port 22$/Port 2222/' /etc/ssh/sshd_config && \
    mkdir -p /root/.ssh && chown root.root /root && chmod 700 /root/.ssh && \
    yum install -y cronie && \
    sed -i '/session required pam_loginuid.so/d' /etc/pam.d/crond && \
    chmod +x /usr/local/bin/gosu && \
    true

# 安装Java环境
RUN \
    touch /var/lib/rpm/* && \
    wget --no-cookies --no-check-certificate "$DOWNLOAD_LINK" -O /tmp/jdk-8-linux-x64.tar.gz && \
    mkdir -p /usr/java && \
    tar -xzf /tmp/jdk-8-linux-x64.tar.gz -C /usr/java && \
    ln -s /usr/java/jdk1.8.0_181 /usr/java/latest && \
    /bin/rm -f /tmp/jdk-8-linux-x64.tar.gz && \
    echo "export JAVA_HOME=/usr/java/latest" >> /etc/profile && \
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile && \
    yum clean all && \
    true

# 第二阶段：安装ZooKeeper
FROM base AS osbase

COPY ./docker/aria2c /bin/aria2c
COPY ./docker/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo
COPY ./docker/apache-zookeeper-3.7.0-bin.tar.gz /tmp/
COPY ./docker/manager.deployer-4.2.19-SNAPSHOT.tar.gz /tmp/docker/
COPY ./docker/node.deployer-4.2.19-SNAPSHOT.tar.gz /tmp/docker/

RUN \
    mkdir -p /tmp/docker && \
    mkdir -p /home/admin && \
    rm -rf /home/admin/zookeeper-3.4.13 && \
    tar -xzvf /tmp/apache-zookeeper-*-bin.tar.gz -C /home/admin/ && \
    mv /home/admin/apache-zookeeper-3.7.0-bin /home/admin/zookeeper-3.7.0 && \
    rm -f /tmp/apache-zookeeper-*-bin.tar.gz && \
    chown admin: -R /home/admin && \
    yum clean all && \
    true

# 第三阶段：安装Otter应用
FROM osbase AS otter

EXPOSE 8080 8081 2181 8018 2088 2089 2090

# 复制Otter配置文件
COPY ./docker/app.sh /home/admin/app.sh

# 安装Otter应用
RUN \
    mkdir -p /alidata/bin && \
    mkdir -p /home/admin/bin && \
    mkdir -p /home/admin/manager && \
    tar -xzvf /tmp/docker/manager.deployer-*.tar.gz -C /home/admin/manager && \
    mkdir -p /home/admin/node && \
    tar -xzvf /tmp/docker/node.deployer-*.tar.gz -C /home/admin/node && \
    /bin/rm -f /tmp/docker/node.deployer-*.tar.gz && \
    /bin/rm -f /tmp/docker/manager.deployer-*.tar.gz && \
    mkdir -p /home/admin/manager/logs  && \
    mkdir -p /home/admin/node/logs  && \
    mkdir -p /home/admin/zkData  && \
    mkdir -p /home/admin/zookeeper-3.7.0/logs && \
    chmod +x /home/admin/*.sh  && \
    chown -R admin:admin /home/admin && \
    chmod -R 755 /home/admin/zookeeper-3.7.0/logs && \
    chmod -R 755 /home/admin/zkData && \
    # 修复ZooKeeper JVM参数兼容Java 8
    sed -i 's/-XX:PermSize=[0-9]*[mMgG]//g' /home/admin/zookeeper-3.7.0/bin/zkServer.sh && \
    sed -i 's/-XX:MaxPermSize=[0-9]*[mMgG]//g' /home/admin/zookeeper-3.7.0/bin/zkServer.sh && \
    sed -i 's/-XX:+UseCMSCompactAtFullCollection//g' /home/admin/zookeeper-3.7.0/bin/zkServer.sh && \
    sed -i 's/-XX:+CMSParallelRemarkEnabled//g' /home/admin/zookeeper-3.7.0/bin/zkServer.sh && \
    sed -i 's/-XX:+UseConcMarkSweepGC/-XX:+UseG1GC/g' /home/admin/zookeeper-3.7.0/bin/zkServer.sh && \
    # 确保ZooKeeper日志目录权限正确
    chmod -R 777 /home/admin/zookeeper-3.7.0/logs && \
    yum clean all && \
    echo "otter.zookeeper.cluster.default = 127.0.0.1:2181" >> "/home/admin/node/conf/otter.properties" && \
    # 修复Manager JVM参数
    sed -i 's/-XX:PermSize=96m//g' /home/admin/manager/bin/startup.sh && \
    sed -i 's/-XX:MaxPermSize=256m//g' /home/admin/manager/bin/startup.sh && \
    sed -i 's/-XX:+UseCMSCompactAtFullCollection//g' /home/admin/manager/bin/startup.sh && \
    sed -i 's/-XX:-UseAdaptiveSizePolicy//g' /home/admin/manager/bin/startup.sh && \
    sed -i 's/-XX:+CMSParallelRemarkEnabled//g' /home/admin/manager/bin/startup.sh && \
    sed -i 's/-XX:+UseFastAccessorMethods//g' /home/admin/manager/bin/startup.sh && \
    sed -i 's/-XX:+UseCMSInitiatingOccupancyOnly//g' /home/admin/manager/bin/startup.sh && \
    sed -i 's/-XX:+UseConcMarkSweepGC/-XX:+UseG1GC -XX:MaxGCPauseMillis=200/g' /home/admin/manager/bin/startup.sh && \
    sed -i 's/-Xmx3072m/-Xmx2048m/g' /home/admin/manager/bin/startup.sh && \
    sed -i 's/-Xmn1024m/-XX:NewRatio=1/g' /home/admin/manager/bin/startup.sh && \
    sed -i 's/-XX:SurvivorRatio=2/-XX:SurvivorRatio=8/g' /home/admin/manager/bin/startup.sh && \
    # 修复Node JVM参数
    sed -i 's/-XX:PermSize=96m//g' /home/admin/node/bin/startup.sh && \
    sed -i 's/-XX:MaxPermSize=256m//g' /home/admin/node/bin/startup.sh && \
    sed -i 's/-XX:+UseCMSCompactAtFullCollection//g' /home/admin/node/bin/startup.sh && \
    sed -i 's/-XX:-UseAdaptiveSizePolicy//g' /home/admin/node/bin/startup.sh && \
    sed -i 's/-XX:+CMSParallelRemarkEnabled//g' /home/admin/node/bin/startup.sh && \
    sed -i 's/-XX:+UseFastAccessorMethods//g' /home/admin/node/bin/startup.sh && \
    sed -i 's/-XX:+UseCMSInitiatingOccupancyOnly//g' /home/admin/node/bin/startup.sh && \
    sed -i 's/-XX:+UseConcMarkSweepGC/-XX:+UseG1GC -XX:MaxGCPauseMillis=200/g' /home/admin/node/bin/startup.sh && \
    sed -i 's/-Xmx3072m/-Xmx2048m/g' /home/admin/node/bin/startup.sh && \
    sed -i 's/-Xmn1024m/-XX:NewRatio=1/g' /home/admin/node/bin/startup.sh && \
    sed -i 's/-XX:SurvivorRatio=2/-XX:SurvivorRatio=8/g' /home/admin/node/bin/startup.sh && \
    true

ENV DOCKER_DEPLOY_TYPE=VM

WORKDIR /home/admin

LABEL maintainer="wangcw <rubygreat@msn.com>" \
      version="1.0" \
      description="Otter数据同步中间件"

ENTRYPOINT [ "/home/admin/app.sh" ]