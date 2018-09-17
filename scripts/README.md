# DCOS Toolkit - Utils

## Utility scripts for dcos, mesos, marathon and other dcos services

### [dcosUtil.sh](dcosUtil.sh)

```text
===================
= DCOS Util Usage =
===================
Please input any one operation from : [ help addAWSKey agentsDetails publicIP saveMarathonConfig appsReport nodes nodeSsh taskNodeSsh taskExec tasksByNode switchCluster cleanService getUsers addUsers deleteUsers getConstraints getZNodeData runOnAllAgents runOnAllMasters runOnLeader ]
- Below operations are supported :
   - help
       - Get help for this utility script.
       - Usage : `bash dcosUtil.sh help`
   - addAWSKey
       - Add the private key of dcos cluster to ssh. Fetches KeyName using aws cli and add if it exits in $HOME/.ssh folder
       - Usage : `bash dcosUtil.sh addAWSKey`
   - agentsDetails
       - Get the list of Public and Private agents along with IP addresses and dcos node ID
       - Usage : `bash dcosUtil.sh agentsDetails <Required - Type of nodes - private, public, all [default]>`
   - publicIP
       - Get the Public IP of public and master nodes.
       - Usage : `bash dcosUtil.sh publicIP <Required - Type of nodes - public [default], masters, leader>`
   - nodes
       - Get the list of nodes along with their type, private IP address, node attributes, number of tasks running, free mem and cpu.
       - There will be a seperate node entry for each node attribute.
       - Usage : `bash dcosUtil.sh nodes`
   - saveMarathonConfig
       - Download the marathon config of all the apps/services running on dcos cluster and save all json files.
       - Usage : `bash dcosUtil.sh saveMarathonConfig <Oprional - app name [default download config for all apps]>`
   - appsReport
       - This will display the docker image and tag used for each app/sevice of DCOS cluster
       - Usage : `bash dcosUtil.sh appsReport`
   - nodeSsh
       - This will ssh to dcos node, need Private IP of node as input, if not specified will prompt for user to input
       - Use 'leader' as Private IP input to ssh to master leader node.
       - Usage : `bash dcosUtil.sh nodeSsh <Private IP of node>`
   - taskNodeSsh
       - This will ssh to dcos node where task is running. Need task name as input.
       - If more than 1 instance are running of the services, this will ssh to first instance's node. Give task ID as input for specific instance.
       - Usage : `bash dcosUtil.sh taskNodeSsh <task name / task ID>`
   - taskExec
       - This will run command inside container running for a task. Need task name / ID as input.
       - If more than 1 instance are running of the services, this will ssh to first instance's node. Give task ID as input for specific instance.
       - Usage : `bash dcosUtil.sh taskExec <task name / task ID>`
   - tasksByNode
       - This will fetch the task name and task id running on perticular node.
       - Need node ip as input.
       - Usage : `bash dcosUtil.sh tasksByNode <Node ip>`
   - switchCluster
       - Switch to other dcos cluster
       - Usage : `bash dcosUtil.sh switchCluster <Cluster Name to switch>`
   - cleanService
       - Clean the service and its reserved resources from zookeeper using mesosphere janiter script
       - Usage : `bash dcosUtil.sh cleanService <service name, ex kafka, kafka-zookeeper, elastic>`
   - getUsers
       - Get the users which are added to cluster organization
       - Usage : `bash dcosUtil.sh getUsers`
   - addUsers
       - Add users to cluster organization
       - Usage : `bash dcosUtil.sh addUsers <Required - File path where each user per line to add>`
   - deleteUsers
       - Delete users from cluster organization
       - Usage : `bash dcosUtil.sh deleteUsers <Required - File path where each user per line to delete>`
   - getConstraints
       - Get the apps which are using placement constraints
       - Usage : `bash dcosUtil.sh getConstraints`
   - getZNodeData
       - Get the data for MESOS Zookeeper Node.
       - Usage : `bash dcosUtil.sh getZNodeData`
   - runOnAllAgents
       - Run user command on all dcos nodes
       - Usage : `bash dcosUtil.sh runOnAllAgents "<command to run, ex systemctl status filebeat.service>"`
   - runOnLeader
       - Run user command on dcos leader master
       - Usage : `bash dcosUtil.sh runOnLeader "<command to run, ex systemctl status filebeat.service>"`
   - runOnAllMasters
       - Run user command on all dcos master nodes
       - Usage : `bash dcosUtil.sh runOnAllMasters "<command to run, ex systemctl status filebeat.service>"`
```

[addNodeAttributes.sh](addNodeAttributes.sh)

```bash
# Usage : 
$ addNodeAttributes.sh <; separated key:value pairs as node attributes> <File path where each node IP per line to add attributes>
# Example : 
$ addNodeAttributes.sh <key1>:<value1>;<key2>:<value2> /path/to/nodes/ip/file

$ addNodeAttributes.sh "SERVER_TYPE:DB;DB_TYPE:POSTGRES" "/tmp/POSTGRES_NDOES.txt"

$ cat /tmp/POSTGRES_NDOES.txt
10.0.0.1
10.0.0.2
10.0.0.3
```