FROM cmccm123/hadoop:3.4
RUN ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa
COPY ./hadoop_config/* /etc/hadoop/
RUN apt-get install openssh-server