#!/bin/bash

tmpScript=$(mktemp "/tmp/mesosNodeAttributes-XXXXXXXX")

ATTRIBUTES="$1"
NODES_FILE=$2

if [ "$#" -ne 2 ]; then
    echo "[Error] Wrong usage. Missing required input parameters."
    echo "[Error] Usage : $0 <; separated key:value pairs as node attributes> <File path where each node IP per line to add attributes>"
    echo "[Error] Example : $0 <key1>:<value1>;<key2>:<value2> /path/to/nodes/ip/file"
    exit 1
fi

if [ ! -f $NODES_FILE ]; then
    echo "[Error] Input nodes IP file is not valid. Please check. Exiting."
    ls -la $NODES_FILE
    exit 1
fi

cat <<EOF > ${tmpScript}
echo "MESOS_ATTRIBUTES=${ATTRIBUTES}" | sudo tee /var/lib/dcos/mesos-slave-common
sudo systemctl stop dcos-mesos-slave
sudo rm -f /var/lib/mesos/slave/meta/slaves/latest
sudo systemctl start dcos-mesos-slave
EOF

for i in `cat $NODES_FILE`; do
    echo $i
    dcos node ssh --master-proxy --option StrictHostKeyChecking=no --private-ip $i <$tmpScript
    sleep 10
done