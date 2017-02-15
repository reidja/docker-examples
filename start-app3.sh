#!/bin/bash

set -e

docker kill appserver3 &> /dev/null || true
docker rm appserver3 &> /dev/null || true
docker run -d \
    --hostname=appserver3 \
    --network=jason \
    --name=appserver3 \
    -e "SERVICE_NAME=appserver" \
   	--log-driver=gelf \
	--log-opt gelf-address=udp://127.0.0.1:12201 \
	--log-opt tag="appserver3" \
    -p 8001 \
    app-server