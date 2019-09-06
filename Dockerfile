FROM java:8-jre-alpine
MAINTAINER Denis Baryshev <dennybaa@gmail.com>

ENV HADOOP_VERSION 2.8.4
ENV HADOOP_HOME /usr/local/hadoop-${HADOOP_VERSION}
ENV HADOOP_CONF_DIR /etc/hadoop
ENV HADOOP_HDFS_USER hdfs
ARG GLIBC_APKVER=2.27-r0
ARG GOSU_VERSION=1.11
ARG GIT_HASH
ARG DATE_BUILD
ARG BRANCH

# Hadoop environment variables
ENV HADOOP_OPTS -Djava.net.preferIPv4Stack=true
ENV HADOOP_PORTMAP_OPTS -Xmx512m
ENV HADOOP_CLIENT_OPTS -Xmx512m
ENV GIT_HASH=${GIT_HASH}
ENV DATE_BUILD=${DATE_BUILD}
ENV BRANCH=${BRANCH}


LABEL vendor=ActionML \
      version_tags="[\"2.8\",\"2.8.4\"]"


# install built-in packages and create users
RUN echo "@community http://nl.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk add --update --no-cache bash curl shadow@community && \
        \
      useradd -mU -d /home/hadoop hadoop && passwd -d hadoop && \
      useradd -mU -d /home/hdfs -G hadoop hdfs && passwd -d hdfs && \
      useradd -mU -d /home/hbase -G hadoop hbase && passwd -d hbase && \
      useradd -mU -d /home/aml aml && passwd -d aml


# Glibc compatibility
RUN curl -sSL https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIBC_APKVER/sgerrand.rsa.pub \
            -o /etc/apk/keys/sgerrand.rsa.pub && \
    curl -sSLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIBC_APKVER/glibc-i18n-$GLIBC_APKVER.apk && \
    curl -sSLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIBC_APKVER/glibc-$GLIBC_APKVER.apk && \
    curl -sSLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIBC_APKVER/glibc-bin-$GLIBC_APKVER.apk && \
    apk add --no-cache glibc-$GLIBC_APKVER.apk glibc-bin-$GLIBC_APKVER.apk glibc-i18n-$GLIBC_APKVER.apk && \
    echo "export LANG=$LANG" > /etc/profile.d/locale.sh && \
      rm /etc/apk/keys/sgerrand.rsa.pub glibc-*.apk


# get GoSU, confd
RUN apk add --update --no-cache --virtual .build-deps gnupg && \
      curl -sSL https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64 \
           -o /usr/local/bin/gosu && chmod 755 /usr/local/bin/gosu && \
      curl -sSL -o /tmp/gosu.asc https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64.asc && \
      export GNUPGHOME=/tmp && \
      gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
      # gpg --batch --keyserver hkps://pgp.mit.edu --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
      #   gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
        gpg --batch --verify /tmp/gosu.asc /usr/local/bin/gosu && \
            \
      curl -L https://github.com/kelseyhightower/confd/releases/download/v0.12.0-alpha3/confd-0.12.0-alpha3-linux-amd64 \
           -o /usr/local/bin/confd && chmod 755 /usr/local/bin/confd && \
    apk del .build-deps && rm -rf /tmp/*


# Fetch, unpack hadoop dist and prepare layout
RUN curl -L http://www-us.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz \
        | tar -xzp -C /usr/local && \
      mv ${HADOOP_HOME}/etc/hadoop /etc/ && \
      ln -s /etc/hadoop/ ${HADOOP_HOME}/etc/hadoop && \
      mkdir -p /hadoop/dfs/name /hadoop/dfs/sname1 /hadoop/dfs/data1 && \
      chown -R hdfs:hdfs /hadoop/dfs


VOLUME [ "/etc/hadoop", "/hadoop/dfs/name", "/hadoop/dfs/sname1", "/hadoop/dfs/data1" ]

# Add confd configuration files
ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates

ADD ./hdfs-site.xml ./hdfs-bootstrap-paths ${HADOOP_CONF_DIR}/
ADD ./*.sh /

ENTRYPOINT [ "/entrypoint.sh" ]

# HDFS exposed ports
EXPOSE 9000 50010 50020 50070 50075 50090
