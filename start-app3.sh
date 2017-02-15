#!/bin/bash

set -e

source config.sh

docker kill appserver3 &> /dev/null || true
docker rm appserver3 &> /dev/null || true

echo "Provide Sentry URL (replace localhost):"
read SENTRY_URL
echo "Key: $SENTRY_URL"


docker run  \
    --rm \
    --hostname=appserver3 \
    --network=jason \
    --name=appserver3 \
    -e "SERVICE_NAME=appserver" \
    -e "SENTRY_URL=$SENTRY_URL" \
    -e "DATADOG_API_KEY=$DATADOG_API_KEY" \
    -e "DATADOG_APP_KEY=$DATADOG_APP_KEY" \
   	--log-driver=gelf \
	--log-opt gelf-address=udp://127.0.0.1:12201 \
	--log-opt tag="appserver3" \
    -p 8001 \
    app-server