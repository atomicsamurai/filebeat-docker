#!/bin/bash

# This creates filebeat configuration file based on environment variables

# set -x
set -e

# if [[ $# -ne 2 ]]; then
#     echo "Run filebeat for ForgeRock ID Cloud"
#     echo "Usage: $0 <env file name> <comma separaeted sources>"
#     exit 1
# fi
# ENVFILE=$1
# LOG_SOURCES=$2

# get the directory where this script is
# DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DIR=/

# DATE=$(date '+%Y%m%d%H%M%S')

cd ${DIR}

TEMPLATE_FILE="filebeat.yml.template"
CONFIG_FILE="filebeat.yml"
/bin/cat <<EOM >$TEMPLATE_FILE
- type: httpjson
  config_version: 2
  request.url: ##ORIGIN##/monitoring/logs/tail
  request.transforms:
    - set:
        target: header.Authorization
        value: 'Basic ##CREDENTIALS##'
    - set:
        target: url.params.source
        value: '##LOG_SOURCE##'
    - set:
        target: url.params._pagedResultsCookie
        value: '[[.last_response.body.pagedResultsCookie]]'
  request.rate_limit:
    limit: '[[.last_response.header.Get "x-ratelimit-limit"]]'
    remaining: '[[.last_response.header.Get "x-ratelimit-remaining"]]'
    reset: '[[.last_response.header.Get "x-ratelimit-reset"]]'
  response.split:
    target: body.result
    type: array
EOM

echo "filebeat.inputs:" >$CONFIG_FILE # this starts a new CONFIG_FILE

# source ${ENVFILE}
CREDENTIALS=$(echo -n "${API_KEY_ID}:${API_KEY_SECRET}" | base64 -w 0)

for LOG_SOURCE in $(echo $LOG_SOURCES | sed "s/,/ /g"); do
    echo "$LOG_SOURCE"
    sed -e "s@##ORIGIN##@$ORIGIN@g" -e "s@##CREDENTIALS##@$CREDENTIALS@g" -e "s@##LOG_SOURCE##@$LOG_SOURCE@g" $TEMPLATE_FILE >>filebeat.yml
done

echo "output.logstash:" >>$CONFIG_FILE
echo "  hosts: ["elk:5044"]" >>$CONFIG_FILE # elk is the service name for elk docker container in docker-compose

#./filebeat -e -c $CONFIG_FILE
#rm -f $CONFIG_FILE

# Add filebeat as command if needed
if [ "${1:0:1}" = '-' ]; then
	set -- filebeat "$@"
fi

exec "$@"