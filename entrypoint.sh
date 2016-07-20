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

## Handle startup bahaviour
#
case $1 in
  hdfs)
    shift
    [ -z "$1" ] || eval setup_$1

    # Configure hadoop from template (confd) and run hdfs command
    confd -onetime -backend env
    exec su -c "exec $HADOOP_HOME/bin/hdfs $1" $HADOOP_HDFS_USER
    ;;
  *)
    # Start helper script if any
    [ -x "/$1.sh" ] && exec "/$1.sh"

    # Fallback for other commands
    cmdline="$@"
    exec ${cmdline:-/bin/bash}
    ;;
esac
