FROM openjdk:8u212-jre-alpine

ARG kafka_version=2.7.0
ARG scala_version=2.13
ARG glibc_version=2.31-r0
ARG vcs_ref=unspecified
ARG build_date=unspecified
ARG consul_version=1.7.1
ARG hashicorp_releases=https://releases.hashicorp.com
ARG filebeat_version=7.5.0
ARG consul_url=consul

LABEL org.label-schema.name="kafka" \
      org.label-schema.description="Apache Kafka" \
      org.label-schema.build-date="${build_date}" \
      org.label-schema.vcs-url="https://github.com/wurstmeister/kafka-docker" \
      org.label-schema.vcs-ref="${vcs_ref}" \
      org.label-schema.version="${scala_version}_${kafka_version}" \
      org.label-schema.schema-version="1.0" \
      maintainer="wurstmeister"

ENV KAFKA_VERSION=$kafka_version \
    SCALA_VERSION=$scala_version \
    KAFKA_HOME=/opt/kafka \
    GLIBC_VERSION=$glibc_version \
    CONSUL_VERSION=$consul_version \
    HASHICORP_RELEASES=$hashicorp_releases \
    FILEBEAT_VERSION=$filebeat_version \
    CUSTOM_INIT_SCRIPT=/opt/kafka/bin/entrypointwrapper.sh \
    CONSUL_URL=$consul_url \
    KAFKA_ZOOKEEPER_CONNECT=zookeeper:2181 \
    KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=INSIDE:PLAINTEXT,OUTSIDE:PLAINTEXT \
    KAFKA_ADVERTISED_LISTENERS=INSIDE://kafka:9092,OUTSIDE://localhost:9094 \
    KAFKA_LISTENERS=INSIDE://0.0.0.0:9092,OUTSIDE://0.0.0.0:9094 \
    KAFKA_INTER_BROKER_LISTENER_NAME=INSIDE \
    KAFKA_RESERVED_BROKER_MAX_ID=1000000000 \
    HOSTNAME_COMMAND="hostname | awk -F'-' '{print $$2}'" \
    BROKER_ID_COMMAND="hostname -i | sed -e 's/\\.//g'"

ENV PATH=${PATH}:${KAFKA_HOME}/bin

COPY download-kafka.sh start-kafka.sh broker-list.sh create-topics.sh versions.sh /tmp/

RUN apk add --no-cache bash curl jq docker \
RUN apk add --no-cache bash curl jq \
 && chmod a+x /tmp/*.sh \
 && mv /tmp/start-kafka.sh /tmp/broker-list.sh /tmp/create-topics.sh /tmp/versions.sh /usr/bin \
 && sync && /tmp/download-kafka.sh \
 && tar xfz /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -C /opt \
 && rm /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz \
 && ln -s /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} ${KAFKA_HOME} \
 && rm /tmp/* \
 && wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk \
 && apk add --no-cache --allow-untrusted glibc-${GLIBC_VERSION}.apk \
 && rm glibc-${GLIBC_VERSION}.apk

RUN curl -L -o /tmp/consul.zip ${HASHICORP_RELEASES}/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip \
 && unzip -d /usr/bin /tmp/consul.zip && chmod +x /usr/bin/consul && rm /tmp/consul.zip \
 && mkdir -p /etc/consul.d/ \
 && mkdir -p /opt/consul-data/
 
ADD consul-kafka.json /etc/consul.d/

RUN curl https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${FILEBEAT_VERSION}-linux-x86_64.tar.gz -o /tmp/filebeat.tar.gz \
  && tar xzf /tmp/filebeat.tar.gz \
  && rm /tmp/filebeat.tar.gz \
  && mv filebeat-${FILEBEAT_VERSION}-linux-x86_64 /usr/share/filebeat \
  && cp /usr/share/filebeat/filebeat /usr/bin \
  && mkdir -p /etc/filebeat \
  && cp -a /usr/share/filebeat/module /etc/filebeat/
  
ADD filebeat.yml /etc/filebeat

RUN mkdir -p /opt/prometheus/ \
  && curl https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.12.0/jmx_prometheus_javaagent-0.12.0.jar -o /opt/prometheus/jmx-exporter.jar

ADD prometheus_kafka.yml /opt/prometheus/

ENV KAFKA_OPTS='-javaagent:/opt/prometheus/jmx-exporter.jar=7071:/opt/prometheus/prometheus_kafka.yml'

COPY overrides /opt/overrides

ADD entrypointwrapper.sh /opt/kafka/bin/

RUN chmod +x /opt/kafka/bin/entrypointwrapper.sh

VOLUME ["/kafka"]

# Use "exec" form so that it runs as PID 1 (useful for graceful shutdown)
CMD ["start-kafka.sh"]
