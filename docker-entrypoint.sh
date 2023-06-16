#!/bin/bash

# This creates filebeat configuration file based on environment variables

# set -x
# set -e

# These are the env vars
# FIDC_ORIGIN
# FIDC_API_KEY_ID
# FIDC_API_KEY_SECRET
# FIDC_LOG_SOURCE
# FIDC_LOG_START_TIME
# FIDC_LOG_END_TIME
# FIDC_PULL_INTERVAL
# FIDC_LOG_REQUEST_TIMEOUT

cd /opt/filebeat

TEMPLATE_FILE="filebeat.yml.template"
CONFIG_FILE="filebeat.yml"

if [[ -z "${FIDC_LOG_START_TIME}" ]]; then
cat >$TEMPLATE_FILE <<EOF
filebeat.inputs:
- type: httpjson
  interval: ##FIDC_PULL_INTERVAL##
  config_version: 2
  request:
    timeout: ##FIDC_LOG_REQUEST_TIMEOUT##
    url: ##ORIGIN##/monitoring/logs/tail
    transforms:
      - set:
          target: url.params.source
          value: '##LOG_SOURCE##'
      - set:
          target: header.x-api-key
          value: '##API_KEY_ID##'
      - set:
          target: header.x-api-secret
          value: '##API_KEY_SECRET##'	          
EOF
else
cat >$TEMPLATE_FILE <<EOF
filebeat.inputs:
- type: httpjson
  interval: ##FIDC_PULL_INTERVAL##
  config_version: 2
  auth.basic:
    user: ##API_KEY_ID##
    password: ##API_KEY_SECRET##
  request:
    timeout: ##FIDC_LOG_REQUEST_TIMEOUT##
    url: ##ORIGIN##/monitoring/logs
    transforms:
      - set:
          target: url.params.source
          value: '##LOG_SOURCE##'
      - set:
          target: url.params.beginTime
          value: '##LOG_START_TIME##'
EOF
if [[ ! -z "${FIDC_LOG_END_TIME}" ]]; then
cat >>$TEMPLATE_FILE <<EOF
      - set:
          target: url.params.endTime
          value: '##LOG_END_TIME##'
EOF
fi
fi

cat >>$TEMPLATE_FILE <<EOF
      - set:
          target: url.params._pagedResultsCookie
          value: '[[.last_response.body.pagedResultsCookie]]'
    rate_limit:
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
  - timestamp:
      field: timestamp
      ignore_failure: false
      layouts:
        - '2006-01-02T15:04:05.999999999Z'
      test:
        - '2021-03-16T16:39:40.410894588Z'
  - drop_fields:
      fields: ["timestamp"]
  - if:
      contains:
        type: "text"
    then:
      - rename:
          fields:
            - from: "payload"
              to: "text_payload"
            - from: "source"
              to: "fidc_source"
          ignore_missing: false
          fail_on_error: true
    else:
      - drop_event:
          when:
            equals:
              payload.userId: "id=amadmin,ou=user,ou=am-config"
      - extract_array:
          when:
            has_fields: ['payload.http.request.headers.x-forwarded-for']
          field: payload.http.request.headers.x-forwarded-for
          fail_on_error: false
          ignore_missing: true
          mappings:
            payload.http.request.headers.x-forwarded-for-extracted: 0
      - dissect:
          when:
            has_fields: ['payload.http.request.headers.x-forwarded-for-extracted']
          tokenizer: "%{payload.http.request.client_ip}, %{ip2}, %{ip3}"
          field: "payload.http.request.headers.x-forwarded-for-extracted"
          target_prefix: ""
          ignore_failure: true
          trim_values: all
      - extract_array:
          when:
            has_fields: ['payload.http.request.headers.user-agent']
          field: payload.http.request.headers.user-agent
          fail_on_error: false
          ignore_missing: true
          mappings:
            payload.http.request.headers.user-agent-extracted: 0
      - drop_fields:
          fields: ["ip2", "ip3", "payload.http.request.headers.x-forwarded-for", "payload.http.request.headers.user-agent"]
          ignore_missing: true
      - rename:
          fields:
              - from: "payload.response.detail"
                to: "payload.response.message"
          ignore_missing: true
          fail_on_error: false
      - rename:
          fields:
            - from: "payload"
              to: "json_payload"
            - from: "source"
              to: "fidc_source"
          ignore_missing: false
          fail_on_error: true
output.elasticsearch:
  hosts: ["http://elk:9200"]
  pipeline: geoip-and-useragent
  allow_older_versions: true
setup.template:
  type: "index"
  append_fields:
    - name: json_payload
      type: object
    - name: text_payload
      type: text
    - name: geoip.location
      type: geo_point
EOF

# set values in config file from env vars
sed \
    -e "s@##FIDC_LOG_REQUEST_TIMEOUT##@${FIDC_LOG_REQUEST_TIMEOUT:-1m}@g" \
    -e "s@##FIDC_PULL_INTERVAL##@${FIDC_PULL_INTERVAL:-10s}@g" \
    -e "s@##ORIGIN##@$FIDC_ORIGIN@g" \
    -e "s@##API_KEY_ID##@$FIDC_API_KEY_ID@g" \
    -e "s@##API_KEY_SECRET##@$FIDC_API_KEY_SECRET@g" \
    -e "s@##LOG_SOURCE##@$FIDC_LOG_SOURCE@g" \
    -e "s@##LOG_START_TIME##@$FIDC_LOG_START_TIME@g" \
    -e "s@##LOG_END_TIME##@$FIDC_LOG_END_TIME@g" \
    $TEMPLATE_FILE >$CONFIG_FILE

#./filebeat -e -c $CONFIG_FILE
#rm -f $CONFIG_FILE

# wait for Kibana
if [ -z "$KIBANA_URL" ]; then
    KIBANA_URL=http://elk:5601
fi
counter=0
echo "Will wait for 60s for Kibana to start ..."
while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' ${KIBANA_URL}/api/status)" != "200" && $counter -lt 180 ]]; do
    sleep 1
    ((counter++))
    echo "waiting for Kibana to respond ($counter/180)"
done
if [[ "$(curl -s -o /dev/null -w ''%{http_code}'' ${KIBANA_URL}/api/status)" != "200" ]]; then
    echo "Timed out waiting for Kibana to respond. Exiting."
    exit 1
fi

# Add filebeat as command if needed
if [ "${1:0:1}" = '-' ]; then
	set -- filebeat "$@"
fi

exec "$@"