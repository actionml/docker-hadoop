[![DockerHub](https://img.shields.io/badge/docker-available-blue.svg)](https://hub.docker.com/r/dennybaa/hadoop) [![Build Status](https://travis-ci.org/dennybaa/docker-hadoop.svg?branch=master)](https://travis-ci.org/dennybaa/docker-hadoop)
# Docker Hadoop containers

These containers currently provide ability to deploy a standalone hadoop cluster which can contain two types of nodes: namenodes and datanodes. Hadoop architecture presumes that namenode (as well as secondary namenode) is run on separate host with datanodes. Namenode contains the whole HDFS cluster metadata which requires big amount of RAM while datanodes usually placed on commodity hardware and basically provide storage.

## Startup scenario

Bringing up Hadoop/HDFS cluster we'll require at least one namenode and a few datanodes. The algorithm looks like the following:

 1. Start namenode container, wait for the node to be ready.
 2. Format namenode to create an empty HDFS.
 3. Start several datanodes containers, wait for them to be ready.
 4. Bootstrap required directories and permissions in HDFS.

This order should be respected when you are starting Hadoop cluster! During work with our cluster we decouple **data** from a **service**, such approach might be useful for production because a namenode/datanode (a service) can be easily destroyed/recreated with possibility to preserve its data.


## Starting containers

Configuration of containers is stored in `/etc/hadoop` volume, it can be passed to the container as needed. Mind that default configuration uses auto-generation from templates hence actual files under `/etc/hadoop` are auto-generated according to `conf.d/*` and `templates/*` rules. To bootstrap a **default** cluster you will only require to grab namenode host name or IP address and pass it to datanode containers as *environment variable*.

### Starting namenode and formatting HDFS

First we create a primary namenode data container and format it then we run the namenode service container.

```
# data container
docker run -it --name primary-namenode-data dennybaa/hadoop /format-namenode.sh
# service container
docker run -d --name primary-namenode -p 50070:50070 --volumes-from primary-namenode-data dennybaa/hadoop /start.sh namenode
# wait for start (follow logs and ^C)
docker logs -f primary-datanode
```

### Starting datanode

During this step we start datanode container, *this step can be repeated several times*.

As been said above let's grab the namenode IP first:

```
namenode_ip=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' primary-namenode)
```

**Create data volume and service (the bellow step can be repeated several times).**
___

```
# (change number to reflect the actual container creation number)
# data container 
docker run -it --name datanode-data-1 dennybaa/hadoop /bin/true

# datanode service
docker run -d --name datanode-1 -e HADOOP_NAMENODE_ADDRESS=$namenode_ip --volumes-from datanode-data-1 dennybaa/hadoop /start.sh datanode

# wait for start (follow logs and ^C)
docker logs -f datanode-1
```

### Bootstrap HDFS

To bootstrap HDFS you can use this container for example like this:

```
docker run --rm -it -e HADOOP_NAMENODE_ADDRESS=$namenode_ip dennybaa/hadoop /bootstrap-hdfs.sh
```

Mind that the operation is of **run-once** nature, so there's no need to run it twice.
The bootstrap process can be tuned, just [hdfs-bootstrap-paths](hdfs-bootstrap-paths) file same as the one in repository and pass it to the container as volume `-v /path/to/hdfs-bootstrap-paths:/hdfs-bootstrap-paths`.

# Authors

* Denis Baryshev (dennybaa@gmail.com)
