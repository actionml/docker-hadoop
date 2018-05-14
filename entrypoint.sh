#!/bin/bash
# Script locates ip for a namenode to bind to. Generates config and starts namenode/datanode.
# expects: HADOOP_HOME, HADOOP_HDFS_USER

# hadoop-env.sh is not used!!! If env should be passed the propper way
# is to use docker --env-file option.

: ${HADOOP_HOME:?Must be provided\!}
: ${HADOOP_HDFS_USER:?Must be provided\!}

export HADOOP_NAMENODE_ADDRESS

# Pick up Namenode address
setup_namenode() {
  export HADOOP_NAMENODE_BINDIF=${HADOOP_NAMENODE_BINDIF:-eth0}

  if [ -z "$HADOOP_NAMENODE_ADDRESS" ]; then
    cidr_ip=$(ip a show $HADOOP_NAMENODE_BINDIF | grep "inet " | tr -s ' ' | cut -f 3 -d' ')
    HADOOP_NAMENODE_ADDRESS="${cidr_ip%/*}"
  fi
}

# Set Hadoop directories owner
chown_volume() {
  paths="/hadoop/dfs/name /hadoop/dfs/sname1 /hadoop/dfs/data1"
  mkdir -p ${paths}
  chown ${HADOOP_HDFS_USER}:${HADOOP_HDFS_USER} ${paths}
}

# Setup before handing off to the Hadoop binary
setup() {
  fail=$1
  [ -z "$fail" ] || : ${HADOOP_NAMENODE_ADDRESS:?Must be provided\!}

  # write core-site.xml and hdfs-site.xml
  confd -onetime -backend env

  # chown directories
  chown_volume
}


## Sleep before starting up
#
sleep ${WAITFORSTART:-0}

## Handle startup behavior
#
case $1 in
  hdfs)
    # Namenode picks its address automatically
    shift
    [ "$1" != "namenode" ] || setup_namenode

    setup fail
    exec gosu $HADOOP_HDFS_USER $HADOOP_HOME/bin/hdfs $@
    ;;
  *)
    setup

    # Start helper script if any (exec without dropping privileges)
    [ -x "/$1.sh" ] && exec "/$1.sh"

    # Run a random command as Hadoop user
    exec gosu $HADOOP_HDFS_USER $@
    ;;
esac
