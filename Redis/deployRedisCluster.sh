#!/bin/bash

export CUR_DIR="$(cd $(dirname $0); pwd)"

REDIS_NODE_COUNT=6
NODE_BASE_NAME="redis-node"
NODE_MASTER_NAME="redis"
REDIS_NDOE_TEMPLATE="$CUR_DIR/redis-node-template.json"
REDIS_NDOE_TMP="/tmp/redis-node-templates"
REDIS_APP_STATUS_TIMEOUT=180
REDIS_APP_STATUS_PERIOD=10
NODEPORT=6379
NODECPU=0.5
NODEMEM=4096

rm -rf $REDIS_NDOE_TMP
mkdir -p $REDIS_NDOE_TMP

echo ""
dcos node --json | jq '.[] | .hostname' -r > $REDIS_NODES

if [ $(cat $REDIS_NODES | wc -l) -lt $REDIS_NODE_COUNT ]; then
    echo "[Redis Cluster] DCOS node count is less than $REDIS_NODE_COUNT, can not deploy redis cluster. Exiting."
    exit 1
fi

for i in $(seq 1 $REDIS_NODE_COUNT)
do
    echo "[Redis Cluster] Creating node $i with below settings :"
    if [ $i -eq 1 ]; then
        NODEVIP="${NODE_MASTER_NAME}"
    else
        NODEVIP="${NODE_BASE_NAME}-$i"
    fi
    NODENAME="${NODE_BASE_NAME}-$i"
    VOLUMENAME="$DCOS_CLUSTER_NAME-$NODE_BASE_NAME-$i"
    NODEHOSTIP=$(cat $REDIS_NODES | tail -$i | head -1)
    echo -e "\tNode name = $NODENAME \tVolume name = $VOLUMENAME\tNode Host = $NODEHOSTIP\tNode VIP = $NODEVIP\tNode Port = $NODEPORT\tNode CPU = $NODECPU\tNode Memory = $NODEMEM"
    NODE_JSON="$REDIS_NDOE_TMP/$NODENAME.json"
    cp $REDIS_NDOE_TEMPLATE $NODE_JSON
    sed -i "s/#NODENAME#/$NODENAME/g; s/#NODEHOSTIP#/$NODEHOSTIP/g; s/#NODEVIP#/$NODEVIP/g; s/#NODEPORT#/$NODEPORT/g; s/#NODECPU#/$NODECPU/g; s/#NODEMEM#/$NODEMEM/g; s/#VOLUMENAME#/$VOLUMENAME/g" "$NODE_JSON"
    echo -e "[Redis Cluster] Marathon json config for node $NODENAME is created. Deploying now.\n"
    dcos marathon app add $NODE_JSON
done

step=0
while [ "$step" -le $REDIS_APP_STATUS_TIMEOUT ];
do
    runningRedisNodes=$(dcos task $NODE_BASE_NAME | grep -E "$NODE_BASE_NAME-\<[0-9]\>" | awk '{if ($4 == "R") print}' | wc -l)
    if [[ "$runningRedisNodes" -eq $REDIS_NODE_COUNT ]]; then
        echo -e "[Redis Cluster] All redis nodes are up and running. Proceeding with deploying redis-cluster-util app.\n"
        dcos task $NODE_BASE_NAME | grep -E "$NODE_BASE_NAME-\<[0-9]\>"
        echo ""
        break
    else
        echo "[Redis Cluster] Not all redis nodes are up and running. Current running nodes = $runningRedisNodes & Required Redis Node count = $REDIS_NODE_COUNT. Sleeping for $REDIS_APP_STATUS_PERIOD seconds."
        step=$((step+$REDIS_APP_STATUS_PERIOD))
        sleep $REDIS_APP_STATUS_PERIOD
    fi
done

if [[ "$step" -gt $REDIS_APP_STATUS_TIMEOUT ]]; then
    echo "[Redis Cluster] Redis nodes status check is timedout. Please check logs at cluster UI. Exiting."
    exit 1
fi

echo "[Redis Cluster] Deploying redis-cluster-util app."
dcos marathon app add $CUR_DIR/redis-cluster-util.json
echo "[Redis Cluster] Sleeping for 20 seconds to get redis-cluster-util app UP."
sleep 20
REDIS_NODES=$(dcos task $NODE_BASE_NAME | grep -E "$NODE_BASE_NAME-\<[0-9]\>" | awk -v port=$NODEPORT '{print $2":"port}' | paste -s -d' ')

echo "Confirm create redis cluster with redis nodes : $REDIS_NODES"
CURNUM=$RANDOM
read -p "To proceed execution, please enter the captcha [ $CURNUM ] : " USERNUM
if [[ $CURNUM != $USERNUM ]]; then
    echo "[Redis Cluster] Captcha not succeeded !!! Exiting now."
    return 1
else
    echo "[Redis Cluster] Captcha succeeded !!! Proceeding to execution."
fi

echo "[Redis Cluster] Forming redis cluster using redis-cluster-util container."
taskName='redis-cluster-util.infrastructure'
TaskId=`dcos task --json | jq --arg tname $taskName '[.[] | select(.name == $tname)][0] | .id' -r`
taskNodeIP=`dcos task $TaskId | awk 'FNR == 2 {print $2}'`
echo "[Redis Cluster] Task [ $taskName ] with task Id [ $TaskId ] is running on node [ $taskNodeIP ]."
taskContID=`dcos node ssh --option LogLevel=quiet --option StrictHostKeyChecking=no --private-ip=$taskNodeIP --master-proxy "docker ps -q --filter "label=MESOS_TASK_ID=$TaskId"" 2> /dev/null`
taskContID=`echo $taskContID | tr -d '\r'`
echo "[Redis Cluster] Task Docker Container ID : [ $taskContID ]"
echo "[Redis Cluster] Running [ docker exec -it $taskContID $taskCmd ]"
dcos node ssh --option StrictHostKeyChecking=no --option LogLevel=quiet --private-ip=$taskNodeIP --master-proxy "docker exec -it $taskContID redis-trib.rb create --replicas 1 $REDIS_NODES" 2>/dev/null
