#!/bin/sh
# Format namenode (run as hdfs user)
#
#   /hadoop/* volumes are exported as volumes and are not persisted,
#   so we do this on RUNTIME (not during container build).

# expects: HADOOP_HOME HADOOP_HDFS_USER
#

if [ ! -f /hadoop/dfs/name/.formatted ]; then
  # Suppress warnings on "none" network
  echo "127.0.0.1 `hostname` localhost" >> /etc/hosts

  su -c "${HADOOP_HOME}/bin/hdfs namenode -format hdfs" $HADOOP_HDFS_USER
  touch /hadoop/dfs/name/.formatted
fi
