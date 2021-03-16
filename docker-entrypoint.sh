#!/bin/bash

# This creates filebeat configuration file based on environment variables

set -x
# set -e

cd /opt/filebeat

TEMPLATE_FILE="filebeat.yml.template"
CONFIG_FILE="filebeat.yml"
cat >$TEMPLATE_FILE <<EOF
filebeat.inputs:
- type: httpjson
  config_version: 2
  request.url: ##ORIGIN##/monitoring/logs/tail
  auth.basic:
    user: ##API_KEY_ID##
    password: ##API_KEY_SECRET##
  request.transforms:
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
    transforms:
      - set:
          target: body.tenant
          value: '##ORIGIN##'
processors:
  - decode_json_fields:
      fields: ["message"]
      process_array: true
      max_depth: 5
      target: ""
      overwrite_keys: true
      add_error_key: true
  - if:
      contains:
        type: "json"
    then:
      - rename:
          fields:
            - from: "payload"
              to: "json_payload"
          ignore_missing: false
          fail_on_error: true
    else:
      - rename:
          fields:
            - from: "payload"
              to: "text_payload"
          ignore_missing: false
          fail_on_error: true
output.elasticsearch:
  hosts: ["http://elk:9200"]
setup.template:
  type: "index"
  append_fields:
    - name: json_payload
      type: object
    - name: text_payload
      type: text
EOF

# set values in config file from env vars
sed \
    -e "s@##ORIGIN##@$ORIGIN@g" \
    -e "s@##API_KEY_ID##@$API_KEY_ID@g" \
    -e "s@##API_KEY_SECRET##@$API_KEY_SECRET@g" \
    -e "s@##LOG_SOURCE##@$LOG_SOURCE@g" \
    $TEMPLATE_FILE >>$CONFIG_FILE

#./filebeat -e -c $CONFIG_FILE
#rm -f $CONFIG_FILE

# Add filebeat as command if needed
if [ "${1:0:1}" = '-' ]; then
	set -- filebeat "$@"
fi

exec "$@"