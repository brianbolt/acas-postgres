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

ENV PG_MAJOR 9.4
ENV PG_MJR 94
ENV PG_VERSION 9.4-2

RUN yum install -y http://yum.postgresql.org/$PG_MAJOR/redhat/rhel-6-x86_64/pgdg-centos$PG_MJR-$PG_VERSION.noarch.rpm
RUN yum install postgresql$PG_MJR-server postgresql$PG_MJR postgresql$PG_MJR-contrib postgresql$PG_MJR-devel postgresql$PG_MJR-plperl -y

ENV LANG en_US.utf8

RUN mkdir /docker-entrypoint-initdb.d

RUN mkdir -p /var/run/postgresql && chown -R postgres /var/run/postgresql

ENV PATH /usr/pgsql-$PG_MAJOR/bin:$PATH
ENV PGDATA /var/lib/postgresql/data
VOLUME /var/lib/postgresql/data

RUN yum install -y cmake tk-devel readline-devel zlib-devel bzip2-devel sqlite-devel @development-tools
RUN yum install -y wget gcc-c++ python-devel numpy
WORKDIR /opt
ENV BOOST_VERSION_DOT 1.48.0
ENV BOOST_VERSION 1_48_0 
RUN wget http://downloads.sourceforge.net/project/boost/boost/$BOOST_VERSION_DOT/boost_$BOOST_VERSION.tar.gz && tar -zxf boost_$BOOST_VERSION.tar.gz
WORKDIR /opt/boost_$BOOST_VERSION
RUN ./bootstrap.sh --with-libraries=python,regex,thread,serialization
RUN ./b2 install

ENV RDKIT_VERSION 2016_09_1

WORKDIR /opt
RUN wget https://github.com/rdkit/rdkit/archive/Release_$RDKIT_VERSION.tar.gz && tar -zxf Release_$RDKIT_VERSION.tar.gz
ENV RDBASE /opt/rdkit-Release_$RDKIT_VERSION
ENV LD_LIBRARY_PATH /usr/pgsql-$PG_MAJOR/lib:/usr/lib64/:$RDBASE/lib:/usr/local/lib/
RUN mkdir $RDBASE/build
WORKDIR $RDBASE/build
RUN cmake -DBOOST_ROOT=/opt/boost_$BOOST_VERSION -DRDK_BUILD_PGSQL=ON -DPostgreSQL_ROOT=/usr/pgsql-$PG_MAJOR -DPostgreSQL_TYPE_INCLUDE_DIR=/usr/pgsql-$PG_MAJOR/include/server/ ..
RUN make
RUN make install
RUN chmod +x $RDBASE/build/Code/PgSQL/rdkit/pgsql_install.sh
RUN $RDBASE/build/Code/PgSQL/rdkit/pgsql_install.sh

COPY docker-entrypoint.sh /
COPY src/* /docker-entrypoint-initdb.d/

ENTRYPOINT ["/bin/sh", "/docker-entrypoint.sh"]

EXPOSE 5432
CMD ["postgres"]
