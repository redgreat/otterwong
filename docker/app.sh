#!/bin/bash
#set -e

source /etc/profile
export JAVA_HOME=/usr/java/latest
export PATH=$JAVA_HOME/bin:$PATH
touch /tmp/start.log
chown admin: /tmp/start.log
chown admin: /home/admin/manager
chown admin: /home/admin/zkData
host=`hostname -i`

if [ -z "${RUN_MODE}" ]; then
    RUN_MODE="ALL"
fi
if [ -z "${OTTER_MANAGER_MYSQL}" ]; then
    OTTER_MANAGER_MYSQL="fn.wongcw.cn:3306"
fi
if [ -z "${MYSQL_USER}" ]; then
    MYSQL_USER="otter"
fi
if [ -z "${MYSQL_PASSWORD}" ]; then
    MYSQL_PASSWORD="Lunz2017"
fi
if [ -z "${MYSQL_DATABASE}" ]; then
    MYSQL_DATABASE="otter"
fi

# default zookeeper config
ZOO_DIR=/home/admin/zookeeper-3.7.0
ZOO_CONF_DIR=$ZOO_DIR/conf
ZOO_DATA_DIR=/home/admin/zkData 
ZOO_DATA_LOG_DIR=$ZOO_DATA_DIR/datalog 
ZOO_LOG_DIR=$ZOO_DIR/logs 
ZOO_TICK_TIME=10000 
ZOO_INIT_LIMIT=10 
ZOO_SYNC_LIMIT=5
ZOO_AUTOPURGE_PURGEINTERVAL=0 
ZOO_AUTOPURGE_SNAPRETAINCOUNT=3 
ZOO_MAX_CLIENT_CNXNS=60 
ZOO_STANDALONE_ENABLED=true 
ZOO_ADMINSERVER_ENABLED=true

# 等待TERM/INT信号
waitterm() {
        local PID
        tail -f /dev/null &
        PID="$!"
        trap "kill -TERM ${PID}" TERM INT
        wait "${PID}" || true
        trap - TERM INT
        wait "${PID}" 2>/dev/null || true
}

# 检查服务启动状态
function checkStart() {
    local name=$1
    local cmd=$2
    local timeout=$3
    printf "\e[?25l" 
    i=0
    str=""
    bgcolor=43
    space48="                       "    
    echo "$name check ... [$cmd]"
    isrun=0
    while [ $timeout -gt 0 ]
    do
        ST=`eval $cmd`
        if [ "$ST" -gt 0 ]; then
            isrun=1
            break
        else
            percentstr=$(printf "%3s" $i)
            totalstr="${space48}${percentstr}${space48}"
            leadingstr="${totalstr:0:$i+1}"
            trailingstr="${totalstr:$i+1}"
            printf "\r\e[30;47m${leadingstr}\e[37;40m${trailingstr}\e[0m"
            let i=$i+1
            str="${str}="
            sleep 1
            let timeout=$timeout-1
        fi
    done
    echo ""
    if [ $isrun == 1 ]; then
        echo -e "\033[32m $name start successful \033[0m" 
    else
        echo -e "\033[31m $name start timeout \033[0m"
    fi
    printf "\e[?25h""\n"
}

# 启动zookeeper服务
function start_zookeeper() {
    echo "start zookeeper ..."
    
    rm -f $ZOO_DATA_DIR/myid
    rm -f $ZOO_CONF_DIR/zoo.cfg
    if [[ ! -f "$ZOO_CONF_DIR/zoo.cfg" ]]; then
        CONFIG="$ZOO_CONF_DIR/zoo.cfg"
        {
            echo "dataDir=$ZOO_DATA_DIR" 
            echo "dataLogDir=$ZOO_DATA_LOG_DIR"
            echo "tickTime=$ZOO_TICK_TIME"
            echo "initLimit=$ZOO_INIT_LIMIT"
            echo "syncLimit=$ZOO_SYNC_LIMIT"
            echo "clientPortAddress=${ZOO_CLUSTER}"
            echo "clientPort=2181"
            echo "quorumListenOnAllIPs=true"
            echo "autopurge.snapRetainCount=$ZOO_AUTOPURGE_SNAPRETAINCOUNT"
            echo "autopurge.purgeInterval=$ZOO_AUTOPURGE_PURGEINTERVAL"
            echo "maxClientCnxns=$ZOO_MAX_CLIENT_CNXNS"
            echo "standaloneEnabled=$ZOO_STANDALONE_ENABLED"
            echo "admin.enableServer=$ZOO_ADMINSERVER_ENABLED"
            echo "admin.serverAddress=${ZOO_CLUSTER}"
            echo "admin.serverPort=8018"
            echo "4lw.commands.whitelist=*"
        } >> "$CONFIG"
        if [[ -z $ZOO_SERVERS ]]; then
            ZOO_SERVERS="server.1=${ZOO_CLUSTER}:2888:3888"
        fi

        for server in $ZOO_SERVERS; do
            echo "$server" >> "$CONFIG"
        done

        if [[ -n $ZOO_4LW_COMMANDS_WHITELIST ]]; then
            echo "4lw.commands.whitelist=$ZOO_4LW_COMMANDS_WHITELIST" >> "$CONFIG"
        fi

        for cfg_extra_entry in $ZOO_CFG_EXTRA; do
            echo "$cfg_extra_entry" >> "$CONFIG"
        done
    fi

    if [[ ! -f "$ZOO_DATA_DIR/myid" ]]; then
        echo "${ZOO_MY_ID:-1}" > "$ZOO_DATA_DIR/myid"
    fi
    
    cmd="su admin -c 'mkdir -p $ZOO_DATA_DIR;mkdir -p $ZOO_LOG_DIR; cd $ZOO_DATA_DIR; $ZOO_DIR/bin/zkServer.sh start >> $ZOO_DATA_DIR/zookeeper.log 2>&1'"
    eval $cmd
    checkStart "zookeeper" "echo stat | nc ${ZOO_CLUSTER} 2181 | grep -c Outstanding" 120
}

