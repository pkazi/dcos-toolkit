#!/bin/bash

###########################################################################
#  Script     : dcosUtil.sh
#  Author     : ParvezAhamad Kazi (https://github.com/pkazi)
#  Description: This utility script is used to manage and query dcos cluster.
###########################################################################

DTSTAMP=`date +"%d%m%y-%H%M%S"`
BOXCHAR="="

function HeaderBox {
        msg="$BOXCHAR $* $BOXCHAR"
        edge=$(echo "$msg" | sed "s/./$BOXCHAR/g")
        echo ""
        echo "$edge"
        echo "$msg"
        echo "$edge"
}

function ConfirmProceed
{
        msg=$1
        CURNUM=$RANDOM
        HeaderBox "$msg"
        read -p "To proceed execution, please enter the captcha [ $CURNUM ] : " USERNUM
        if [[ $CURNUM != $USERNUM ]]; then
                read -p "Wrong captcha, do you want to retry ?[ y/n ] : " RETRYCH
                if [[ "$RETRYCH" == "y" ]] || [[ "$RETRYCH" == "Y" ]]; then
                        ConfirmProceed "$msg"
                else
                        echo "No captcha retry, Exiting."
                        exit 1
                fi
        else
                echo "Captcha succeeded !!! Proceeding to execution."
                echo ""
                return
        fi
}

function ShowDCOSConfig
{
        export DCOS_CLUSTER_NAME=`dcos config show cluster.name`
        export DCOS_CLUSTER_URL=`dcos config show core.dcos_url`
        export DCOS_CLUSTER_ACS_TOKEN=`dcos config show core.dcos_acs_token`

        HeaderBox "Current DCOS config"
        #dcos config show
        printf "%-15s : %-50s\n" "Cluster Name" "$DCOS_CLUSTER_NAME"
        printf "%-15s : %-50s\n" "Cluster URL" "$DCOS_CLUSTER_URL"
}

function help
{
HeaderBox "DCOS Util Usage"
echo "Please input any one operation from : [ `echo $operationList | tr ',' ' '` ]"
cat << 'EOF'
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
EOF
}

function agentsDetails
{
        type=${$1:-all}
        if [[ $type != "all" ]]; then
                HeaderBox "Private and Public Agents Details"
                dcos node --json |  jq '.[] | select(.type | contains("agent")) | if (.attributes.public_ip != null) then "Public Agent  : " else "Private Agent : " end + .id + " - " + .hostname ' -r | sort
        elif [[ $type != "private" ]]; then
                HeaderBox "Private Agents Details"
                dcos node --json |  jq '.[] | select(.type | contains("agent")) | select(.attributes.public_ip == null) | "Private Agent : " + .id + " - " + .hostname ' -r
        elif [[ $type != "public" ]]; then
                HeaderBox "Public Agents Details"
                dcos node --json |  jq '.[] | select(.type | contains("agent")) | select(.attributes.public_ip != null) | "Public Agent : " + .id + " - " + .hostname ' -r
        fi
}

function publicIP
{
        type=${$1:-public}

        if [[ $type != "public" ]]; then
                HeaderBox "Public IP of Public Agents"
                for ip in $(dcos node --json | jq '.[] | select(.attributes.public_ip == "true") | .ip' -r); 
                do
                        echo "Private IP : $ip"
                        echo "Public IP : $(dcos node ssh --option StrictHostKeyChecking=no --option LogLevel=quiet --master-proxy --private-ip=$id "curl -s ifconfig.co")"
                done 2>/dev/null
        elif [[ $type != "master" ]]; then
                HeaderBox "Public IP of All Masters"
                for ip in $(dcos node --json |  jq '.[] | select(.type | contains("master")) | .ip' -r); 
                do 
                        echo "Private IP : $ip"
                        echo "Public IP : $(dcos node ssh --option StrictHostKeyChecking=no --option LogLevel=quiet --master-proxy --private-ip=$ip "curl -s ifconfig.co")"
                done 2>/dev/null
        elif [[ $type != "leader" ]]; then
                HeaderBox "Public IP of Master Leader"
                leaderPrIP=$(dcos node --json |  jq '.[] | select(.type | contains("leader")) | .ip' -r)
                dcos node ssh --option StrictHostKeyChecking=no --option LogLevel=quiet --master-proxy --leader "curl -s ifconfig.co" 2>/dev/null
        else
                echo "Wrong Choice. Select from public / master / leader"
        fi
}

