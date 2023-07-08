FROM ubuntu:20.04

ARG USER=root
ARG HADOOP_HOME=/usr/local/hadoop
ARG HIVE_HOME=/usr/local/hive
ARG HADOOP_ENV=$HADOOP_HOME/etc/hadoop/hadoop-env.sh
ARG DEBIAN_FRONTEND=noninteractive
#Install mysql

RUN echo "mysql-community-server mysql-community-server/root-pass password 'dsano.1'" | debconf-set-selections
RUN echo "mysql-community-server mysql-community-server/re-root-poss password 'dsano.1'" | debconf-set-selections
RUN apt-get update && apt-get install -y mysql-server \
    && mkdir -p /var/lib/mysql /var/run/mysqld \
    && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
    && chmod 777 /var/run/mysqld


# setup mysql
COPY ./mysql/mysql-init.sql mysql-init.sql
RUN service mysql start && mysql mysql < ./mysql-init.sql && rm ./mysql-init.sql

# install lib
RUN apt-get update && apt-get install -y curl ssh openjdk-8-jdk vim openssh-server net-tools iputils-ping && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash --groups sudo dsa
RUN /bin/echo -e 'dsano.1\ndsano.1' | passwd dsa
RUN /bin/echo -e 'dsano.1\ndsano.1' | passwd root

#COPY ./hadoop-3.3.4.tar.gz hadoop-3.3.4.tar.gz
#COPY ./apache-hive-3.1.3-bin.tar.gz apache-hive-3.1.3-bin.tar.gz

# RUN wget https://downloads.apache.org/hadoop/common/hadoop-3.3.4/hadoop-3.3.4.tar.gz
# RUN wget https://downloads.apache.org/hive/hive-3.1.3/apache-hive-3.1.3-bin.tar.gz



RUN wget https://downloads.apache.org/hadoop/common/hadoop-3.3.4/hadoop-3.3.4.tar.gz \
	&& tar xzvf hadoop-3.3.4.tar.gz -C /usr/local \
	&& rm hadoop-3.3.4.tar.gz \
	&& mv /usr/local/hadoop-3.3.4 $HADOOP_HOME \
	&& chown -R root $HADOOP_HOME

RUN wget https://downloads.apache.org/hive/hive-3.1.3/apache-hive-3.1.3-bin.tar.gz \
	&& tar xzvf apache-hive-3.1.3-bin.tar.gz -C /usr/local \
	&& rm apache-hive-3.1.3-bin.tar.gz \
	&& mv /usr/local/apache-hive-3.1.3-bin $HIVE_HOME



WORKDIR /usr/local/hadoop

#set env
RUN echo "export VISIBLE=now" >> ~/.bashrc
RUN echo "export HADOOP_HOME=$HADOOP_HOME" >> ~/.bashrc
RUN echo "export HIVE_HOME=$HIVE_HOME" >> ~/.bashrc
RUN echo "export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HIVE_HOME/bin" >> ~/.bashrc


#setup hadoop
RUN echo 'export JAVA_HOME="$(dirname $(dirname $(readlink -f $(which javac))))"' >> $HADOOP_ENV && \
	echo "export HADOOP_HOME=$HADOOP_HOME" >> $HADOOP_ENV && \
	echo "export HDFS_DATANODE_USER=$USER" >> $HADOOP_ENV && \
	echo "export HDFS_NAMENODE_USER=$USER" >> $HADOOP_ENV && \
	echo "export HDFS_SECONDARYNAMENODE_USER=$USER" >> $HADOOP_ENV && \
	echo "export YARN_NODEMANAGER_USER=$USER" >> $HADOOP_ENV && \
	echo "export YARN_RESOURCEMANAGER_USER=$USER" >> $HADOOP_ENV
ENV HADOOP_HOME=$HADOOP_HOME

COPY ./hadoop_config/* /usr/local/hadoop/etc/hadoop/
RUN ${HADOOP_HOME}/bin/hdfs namenode -format  && rm  /usr/local/hadoop/etc/hadoop/workers && rm  /usr/local/hadoop/etc/hadoop/hive-site.xml

#setup hive
WORKDIR /usr/local
RUN wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j_8.0.33-1ubuntu20.04_all.deb
RUN dpkg -i mysql-connector-j_8.0.33-1ubuntu20.04_all.deb
RUN cp /usr/share/java/mysql-connector-java-8.0.33.jar $HIVE_HOME/lib/
RUN rm /usr/local/hive/lib/log4j-slf4j-impl-*.jar

COPY ./hadoop_config/hive-site.xml /usr/local/hive/conf/hive-site.xml
RUN service mysql start && ${HIVE_HOME}/bin/schematool -initSchema -dbType mysql

## set ssh key
RUN ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa
RUN cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys

## setup ssh
RUN mkdir /var/run/sshd
RUN sed -i 's@#HostKey /etc/ssh/ssh_host_rsa_key@HostKey ~/.ssh/id_rsa@g' /etc/ssh/sshd_config
RUN sed -i 's@#PermitRootLogin prohibit-password@PermitRootLogin yes@g' /etc/ssh/sshd_config
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd



RUN echo '/usr/sbin/sshd -D' >> ~/.bashrc

EXPOSE 9870/TCP 9868/TCP 9864/TCP 8088/TCP 22/TCP


CMD bash