# 停止zookeeper服务
function stop_zookeeper() {
    echo "stop zookeeper"
    cmd="su admin -c 'mkdir -p $ZOO_DATA_DIR; cd $ZOO_DATA_DIR; $ZOO_DIR/bin/zkServer.sh stop >> $ZOO_DATA_DIR/zookeeper.log 2>&1'"
    eval $cmd
    echo "stop zookeeper successful ..."
}

# 启动manager服务
function start_manager() {
    echo "start manager ..."
    


    if [ -n "${OTTER_MANAGER_MYSQL}" ] ; then
        cmd="sed -i -e 's/^otter.database.driver.url.*$/otter.database.driver.url = jdbc:mysql:\/\/${OTTER_MANAGER_MYSQL}\/${MYSQL_DB:-otter}?useUnicode=true\&characterEncoding=UTF-8\&useSSL=false/' /home/admin/manager/conf/otter.properties"
        eval $cmd
        cmd="sed -i -e 's/^otter.database.driver.username.*$/otter.database.driver.username = ${MYSQL_USER}/' /home/admin/manager/conf/otter.properties"
        eval $cmd
        cmd="sed -i -e 's/^otter.database.driver.password.*$/otter.database.driver.password = ${MYSQL_PASSWORD}/' /home/admin/manager/conf/otter.properties"
        eval $cmd
        cmd="sed -i -e 's/^otter.communication.manager.port.*$/otter.communication.manager.port = 8081/' /home/admin/manager/conf/otter.properties"
        eval $cmd
        cmd="sed -i -e 's/^otter.domainName.*$/otter.domainName = ${OTTER_DOMAIN_NAME}/' /home/admin/manager/conf/otter.properties"
        eval $cmd
        cmd="sed -i -e 's/^otter.port.*$/otter.port = ${OTTER_PORT:-8080}/' /home/admin/manager/conf/otter.properties"
        eval $cmd
        cmd="sed -i -e 's/^otter.zookeeper.cluster.default.*$/otter.zookeeper.cluster.default = ${ZOO_CLUSTER}:2181/' /home/admin/manager/conf/otter.properties"
        eval $cmd
    fi
    su - admin -c "cd /home/admin/manager/bin ; sh startup.sh 1>>/tmp/start_manager.log 2>&1"

    checkStart "manager" "nc ${ZOO_CLUSTER} ${OTTER_PORT:-8080} -w 1 -z | wc -l" 120
}

# 停止manager服务
function stop_manager() {
    # stop manager
    echo "stop manager"
    su admin -c 'cd /home/admin/manager/bin; sh stop.sh 1>>/tmp/start_manager.log 2>&1'
    echo "stop manager successful ..."
}

# 启动node服务
function start_node() {
    echo "start node ..."
    
    cmd="sed -i -e 's/^otter.manager.address.*$/otter.manager.address = ${MANAGER_ADD}:8081/' /home/admin/node/conf/otter.properties"
    eval $cmd
    cmd="sed -i -e 's/^otter.zookeeper.cluster.default.*$/otter.zookeeper.cluster.default = ${ZOO_CLUSTER}:2181/' /home/admin/node/conf/otter.properties"
    eval $cmd
    cmd="su - admin -c 'cd /home/admin/node/bin/ && sh startup.sh >> /tmp/start_node.log 2>&1'"
    eval $cmd

    checkStart "node" "nc ${ZOO_CLUSTER} 2088 -w 1 -z | wc -l" 120
    node_is_run=$(nc ${ZOO_CLUSTER} 2088 -w 1 -z | wc -l)
    echo "node_is_run:"$node_is_run
    if [ $node_is_run == 0 ]; then
        echo -e "\033[32m ==> restart Node ... \033[0m"
        stop_node
        start_node
    fi
}

# 停止node服务
function stop_node() {
    echo "stop node"
    su - admin -c 'cd /home/admin/node/bin/ && sh stop.sh'
    echo "stop node successful ..."
}

echo "==> START ..."
start_zookeeper

if [ "${RUN_MODE}" == "ALL" ]; then
    echo -e "\033[32m ==> START RUN_MODE: "${RUN_MODE}"... \033[0m"
    start_manager
    echo "you can visit manager link : http://${OTTER_DOMAIN_NAME}:${OTTER_PORT:-8080}/ , just have fun !"
    start_node    
fi

if [ "${RUN_MODE}" == "NODE" ]; then
    echo -e "\033[32m ==> START RUN_MODE: "${RUN_MODE}"... \033[0m"
    start_node    
fi

if [ "${RUN_MODE}" == "MANAGER" ]; then
    echo -e "\033[32m ==> START RUN_MODE: "${RUN_MODE}"... \033[0m"
    start_manager  
    echo "you can visit manager link : http://${OTTER_DOMAIN_NAME}:${OTTER_PORT:-8080}/ , just have fun !"  
fi

echo -e "\033[32m ==> START SUCCESSFUL ... \033[0m"

netstat -tunlp
tail -f /dev/null &
waitterm

echo "==> STOP"

stop_manager
stop_node
stop_zookeeper

echo "==> STOP SUCCESSFUL ..."