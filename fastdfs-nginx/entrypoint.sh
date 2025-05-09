#!/bin/bash
#set -e
if [ "$debug" = "true" ]; then
    set -x
fi

GROUP_NAME=${GROUP_NAME:-group1}
if [ -n "$GET_TRACKER_SERVER" ]; then
    export TRACKER_SERVER=$(eval $GET_TRACKER_SERVER)
fi

function fdfs_set() {
    if [ "$1" = "monitor" ] ; then
        if [ -n "$TRACKER_SERVER" ] ; then  
          sed -i "s|tracker_server[ ]*=[ ]*.*$|tracker_server = ${TRACKER_SERVER}|g" /etc/fdfs/client.conf
        fi
        fdfs_monitor /etc/fdfs/client.conf
        exit 0
    elif [ "$1" = "storage" ] ; then
        FASTDFS_MODE="storage"
    else 
        FASTDFS_MODE="tracker"
    fi
    
    if [ -n "$PORT" ] ; then  
        sed -i "s|^port[ ]*=[ ]*.*$|port = ${PORT}|g" /etc/fdfs/"$FASTDFS_MODE".conf
    fi
    
    if [ -n "$TRACKER_SERVER" ] ; then  
        sed -i "s|^tracker_server[ ]*=[ ]*.*$|tracker_server = ${TRACKER_SERVER}|g" /etc/fdfs/storage.conf
        sed -i "s|^tracker_server[ ]*=[ ]*.*$|tracker_server = ${TRACKER_SERVER}|g" /etc/fdfs/client.conf
        sed -i "s|^tracker_server[ ]*=[ ]*.*$|tracker_server = ${TRACKER_SERVER}|g" /etc/fdfs/mod_fastdfs.conf
    fi
    
    sed -i "s|^group_name[ ]*=[ ]*.*$|group_name = ${GROUP_NAME}|g" /etc/fdfs/storage.conf
    sed -i "s|^group_name[ ]*=[ ]*.*$|group_name = ${GROUP_NAME}|g" /etc/fdfs/mod_fastdfs.conf
}
    
function fdfs_start() {
    FASTDFS_LOG_FILE="${FASTDFS_BASE_PATH}/logs/${FASTDFS_MODE}d.log"
    PID_NUMBER="${FASTDFS_BASE_PATH}/data/fdfs_${FASTDFS_MODE}d.pid"
    
    echo "try to start the $FASTDFS_MODE node..."
    fdfs_${FASTDFS_MODE}d /etc/fdfs/${FASTDFS_MODE}.conf stop
    if [ -f "$FASTDFS_LOG_FILE" ]; then 
        rm -f "$FASTDFS_LOG_FILE"
    fi
    if [ -f "$PID_NUMBER" ]; then
        rm -f "$PID_NUMBER"
    fi

    # start the fastdfs node.	
    fdfs_${FASTDFS_MODE}d /etc/fdfs/${FASTDFS_MODE}.conf start
}

function nginx_set() {
    # start nginx.
    if [ "${FASTDFS_MODE}" = "storage" ]; then
        cp -f /nginx_conf/conf.d/${FASTDFS_MODE}.conf /usr/local/nginx/conf/conf.d/
        sed -i "s|group1|${GROUP_NAME}|g" /usr/local/nginx/conf/conf.d/${FASTDFS_MODE}.conf
        /usr/local/nginx/sbin/nginx
    elif [ "${FASTDFS_MODE}" = "tracker" ]; then
        cp -f /nginx_conf/conf.d/${FASTDFS_MODE}.conf /usr/local/nginx/conf/conf.d/
        # 持续检测直到端口可达
        until curl -I --silent --connect-timeout 2 "http://storage0:8080" >/dev/null; do
            echo "等待中... Storage 服务未就绪，5 秒后重试。"
            sleep 5
        done
        echo "成功：Storage 的 8080 端口可达，启动 Nginx。"
        /usr/local/nginx/sbin/nginx
    fi
}

function health_check() {
    if [ $HOSTNAME = "localhost.localdomain" ]; then
        return 0
    fi
    # Storage OFFLINE, restart storage.
    monitor_log=/tmp/monitor.log
    check_log=/tmp/health_check.log
    while true; do
        fdfs_monitor /etc/fdfs/client.conf 1>$monitor_log 2>&1
        cat $monitor_log|grep $HOSTNAME > $check_log 2>&1
        error_log=$(egrep "OFFLINE" "$check_log")
        if [ ! -z "$error_log" ]; then
            cat /dev/null > "$FASTDFS_LOG_FILE"
            fdfs_start
        fi
        sleep 10
    done
}

if [ "$CUSTOM_CONFIG" == "false" ]; then
    fdfs_set $*
    nginx_set $*
fi

fdfs_start
health_check &

# wait for pid file(important!),the max start time is 30 seconds,if the pid number does not appear in 30 seconds,start failed.
TIMES=30
while [ ! -f "$PID_NUMBER" -a $TIMES -gt 0 ]
do
    sleep 1s
    TIMES=`expr $TIMES - 1`
done

case $1 in
    monitor|storage|tracker)
    # sleep infinity
    [ -f "$FASTDFS_LOG_FILE" ] && tail -f "$FASTDFS_LOG_FILE"
    ;;
    *)
    exec "$@"
    ;;
esac
