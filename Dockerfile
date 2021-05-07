FROM germanedge-docker.artifactory.new-solutions.com/edge-one/ge-ubuntu-generic:0.16.0
ARG kafka_version=2.8.0
ARG scala_version=2.13
ARG zookeper_version=3.5.9

ENV KAFKA_VERSION=$kafka_version \
    SCALA_VERSION=$scala_version \
    KAFKA_HOME=/app/kafka \
    HOSTNAME_COMMAND="hostname | awk -F'-' '{print $$2}'" \
    BROKER_ID_COMMAND="/app/getfreebrokerid.sh" \
    KAFKA_ZOOKEEPER_CONNECT=zookeeper:2181 \
    KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=INSIDE:PLAINTEXT,OUTSIDE:PLAINTEXT \
    KAFKA_ADVERTISED_LISTENERS=INSIDE://:9092,OUTSIDE://_{HOSTNAME_COMMAND}:9094 \
    KAFKA_LISTENERS=INSIDE://0.0.0.0:9092,OUTSIDE://0.0.0.0:9094 \
    KAFKA_INTER_BROKER_LISTENER_NAME=INSIDE \
    KAFKA_RESERVED_BROKER_MAX_ID=1000000000 \
    KAFKA_LOG_RETENTION_BYTES=-1 \
    KAFKA_LOG_RETENTION_HOURS=-1 \
    KAFKA_LOG_DIRS=/app/kafka-data \
    SERVICENAME=kafka \
    PORT=9092 \
    CONSUL_TAGS='"primary","application","prometheus","config"' \
    CONSUL_META_SCRAPE_PATH="\/metrics" \
    CONSUL_META_SCRAPE_PORT=7071 \
    FILEBEAT_MODULES=kafka \
    FILEBEAT_ARGS='-M kafka.log.var.kafka_home=[/app/kafka]' \
    ZOOKEEPER_VERSION=$zookeper_version

COPY service.json /app/

USER root


#Set variables and install java 11
ENV JAVA_HOME=/usr/local/openjdk-11
ENV PATH=/usr/local/openjdk-11/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN /bin/sh -c set -eux; 		arch="$(dpkg --print-architecture)"; 	case "$arch" in 		arm64 | aarch64) downloadUrl=https://github.com/AdoptOpenJDK/openjdk11-upstream-binaries/releases/download/jdk-11.0.9%2B11/OpenJDK11U-jdk_aarch64_linux_11.0.9_11.tar.gz ;; 		amd64 | i386:x86-64) downloadUrl=https://github.com/AdoptOpenJDK/openjdk11-upstream-binaries/releases/download/jdk-11.0.9%2B11/OpenJDK11U-jdk_x64_linux_11.0.9_11.tar.gz ;; 		*) echo >&2 "error: unsupported architecture: '$arch'"; exit 1 ;; 	esac; 		savedAptMark="$(apt-mark showmanual)"; 	apt-get update; 	apt-get install -y --no-install-recommends 		dirmngr 		gnupg 		wget 	; 	rm -rf /var/lib/apt/lists/*; 		wget -O openjdk.tgz.asc "$downloadUrl.sign"; 	wget -O openjdk.tgz "$downloadUrl" --progress=dot:giga; 		export GNUPGHOME="$(mktemp -d)"; 	gpg --batch --keyserver ha.pool.sks-keyservers.net --keyserver-options no-self-sigs-only --recv-keys CA5F11C6CE22644D42C6AC4492EF8D39DC13168F; 	gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys EAC843EBD3EFDB98CC772FADA5CD6035332FA671; 	gpg --batch --list-sigs --keyid-format 0xLONG CA5F11C6CE22644D42C6AC4492EF8D39DC13168F 		| tee /dev/stderr 		| grep '0xA5CD6035332FA671' 		| grep 'Andrew Haley'; 	gpg --batch --verify openjdk.tgz.asc openjdk.tgz; 	gpgconf --kill all; 	rm -rf "$GNUPGHOME"; 		mkdir -p "$JAVA_HOME"; 	tar --extract 		--file openjdk.tgz 		--directory "$JAVA_HOME" 		--strip-components 1 		--no-same-owner 	; 	rm openjdk.tgz*; 			apt-mark auto '.*' > /dev/null; 	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; 	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; 		{ 		echo '#!/usr/bin/env bash'; 		echo 'set -Eeuo pipefail'; 		echo 'if ! [ -d "$JAVA_HOME" ]; then echo >&2 "error: missing JAVA_HOME environment variable"; exit 1; fi'; 		echo 'cacertsFile=; for f in "$JAVA_HOME/lib/security/cacerts" "$JAVA_HOME/jre/lib/security/cacerts"; do if [ -e "$f" ]; then cacertsFile="$f"; break; fi; done'; 		echo 'if [ -z "$cacertsFile" ] || ! [ -f "$cacertsFile" ]; then echo >&2 "error: failed to find cacerts file in $JAVA_HOME"; exit 1; fi'; 		echo 'trust extract --overwrite --format=java-cacerts --filter=ca-anchors --purpose=server-auth "$cacertsFile"'; 	} > /etc/ca-certificates/update.d/docker-openjdk; 	chmod +x /etc/ca-certificates/update.d/docker-openjdk; 	/etc/ca-certificates/update.d/docker-openjdk; 		find "$JAVA_HOME/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; 	ldconfig; 		fileEncoding="$(echo 'System.out.println(System.getProperty("file.encoding"))' | jshell -s -)"; [ "$fileEncoding" = 'UTF-8' ]; rm -rf ~/.java; 	javac --version; 	java --version

#Print java home and version
RUN echo $JAVA_HOME
RUN java --version
ENV PATH=${PATH}:${KAFKA_HOME}/bin


COPY download-kafka.sh start-kafka.sh broker-list.sh create-topics.sh versions.sh /tmp/

RUN chmod a+x /tmp/*.sh \
 && mv /tmp/broker-list.sh /tmp/create-topics.sh /tmp/versions.sh /usr/bin \
 && mv /tmp/start-kafka.sh /app/startup.sh \
 && sync && /tmp/download-kafka.sh \
 && tar xfz /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -C /opt \
 && rm /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz \
 && ln -s /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} ${KAFKA_HOME} \
 && rm /tmp/download-kafka.sh 


RUN wget -O /tmp/zookeeper.tar.gz https://downloads.apache.org/zookeeper/zookeeper-${ZOOKEEPER_VERSION}/apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz \
  && tar -xzf /tmp/zookeeper.tar.gz -C /opt \
  && mv /opt/apache-zookeeper-${ZOOKEEPER_VERSION}-bin /opt/zookeeper

RUN mkdir -p /opt/prometheus/ \
  && curl https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.15.0/jmx_prometheus_javaagent-0.15.0.jar -o /opt/prometheus/jmx-exporter.jar

ADD prometheus_kafka.yml /opt/prometheus/

ENV KAFKA_OPTS='-javaagent:/opt/prometheus/jmx-exporter.jar=7071:/opt/prometheus/prometheus_kafka.yml'

COPY overrides /opt/overrides

COPY getfreebrokerid.sh /app/
RUN chmod +x /app/getfreebrokerid.sh

RUN chown -R -H -L edgeone:root $KAFKA_HOME

USER 1000
