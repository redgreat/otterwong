FROM canal/otter-osbase


COPY ./aria2c /bin/aria2c
COPY ./CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo
COPY ./apache-zookeeper-3.7.0-bin.tar.gz /tmp/
COPY ./manager.deployer-4.2.19-SNAPSHOT.tar.gz /tmp/docker/
COPY ./node.deployer-4.2.19-SNAPSHOT.tar.gz /tmp/docker/
RUN \
    mkdir -p /tmp/docker && \
    yum -y remove mysql-server && \
    yum -y localinstall https://dev.mysql.com/get/mysql57-community-release-el6-9.noarch.rpm && \
    yum -y install mysql-server --nogpgcheck && \
    yum -y update  && \
    mkdir -p /home/admin && \    
    rm -rf /home/admin/zookeeper-3.4.13 && \
    tar -xzvf /tmp/apache-zookeeper-*-bin.tar.gz -C /home/admin/ && \
    mv /home/admin/apache-zookeeper-3.7.0-bin /home/admin/zookeeper-3.7.0 && \
    rm -f /tmp/apache-zookeeper-*-bin.tar.gz && \
    chown admin: -R /home/admin && \ 
    rm -rf /var/lib/mysql/* && \ 
    yum clean all && \
    true

CMD ["/bin/bash"]