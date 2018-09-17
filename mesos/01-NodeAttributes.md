# DCOS Toolkit - Mesos - Add node Attributes

- To use marathon constraints, we can specify attributes to every mesos node.
- Attributes are defined in key:value pairs and node can have multiple attributes.
- Attributes are useful to categorize the node, for example: nodes for DB servers can have attribute like 'SERVER_TYPE:DB' or 'DB_TYPE:MYSQL'
- Attributes are useful to add constraints on marathon apps to run on run on nodes with specific attributes.

## Steps to add node attributes on mesos node

1. SSH on node

2. Create or edit file  
    `sudo vi /var/lib/dcos/mesos-slave-common`

3. Add contents as :  
    `MESOS_ATTRIBUTES=<key1>:<value1>;<key2>:<value2>;...;<keyN>:<valueN>`

    >  Note - multiple attributes are separated by semicolon [;].  
    Example:
    MESOS_ATTRIBUTES=TYPE:DB;DB_TYPE:MONGO;

4. Stop dcos-mesos-slave service  
    `sudo systemctl stop dcos-mesos-slave`

5. Remove link for latest slave metadata  
    `sudo rm -f /var/lib/mesos/slave/meta/slaves/latest`

7. Start dcos-mesos-slave service  
    `sudo systemctl start dcos-mesos-slave`

8. Check status of dcos-mesos-slave service  
    `sudo systemctl status dcos-mesos-slave`

9. Wait for some time, node will be in HEALTHY state again.

10. Add app placement constraint with field = key and value = value

11. Verify attributes, run on any node  
    `curl -s http://leader.mesos:5050/state | jq '.slaves[]| .hostname ,.attributes'`

    or Check DCOS UI
    Nodes => Select any Node => Details Tab

## Automation Script

[addNodeAttributes.sh](../scripts/addNodeAttributes.sh)