function saveMarathonConfig
{
        HeaderBox "Save Marathon Configs"
        ConfigPath="/tmp/dcos-config-$DCOS_CLUSTER_NAME-$DTSTAMP"
        servName=$1
        if [ ! -d $ConfigPath ]; then
                echo "Directory does not exist - $ConfigPath , Creating it."
                mkdir -p $ConfigPath
        fi
        if [ -d $ConfigPath ]; then
                printf '%.0s=' {1..120}
                printf "\n%-40s %-80s\n" "Config Name" "Saved At"
                printf '%.0s=' {1..120}
                count=0
                if [ ! -z $servName ]; then
                        dcos marathon app show $servName | jq '. | del(.tasks, .version, .versionInfo, .tasksHealthy, .tasksRunning, .tasksStaged, .tasksUnhealthy, .deployments, .executor, .lastTaskFailure, .args, .ports, .residency, .secrets, .storeUrls, .uris, .user)' >& $ConfigPath/$servName.json
                        printf "\n%-40s %-80s" "$servName" "$ConfigPath/$servName.json"
                        count=$((count + 1))
                else
                        # 1.9 to 1.11 convert, delete = .args .ports .residency .secrets .storeUrls .uris .user
                        for service in `dcos marathon app list --quiet | sort`; do
                                appName=${service/\//};
                                fileName=$(echo $appName |  cut -d"/" -f1,2,3 | tr "/" "_")
                                dcos marathon app show $appName | jq '. | del(.tasks, .version, .versionInfo, .tasksHealthy, .tasksRunning, .tasksStaged, .tasksUnhealthy, .deployments, .executor, .lastTaskFailure, .args, .ports, .residency, .secrets, .storeUrls, .uris, .user)' >& $ConfigPath/$fileName.json
                                printf "\n%-40s %-80s" "$service" "$ConfigPath/$fileName.json"
                                count=$((count + 1))
                        done
                fi
                printf "\n"
                printf '%.0s=' {1..120}
                echo -e "\nTotal $count configs are saved."
                printf '%.0s=' {1..120}
                printf "\n"
        else
                echo "Directory does not exist - $ConfigPath, Exiting."
        fi
}

function appsReport
{
        HeaderBox "DC/OS Apps Report"
        TMP_CSV_FILE=$(mktemp /tmp/dcos-config.XXXXXX.csv)
        TMP_CSV_FILE_SORT="${TMP_CSV_FILE}_sort"
        #dcos marathon app list --json | jq '.[] | if (.container.docker.image != null ) then .id + ",Docker Application," + .container.docker.image else .id + ",DCOS Service," + .labels.DCOS_PACKAGE_VERSION end' -r > $TMP_CSV_FILE
        dcos marathon app list --json | jq '.[] | .id + if (.container.type == "DOCKER") then ",Docker Container," + .container.docker.image else ",Mesos Container," + if(.labels.DCOS_PACKAGE_VERSION !=null) then .labels.DCOS_PACKAGE_NAME+":"+.labels.DCOS_PACKAGE_VERSION  else "[ CMD ]" end end' -r > $TMP_CSV_FILE
        sed -i "s|^/||g" $TMP_CSV_FILE
        sort -t "," -k2,2 -k3,3 -k1,1 $TMP_CSV_FILE > ${TMP_CSV_FILE_SORT}
        cnt=1
        printf '%.0s=' {1..150}
        printf "\n  %-5s%-35s%-23s%-40s%-20s\n" "No" "Application Name" "Container Type" "Docker Image" "Tag / Version"
        printf '%.0s=' {1..150}
        while IFS=, read -r app typ image; 
        do
                tag=`echo $image | awk -F':' -v im="$image" '{tag=(im=="[ CMD ]")?"NA":($2=="")?"latest":$2; print tag}'`
                image=`echo $image | awk -F':' '{print $1}'`
                printf "\n  %-5s%-35s%-23s%-40s%-20s" "$cnt" "$app" "$typ" "$image" "$tag"
                cnt=$((cnt + 1))
                sleep 0.3
        done < $TMP_CSV_FILE_SORT
        printf "\n"
        printf '%.0s=' {1..150}
        printf "\n"
}

function nodeSsh
{
        HeaderBox "DCOS Node SSH"
        nodeIp=$1
        
        if [ "$#" -eq 0 ]; then
                echo "Need IP address of node as input. Exiting..."
                echo ""
                dcos node
                echo ""
                exit 1
        fi
        shift
        if [ "${nodeIp}" == "leader" ]; then
	        cmd="dcos node ssh --option StrictHostKeyChecking=no --master-proxy --leader \"$*\""
        else
                cmd="dcos node ssh --option StrictHostKeyChecking=no --private-ip=${nodeIp} --master-proxy \"$*\""
        fi
        echo "Running $cmd"
        $cmd
}

function nodes
{
        HeaderBox "DCOS Node 2.0"
        printf "\n  %-15s %-18s%-18s%-10s%-15s%-10s\n" "Node Type" "Node IP" "Attribute" "Tasks" "Mem Free (MB)" "CPU Free"
        printf '%.0s=' {1..90}
        printf "\n"
        TAB=`echo -e "\t"`
        dcos node --json | jq '.[] | if (.type | contains("leader")) then "Master (leader)" elif ((.type | contains("agent")) and .attributes.public_ip != null) then "Public Agent" elif ((.type | contains("agent")) and .attributes.public_ip == null) then "Private Agent" else empty end + "\t"+ if(.type |contains("master")) then .ip else .hostname end + "\t" +  (if (.attributes | length !=0) then (.attributes | to_entries[] | join(" = ")) else "NA\t\t" end) + "\t" + if(.type |contains("agent")) then (.TASK_RUNNING|tostring) + "\t" + ((.resources.mem - .used_resources.mem)| tostring) + "\t\t" +  ((.resources.cpus - .used_resources.cpus)| tostring)  else "NA\tNA\t\tNA"  end' -r | sort -t"$TAB" -k1,1d -k3,3d -k2,2d
        printf '%.0s=' {1..90}
        printf "\n"
}

function taskNodeSsh
{
        if [ "$#" -eq 0 ]; then
                echo "Need task name as input. Exiting."
                exit 1
        fi
        taskName=$1
        taskNodeIP=`dcos task $taskName | awk 'FNR == 2 {print $2}'`
        if [[ -z $taskNodeIP ]]; then
                echo "No task found with name $taskName"
        else
                HeaderBox "DCOS Task Node SSH"
                echo "Task $taskName is running on node $taskNodeIP"
                nodeSsh $taskNodeIP
        fi
}

function taskExec
{
        HeaderBox "DCOS Task Exec 2.0"
        if [ "$#" -eq 0 ]; then
                echo "Need task name or id as input. Exiting."
                exit 1
        fi
        taskName=$1
        shift
        taskCmd="${*:-bash}"
        TMP_TASKLIST_JSON=$(mkdtemp /tmp/dcostasklist-XXXXXX.json)
        dcos task --json > $TMP_TASKLIST_JSON
        taskExist=`cat $TMP_TASKLIST_JSON | jq --arg tname $taskName '.[] | if(.name == $tname ) then .name else empty end' -r | wc -l`
        if [[ $taskExist -eq 0 ]]; then 
                echo "No task with name $taskName exists."
                echo "Do you mean ?"
                dcos task | grep $taskName | awk '{print $1}'
                exit 1
        fi
        taskType=`cat $TMP_TASKLIST_JSON | jq --arg tname $taskName '[.[] | select(.name == $tname)][0] | .container.type' -r`
        TaskId=`cat $TMP_TASKLIST_JSON | jq --arg tname $taskName '[.[] | select(.name == $tname)][0] | .id' -r`
        if [[ $taskExist -ne 1 ]]; then
                echo -e "$taskExist instances are running. Please select task ID for executing command.\n"
                allTaskIds=$(dcos task $taskName | tee /dev/tty | grep -v "NAME" | awk '{print $5}' | paste -s -d",")
                echo ""
                BASH_KIT_ValidateParameter "TaskId" "String" "false" "Task id for task $taskName." $allTaskIds
        fi
        if [[ $taskType != "DOCKER" ]]; then
                echo "Task [ $taskName ] is of type MESOS Container."
                execCmd="dcos task exec --interactive --tty $TaskId $taskCmd"
                echo "Running [$execCmd]"
                $execCmd
        else
                echo "Task [ $taskName ] is of type DOCKER Container."
                taskNodeIP=`dcos task $TaskId | awk 'FNR == 2 {print $2}'`
                echo "Task [ $taskName ] with task Id [ $TaskId ] is running on node [ $taskNodeIP ]."
                taskContID=`dcos node ssh --option LogLevel=quiet --option StrictHostKeyChecking=no --private-ip=$taskNodeIP --master-proxy "docker ps -q --filter "label=MESOS_TASK_ID=$TaskId"" 2> /dev/null`
                taskContID=`echo $taskContID | tr -d '\r'`
                echo "Task Docker Container ID : [ $taskContID ]"
                echo "Running [ docker exec -it $taskContID $taskCmd ]"
                dcos node ssh --option StrictHostKeyChecking=no --option LogLevel=quiet --private-ip=$taskNodeIP --master-proxy "docker exec -it $taskContID $taskCmd" 2>/dev/null
        fi
}

function tasksByNode
{
        HeaderBox "DCOS Tasks By Node"
        if [ "$#" -eq 0 ]; then
                echo "Need node ip as input. Exiting."
                exit 1
        fi
        nodeIp=$1
        dcos task | egrep "HOST|$nodeIp"
}

function addAWSKey
{
        CLUSTER_KEY=$(aws cloudformation describe-stacks --stack-name $DCOS_CLUSTER_NAME | jq '.Stacks[0].Parameters[]| select(.ParameterKey == "KeyName") | .ParameterValue' -r)
        if [ ! -z $CLUSTER_KEY ]; then
                ssh-add ~/.ssh/$CLUSTER_KEY.pem
        fi
}

function switchCluster
{
        HeaderBox "Switch DCOS Env"
        clusterName=$1
        
        if [ "$#" -eq 0 ]; then
                echo "Need Cluster name as input. Exiting ..."
                exit 1
        fi

        cmd="dcos cluster attach $clusterName"
        dcos cluster list | awk -v clusterName=$clusterName '{if ($1==clusterName) print $1}'
        echo "Running [ $cmd ]"
        $cmd
        ShowDCOSConfig
        dcos node > /dev/null 2>&1
        isAuthLogin=$?
        if [[ $isAuthLogin -eq 1 ]]; then
                HeaderBox "Need to authenticate dcos cluster."
                dcos auth login
        fi
        addAWSKey
}

function getUsers
{
        HeaderBox "DCOS Cluster Organization Users"
        curl -s -H "Authorization: Bearer $(dcos config show core.dcos_acs_token)" "$(dcos config show core.dcos_url)/acs/api/v1/users" | jq '.array[].uid' -r
}

function addUsers
{
        HeaderBox "DCOS Cluster Organization Add Users"
        usersFile=$1
        if [ -z $usersFile ]; then
                echo "Need Users file as input. Exiting."
                exit 1
        fi
        if [ ! -f $usersFile ]; then
                echo "Input users file is not valid. Please check. Exiting."
                ls -la $usersFile
                exit 1
        fi
        for i in `cat $usersFile`; do 
                echo "Adding user $i"
                curl -X PUT -H "Authorization: Bearer $(dcos config show core.dcos_acs_token)" "$(dcos config show core.dcos_url)/acs/api/v1/users/$i" -d "{}"
        done
}

function deleteUsers
{
        HeaderBox "DCOS Cluster Organization Delete Users"
        usersFile=$1
        if [ -z $usersFile ]; then
                echo "Need Users file as input. Exiting."
                exit 1
        fi
        if [ ! -f $usersFile ]; then
                echo "Input users file is not valid. Please check. Exiting."
                ls -la $usersFile
                exit 1
        fi
        for i in `cat users.list`; do 
                echo $i
                curl -X DELETE -H "Authorization: Bearer $(dcos config show core.dcos_acs_token)" "$(dcos config show core.dcos_url)/acs/api/v1/users/$i" -d "{}"
        done
}

function cleanService
{
        SERVICE_NAME=$1
        if [[ -z "$SERVICE_NAME" ]]; then
                echo "Need Service name for cleanup. Exiting ..."
                echo ""
                dcos service --inactive | egrep -v "marathon|metronome"
                exit 1
        fi
        BASH_KIT_ConfirmProceed "Cleanup service '$SERVICE_NAME'"
        dcos node ssh --option StrictHostKeyChecking=no  --master-proxy --leader "docker run mesosphere/janitor /janitor.py -r ${SERVICE_NAME}-role -p ${SERVICE_NAME}-principal -z dcos-service-${SERVICE_NAME}"
}

function getConstraints
{
        HeaderBox "DCOS Get apps with constraints"
        dcos marathon app list --json | jq '.[] | if (.constraints != null) then .id, .constraints else empty end'
}

function getZNodeData
{
        HeaderBox "DCOS Get Zookeeper Node Data"
        ZNODE=$1
        if [[ -z "$ZNODE" ]]; then
                echo "Need ZNode path to get data. Exiting."
                exit 1
        fi
        tmpFile="/tmp$ZNODE.json"
        mkdir -p $(dirname $tmpFile)
        echo "Getting Zookeeper Data for node - $ZNODE"
        curl -s -o $tmpFile -H "Authorization: Bearer $(dcos config show core.dcos_acs_token)" "$(dcos config show core.dcos_url)/exhibitor/exhibitor/v1/explorer/node-data?key=${ZNODE}"
        str=$(cat $tmpFile | jq '.str' -r)
        if [[ -z $str ]] || [[ $str == "Exception" ]]; then
                cat $tmpFile | jq '.stat' -r
        else
                echo $str
        fi
}

function runOnAllAgents
{
        HeaderBox "Run command [ $* ] on all agents nodes"
        for i in `dcos node | egrep -v "TYPE|master" | awk '{print $1}'`; do 
                echo -e "\n###> Running command [ $* ] on $i"
                dcos node ssh --option StrictHostKeyChecking=no --option LogLevel=quiet --master-proxy --private-ip=$i "$*"
                echo -e "======================================\n"
        done
}

function runOnLeader
{
        HeaderBox "Run command [ $* ] on leader"
        dcos node ssh --option StrictHostKeyChecking=no --option LogLevel=quiet --master-proxy --leader "$*"
}

function runOnAllMasters
{
        HeaderBox "Run command [ $* ] on all masters"
        for i in `dcos node | egrep -v "TYPE|agent" | awk '{print $2}'` 
        do 
                echo -e "\n###> Running command [ $* ] on $i"
                dcos node ssh --option StrictHostKeyChecking=no --option LogLevel=quiet --master-proxy --private-ip=$i "$*"
                echo -e "======================================\n"
        done
}

function cleanup
{
        rm $TMP_CSV_FILE_SORT $TMP_CSV_FILE $TMP_TASKLIST_JSON $TMP_NODELIST_JSON &> /dev/null
}

operationList="help,addAWSKey,agentsDetails,publicIP,saveMarathonConfig,appsReport,nodes,nodeSsh,taskNodeSsh,taskExec,tasksByNode,switchCluster,cleanService,getUsers,addUsers,deleteUsers,getConstraints,getZNodeData,runOnAllAgents,runOnAllMasters,runOnLeader"
oprList=`echo $operationList | tr "," "|"`

if [[ $# -ge 1 && "$1" =~ ^($oprList)$ ]] ; then
        Operation="$1"
else
        help
        exit
fi
shift
ShowDCOSConfig
$Operation $*
cleanup