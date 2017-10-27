FROM centos:centos6
# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r postgres && useradd -r -g postgres postgres

RUN yum -y update; yum clean all

# grab gosu for easy step-down from root
RUN gpg --keyserver pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4
RUN yum install -y ca-certificates wget && rm -rf /var/lib/apt/lists/* \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.2/gosu-amd64" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/1.2/gosu-amd64.asc" \
	&& gpg --verify /usr/local/bin/gosu.asc \
	&& rm /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& yum remove -y wget

RUN yum install -y http://yum.postgresql.org/9.4/redhat/rhel-6-x86_64/pgdg-centos94-9.4-3.noarch.rpm
RUN yum install postgresql94-server postgresql94 postgresql94-contrib postgresql94-plperl -y

ENV LANG en_US.utf8

RUN mkdir /docker-entrypoint-initdb.d

ENV PG_MAJOR 9.4
ENV PG_VERSION 9.4-1

RUN mkdir -p /var/run/postgresql && chown -R postgres /var/run/postgresql

ENV PATH /usr/pgsql-$PG_MAJOR/bin:$PATH
ENV PGDATA /var/lib/postgresql/data
VOLUME /var/lib/postgresql/data

COPY docker-entrypoint.sh /
COPY src/* /docker-entrypoint-initdb.d/

ENTRYPOINT ["/bin/sh", "/docker-entrypoint.sh"]

EXPOSE 5432

CMD ["postgres", "-c", "log_connections=on", "-c", "log_disconnections=on"]
