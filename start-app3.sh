#!/bin/bash

set -e

docker kill appserver3 &> /dev/null || true
docker rm appserver3 &> /dev/null || true
docker run  \
    --rm \
    --hostname=appserver3 \
    --network=jason \
    --name=appserver3 \
    -e "SERVICE_NAME=appserver" \
    -e "SENTRY_URL=http://3250148905644605b078c2ae2f916b38:8293b8dbbcb0432eadb1f23ccc01060d@sentry-server:9000/2" \
   	--log-driver=gelf \
	--log-opt gelf-address=udp://127.0.0.1:12201 \
	--log-opt tag="appserver3" \
    -p 8001 \
    app-server