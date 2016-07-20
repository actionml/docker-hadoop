#!/bin/bash
# Script locates ip for a namenode to bind to. Generates config and starts namenode/datanode.
# expects: HADOOP_HOME, HADOOP_HDFS_USER

# hadoop-env.sh is not used!!! If env should be passed the propper way
# is to use docker --env-file option.

: ${HADOOP_HOME:?Must be provided\!}
: ${HADOOP_HDFS_USER:?Must be provided\!}
export HADOOP_NAMENODE_ADDRESS

setup_namenode() {
  export HADOOP_NAMENODE_BINDIF=${HADOOP_NAMENODE_BINDIF:-eth0}

  if [ -z "$HADOOP_NAMENODE_ADDRESS" ]; then
    cidr_ip=$(ip a show $HADOOP_NAMENODE_BINDIF | grep "inet " | tr -s ' ' | cut -f 3 -d' ')
    HADOOP_NAMENODE_ADDRESS="${cidr_ip%/*}"
  fi
}

setup_datanode() {
  : ${HADOOP_NAMENODE_ADDRESS:?Must be provided\!}
}

## Sleep before starting up
#
sleep ${WAITFORSTART:-0}

## Choose start up mode
#
service=$1; shift
case $service in
  namenode|datanode)
    eval setup_$service
  ;;
  *)
    >&2 echo "Hadoop container supports modes: namenode, datanode!"
    exit 1
  ;;
esac

# Configure hadoop from template (confd)
#
confd -onetime -backend env

# Start namenode
exec su -c "exec $HADOOP_HOME/bin/hdfs $service" $HADOOP_HDFS_USER
