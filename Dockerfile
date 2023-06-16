# replace with master-arm64 for ARM64
ARG IMAGE=focal-1.1.0

FROM phusion/baseimage:${IMAGE}

LABEL original="https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.8.0-linux-x86_64.tar.gz"
LABEL modifiedby="Sandeep Chaturvedi <sandeep.chaturvedi@forgerock.com>"
LABEL description="filebeat v8.8.0 docker image for ForgeRock Identity Cloud logs"

ENV FILEBEAT_VERSION=8.8.0 \
    FILEBEAT_SHA1=301799568893c5812e8cf03b71e1dc9d8bace23aa0dcc0b7aa8a54507493498ddc3360718bd41b96f7da7a9e38aec042ca16d5eaeaac11e44ba7c9dca775c4b1

RUN set -x && \
  apt-get update && \
  apt-get install -y wget curl vim nmap net-tools && \
  wget https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${FILEBEAT_VERSION}-linux-x86_64.tar.gz -O /opt/filebeat.tar.gz && \
  cd /opt && \
  echo "${FILEBEAT_SHA1} filebeat.tar.gz" | sha512sum -c - && \
  tar xzvf filebeat.tar.gz && \
#   cd filebeat-${FILEBEAT_VERSION}-linux-x86_64 && \
#   cp filebeat /bin && \
  cd /opt && \
  mv filebeat-${FILEBEAT_VERSION}-linux-x86_64 filebeat && \
#   rm -rf filebeat* && \
  apt-get purge -y wget && \
  apt-get autoremove -y && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD [ "/opt/filebeat/filebeat", "-e", "-c", "/opt/filebeat/filebeat.yml" ]
