### Changelog:

# filebeat for ForgeRock Identity Cloud (FIDC)
This repository contains sample filebeat configurations for use with ForgeRock ID Cloud. You can also create a docker image with the provided `Dockerfile` and run it in docker as explained below.

## Run standalone
1. Download and unzip [filebeat](https://www.elastic.co/downloads/beats/filebeat) (for example, to `/opt/filebeat`)
2. Modify one of the filebeat sample configurations with your tenant details (URL, API key/secret), and other parameters if needed (save it to, for example, `/opt/filebeat/filebeat.yml`). There are two samples:
    a. `filebeat-tail-sample.yml`: this "tails" the logs
    b. `filebeat-timeperiod-sample.yml`: this will get logs between a set `beginTime` and `endTime`. You will need to update these in the sample yml to your desired values.
3. Run filebeat with this configuration
```
$ /opt/filebeat/filebeat -e -c /opt/filebeat/filebeat.yml
```
The ID Cloud logs will be dumped on stdout.

## Run in docker

### Prerequisites
Install docker and docker-compose on your machine.

### Running
1. First, export environment variables to point to a ID Cloud tenant. Best practice is to create separate env files specific to each environment. An example `.env.customername` file could be:
```
export FIDC_ORIGIN="https://<tenant url>"
export FIDC_API_KEY_ID="67xxxxxxxxxxxxxxxxxxxxxxxxxxx221"
export FIDC_API_KEY_SECRET="acxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxd6"
export FIDC_LOG_SOURCE="idm-sync,am-access,am-authentication,idm-core,am-core"
export FIDC_LOG_START_TIME="2021-03-10T00:00:00Z" # optional: only needed when pulling historical logs (not tailing)
export FIDC_LOG_END_TIME="2021-03-10T12:00:00Z"   # optional: only needed when pulling historical logs (not tailing)
export FIDC_PULL_INTERVAL="10s"                   # optional: default 10s (this is only used when FIDC_LOG_START_TIME is used)
export FIDC_LOG_REQUEST_TIMEOUT="1m"              # optional: default 1m
```

Or, download [env-sample](https://raw.githubusercontent.com/atomicsamurai/filebeat-docker/main/env-sample)

---
** NOTE **

If `FIDC_LOG_START_TIME` is set, filebeat will not "tail" the logs, instead it will start pulling logs from the specified instance in past. You can also optionally specify `FIDC_LOG_END_TIME` (along with `FIDC_LOG_START_TIME`). If only `FIDC_LOG_START_TIME` is specified, it will pull all logs from that time to present time. If you need to tail as well as pull historical logs, you can start a separate filebeat container without the `FIDC_LOG_START_TIME` variable set. How to do that is not covered in this doc.

---

`LOG_SOURCE` can be a comma separated list of any of the following:
```
am-access
am-activity
am-authentication
am-config
am-core
am-everything
ctsstore
ctsstore-access
ctsstore-config-audit
ctsstore-upgrade
idm-access
idm-activity
idm-authentication
idm-config
idm-core
idm-everything
idm-sync
userstore
userstore-access
userstore-config-audit
userstore-ldif-importer
userstore-upgrade
```
Beware that for every item in the comma separated list, filebeat will make a separate request (using a separate httpjson input). With a large list, one can easily overwhelm the GCP API quotas.

2. Source the environment file

```
$ source .env.tenantname
```

3. To run the ELK container, use the following code to create a docker-compose.yml on your machine.
```
version: '3.7'
services:
  filebeat:
    image: sandeepc0/filebeat-fidc:standalone
    container_name: filebeat-forgerock-idcloud
    environment:
      - FIDC_ORIGIN
      - FIDC_API_KEY_ID
      - FIDC_API_KEY_SECRET
      - FIDC_LOG_SOURCE
      - FIDC_LOG_START_TIME         # optional: only needed when pulling historical logs (not tailing)
      - FIDC_LOG_END_TIME           # optional: only needed when pulling historical logs (not tailing)
      - FIDC_PULL_INTERVAL          # optional: default 10s (this is only used when FIDC_LOG_START_TIME is used)
      - FIDC_LOG_REQUEST_TIMEOUT    # optional: default 1m
```

Or, download [docker-compose.yml](https://raw.githubusercontent.com/atomicsamurai/filebeat-docker/main/docker-compose.yml)

4. Then, to start the container, from the directory where the above downloaded `docker-compose.yml` is, run the following to start the stack.
```
$ docker-compose up -d
```
You can also run `docker-compose -p <project name> up -d` to manage as a docker-compose project

5. The ForgeRock ID Cloud logs are dumped on the container's stdout by default. You can view those with `docker logs ....`

