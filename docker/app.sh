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

if [ -z "${MANAGER_ADD}" ]; then
    RUN_MODE="10.21.0.10"
fi

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

function get_host_ip()
{
    IP=`host $1 | grep -Eo "[0-9]+.[0-9]+.[0-9]+.[0-9]+"`
    echo "$IP"
}
# waitterm
#   wait TERM/INT signal.
#   see: http://veithen.github.io/2014/11/16/sigterm-propagation.html
waitterm() {
        local PID
        # any process to block
        tail -f /dev/null &
        PID="$!"
        trap "kill -TERM ${PID}" TERM INT
        wait "${PID}" || true
        trap - TERM INT
        wait "${PID}" 2>/dev/null || true
}

# waittermpid "${PIDFILE}".
#   monitor process by pidfile && wait TERM/INT signal.
#   if the process disappeared, return 1, means exit with ERROR.
#   if TERM or INT signal received, return 0, means OK to exit.
waittermpid() {
        local PIDFILE PID do_run error
        PIDFILE="${1?}"
        do_run=true
        error=0
        trap "do_run=false" TERM INT
        while "${do_run}" ; do
                PID="$(cat "${PIDFILE}")"
                if ! ps -p "${PID}" >/dev/null 2>&1 ; then
                        do_run=false
                        error=1
                else
                        sleep 1
                fi
        done
        trap - TERM INT
        return "${error}"
}

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
            echo "clientPortAddress=0.0.0.0"
            echo "clientPort=2181"
            echo "quorumListenOnAllIPs=true"
            echo "autopurge.snapRetainCount=$ZOO_AUTOPURGE_SNAPRETAINCOUNT"
            echo "autopurge.purgeInterval=$ZOO_AUTOPURGE_PURGEINTERVAL"
            echo "maxClientCnxns=$ZOO_MAX_CLIENT_CNXNS"
            echo "standaloneEnabled=$ZOO_STANDALONE_ENABLED"
            echo "admin.enableServer=$ZOO_ADMINSERVER_ENABLED"
            echo "admin.serverAddress=0.0.0.0"
            echo "admin.serverPort=8018"
            echo "4lw.commands.whitelist=*"
        } >> "$CONFIG"
        if [[ -z $ZOO_SERVERS ]]; then
            ZOO_SERVERS="server.1=otter:2888:3888"
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
    
    gosu admin mkdir -p $ZOO_DATA_DIR
    gosu admin mkdir -p $ZOO_LOG_DIR
    gosu admin mkdir -p $ZOO_DIR/logs
    chown -R admin:admin $ZOO_DIR/logs
    chmod -R 755 $ZOO_DIR/logs
    chown -R admin:admin $ZOO_DATA_DIR
    chown -R admin:admin $ZOO_LOG_DIR
    chmod -R 755 $ZOO_DATA_DIR
    chmod -R 755 $ZOO_LOG_DIR
    cd $ZOO_DATA_DIR
    gosu admin $ZOO_DIR/bin/zkServer.sh start >> $ZOO_DATA_DIR/zookeeper.log 2>&1

    checkStart "zookeeper" "echo stat | nc 127.0.0.1 2181 | grep -c Outstanding" 120
}

function stop_zookeeper() {
    echo "stop zookeeper"
    gosu admin mkdir -p $ZOO_DATA_DIR
    cd $ZOO_DATA_DIR
    gosu admin $ZOO_DIR/bin/zkServer.sh stop >> $ZOO_DATA_DIR/zookeeper.log 2>&1
    echo "stop zookeeper successful ..."
}

function start_manager() {
    echo "start manager ..."
    cd /home/admin/manager/bin
    gosu admin sh startup.sh 1>>/tmp/start_manager.log 2>&1
    checkStart "manager" "nc 127.0.0.1 8080 -w 1 -z | wc -l" 120
}

function stop_manager() {
    echo "stop manager"
    cd /home/admin/manager/bin
    gosu admin sh stop.sh 1>>/tmp/start_manager.log 2>&1
    echo "stop manager successful ..."
}

function start_node() {
    echo "start node ..."
    cd /home/admin/node/bin/
    gosu admin bash -c "echo ${ZOO_MY_ID:-1} > /home/admin/node/conf/nid"
    gosu admin sh startup.sh ${ZOO_MY_ID:-1} >>/tmp/start_node.log 2>&1
    checkStart "node" "nc 127.0.0.1 2088 -w 1 -z | wc -l" 120
    node_is_run=$(nc 127.0.0.1 2088 -w 1 -z | wc -l)
    echo "node_is_run:"$node_is_run
    if [ $node_is_run == 0 ]; then
        echo -e "\033[32m ==> restart Node ... \033[0m"
        stop_node
        start_node
    fi
}

function stop_node() {
    echo "stop node"
    cd /home/admin/node/bin/
    gosu admin sh stop.sh
    echo "stop node successful ..."
}

echo "==> START ..."
start_zookeeper

if [ "${RUN_MODE}" == "ALL" ]; then
    echo -e "\033[32m ==> START RUN_MODE: "${RUN_MODE}"... \033[0m"
    start_manager
    echo "you can visit manager link : http://$host:8080/ , just have fun !"
    start_node    
fi

if [ "${RUN_MODE}" == "NODE" ]; then
    echo -e "\033[32m ==> START RUN_MODE: "${RUN_MODE}"... \033[0m"
    start_node    
fi

if [ "${RUN_MODE}" == "MANAGER" ]; then
    echo -e "\033[32m ==> START RUN_MODE: "${RUN_MODE}"... \033[0m"
    start_manager  
    echo "you can visit manager link : http://$host:8080/ , just have fun !"  
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