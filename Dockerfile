FROM canal/otter-osbase:v1 AS base

COPY ./docker/aria2c /bin/aria2c
COPY ./docker/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo
RUN yum -y update  && \
    mkdir -p /home/admin && \
    chown admin: -R /home/admin && \ 
    yum clean all && \
    true

FROM base AS otter

EXPOSE 8080 8081 2181 8018 2088 2089 2090

COPY ./docker/image/ /tmp/docker/
COPY ./docker/app.sh /home/admin/app.sh

RUN \
    cp -R /tmp/docker/alidata /alidata && \
    chmod +x /alidata/bin/* && \
    mkdir -p /home/admin && \
    cp -R /tmp/docker/admin/* /home/admin/  && \
    /bin/cp -f alidata/bin/lark-wait /usr/bin/lark-wait && \
    mkdir -p /home/admin/manager && \
    tar -xzvf /tmp/docker/manager.deployer-*.tar.gz -C /home/admin/manager && \    
    mkdir -p /home/admin/node && \
    tar -xzvf /tmp/docker/node.deployer-*.tar.gz -C /home/admin/node && \
    /bin/rm -f /tmp/docker/node.deployer-*.tar.gz && \
    /bin/rm -f /tmp/docker/manager.deployer-*.tar.gz && \
    mkdir -p /home/admin/manager/logs  && \
    mkdir -p /home/admin/node/logs  && \
    mkdir -p /home/admin/zkData  && \
    chmod +x /home/admin/*.sh  && \
    chmod +x /home/admin/bin/*.sh  && \
    chown admin: -R /home/admin && \ 
    yum clean all && \    
    echo "otter.zookeeper.cluster.default = 127.0.0.1:2181" >> "/home/admin/node/conf/otter.properties" && \
    true

WORKDIR /home/admin

LABEL maintainer="wangcw <rubygreat@msn.com>" \
      version="1.0" \
      description="Otter数据同步中间件"
      
ENTRYPOINT [ "/alidata/bin/main.sh" ]
CMD [ "/home/admin/app.sh" ]