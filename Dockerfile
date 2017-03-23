# Use testing to have a compatible version of OCaml
FROM debian:testing
LABEL maintainer thomas.calmant@inria.fr

# Add SparqlGX
COPY . /opt/sparqlgx
WORKDIR /opt/sparqlgx

# Image configuration
ARG HADOOP_VERSION=2.7.3
ENV HADOOP_URL https://www.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz

# Ensure a sane environment
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive

# Add support for HTTPS in aptitude
# and install Java 8, Scala and OCaml
RUN set -x && \
    apt-get update --fix-missing && \
    apt-get install -y apt-transport-https ocaml-nox opam m4 && \
    apt-get install -y --no-install-recommends curl vim openjdk-8-jdk-headless && \
    echo "deb https://dl.bintray.com/sbt/debian /" | tee -a /etc/apt/sources.list.d/sbt.list && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2EE0EA64E40A89B84B2DF73499E82A75642AC823 && \
    curl -fSLO http://downloads.lightbend.com/scala/2.12.1/scala-2.12.1.deb && \
    dpkg -i scala-2.12.1.deb && \
    apt-get update && \
    apt-get install -y sbt && \
    apt-get clean

# Install Hadoop
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/
RUN set -x && \
    curl -fSL -o - "$HADOOP_URL" | tar xz -C /opt/ && \
    ln -s /opt/hadoop-$HADOOP_VERSION/etc/hadoop /etc/hadoop && \
    cp /etc/hadoop/mapred-site.xml.template /etc/hadoop/mapred-site.xml && \
    mkdir /opt/hadoop-$HADOOP_VERSION/logs

# Update environment
ENV HADOOP_PREFIX=/opt/hadoop-$HADOOP_VERSION \
    HADOOP_CONF_DIR=/etc/hadoop

# Install Spark
RUN . /opt/sparqlgx/conf/compilation.conf && \
    curl -fSL -o - http://d3kbcqa49mib13.cloudfront.net/spark-${SPARK_VERSION}-bin-hadoop2.7.tgz | tar xz -C /opt && \
    ln -s /opt/spark-${SPARK_VERSION}-bin-hadoop2.7 /opt/spark

# Change user
RUN useradd sparqlgx --home-dir /opt/sparqlgx && \
    chown -R sparqlgx: /opt/sparqlgx
USER sparqlgx

# Install Menhir
RUN opam init -a && \
    echo ". /opt/sparqlgx/.opam/opam-init/init.sh > /dev/null 2> /dev/null || true" > ~/.bashrc && \
    opam install -y menhir

# Ensure that bash is the default shell
ENV SHELL=/bin/bash

# Compile and add SparqlGX to the path
RUN eval `opam config env` && \
    bash compile.sh && \
    ln -s /opt/sparqlgx/bin/sparqlgx.sh /opt/sparqlgx/bin/sparqlgx && \
    chmod +x /opt/sparqlgx/bin/sparqlgx.sh && sync
ENV PATH=/opt/sparqlgx/bin:/opt/spark/bin:$HADOOP_PREFIX/bin:$PATH

