FROM debian:jessie

LABEL original="https://github.com/primait/docker-filebeat"
LABEL modifiedby="Sandeep Chaturvedi <sandeep.chaturvedi@forgerock.com>"
LABEL description="filebeat docker image for ForgeRock Identity Cloud logs"

ENV FILEBEAT_VERSION=7.11.1 \
    FILEBEAT_SHA1=3b12c7208707e627bc26964b1b07702bc788961e63f0187830dd5cd6dc9120178f29d04b42c5ff2ede44cc0810e6a592eb93736513af5d2dca92379334b51655

RUN set -x && \
  apt-get update && \
  apt-get install -y wget && \
  wget https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${FILEBEAT_VERSION}-linux-x86_64.tar.gz -O /opt/filebeat.tar.gz && \
  cd /opt && \
  echo "${FILEBEAT_SHA1} filebeat.tar.gz" | sha512sum -c - && \
  tar xzvf filebeat.tar.gz && \
  cd filebeat-* && \
  cp filebeat /bin && \
  cd /opt && \
  rm -rf filebeat* && \
  apt-get purge -y wget && \
  apt-get autoremove -y && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD [ "filebeat", "-e", "-c", "/filebeat.yml" ]
