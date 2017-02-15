#!/bin/bash


if [ "$1" == "--destroy-volumes" ]; then
    echo "Destroying persistent volumes"
    docker volume rm postgres-data
    exit 0
fi

if [ "$1" == "--build-images" ]; then
    echo "Rebuilding container images"
    docker build -f containers/haproxy.Dockerfile -t haproxy .
    docker build -f containers/app.Dockerfile -t app-server .
    exit 0
fi

echo "Stopping and removing ALL existing containers"
docker kill $(docker ps -q) &> /dev/null || true
docker rm $(docker ps -a -q) &> /dev/null || true

echo "Setting up virtual network"
docker network rm jason &> /dev/null || true
docker network create jason &> /dev/null

source config.sh

echo "Launching elasticsearch"
docker run -d \
    --hostname=elasticsearch \
    --network=jason \
    --name=elasticsearch \
    -e "ES_JAVA_OPTS=-Xms128m -Xmx256m" \
    elasticsearch:alpine

echo "Launching kibana"
docker run -d \
    --hostname=kibana \
    --network=jason \
    --name=kibana \
    -p 5601:5601 \
    -e "ELASTIC_SEARCH_URL=http://elasticsearch:9200" \
    kibana

echo "Launching logstash"
docker run -d \
    --hostname=logstash \
    --network=jason \
    --name=logstash \
    --volume=$(pwd)/config/logstash/logstash.conf:/config-dir/logstash.conf \
    -p 12201:12201/udp \
    logstash logstash -f /config-dir/logstash.conf

echo "Waiting 10s for logstash and elasticsearch"
sleep 10

echo "Launching consul server"
docker run -d \
    --hostname=consul-server \
    --network=jason \
    --log-driver=gelf \
    --log-opt gelf-address=udp://127.0.0.1:12201 \
    --log-opt tag="consul-server" \
    --volume=$(pwd)/config/consul.d:/consul/config \
    --name=consul-server \
    -p 8500 \
    consul consul agent -config-dir=/consul/config -dev -ui -client=0.0.0.0 -bind=0.0.0.0

echo "Waiting 5s for consul"
sleep 5

docker exec -it consul-server consul members

echo "Launching registrator"
docker run -d \
    --hostname=registrator \
    --name=registrator \
    --network=jason \
    --log-driver=gelf \
    --log-opt gelf-address=udp://127.0.0.1:12201 \
    --log-opt tag="registrator" \
    --volume=/var/run/docker.sock:/tmp/docker.sock \
    gliderlabs/registrator:latest consul://consul-server:8500

 echo "Launching nomad"
 docker run -d \
     --hostname=nomad-server \
     --network=jason \
     --name=nomad-server \
     --log-driver=gelf \
     --log-opt gelf-address=udp://127.0.0.1:12201 \
     --log-opt tag="nomad-server" \
     --volume=/var/run/docker.sock:/var/run/docker.sock \
     vancluever/nomad

echo "Launching redis"
docker run -d \
    --hostname=redis \
    --network=jason \
    --name redis \
    --log-driver=gelf \
    --log-opt gelf-address=udp://127.0.0.1:12201 \
    --log-opt tag="redis" \
    -p 6379 \
    redis

docker volume inspect postgres-data &> /dev/null
RET=$?
HAD_VOLUME=0
if [ $RET -ne 0 ]; then
    echo "Creating postgres-data volume"
    docker volume create --name postgres-data &> /dev/null
    HAD_VOLUME=0
else
    HAD_VOLUME=1
fi

echo "Launching PostgreSQL"
docker run -d \
    --hostname=postgres \
    --network=jason \
    --name postgres \
    --log-driver=gelf \
    --log-opt gelf-address=udp://127.0.0.1:12201 \
    --log-opt tag="postgres" \
    --volume=postgres-data:/var/lib/postgresql/data \
    -p 5432 \
    -e POSTGRES_PASSWORD=secret \
    -e POSTGRES_USER=sentry \
    postgres

echo "Waiting 10s for PostgreSQL to initialize"
sleep 10

if [ "$1" != "--nosentry" ]; then
    if [ $HAD_VOLUME -eq 0 ]; then
        echo "Migrating Sentry"
        docker run \
            --rm \
            --hostname=sentry-upgrade \
            --network=jason \
            -it \
            --log-driver=gelf \
            --log-opt gelf-address=udp://127.0.0.1:12201 \
            --log-opt tag="sentry-upgrade" \
            -e REDIS_PORT_6379_TCP_ADDR=redis \
            -e SENTRY_POSTGRES_HOST=postgres \
            -e SENTRY_DB_USER=sentry \
            -e SENTRY_DB_PASSWORD=secret \
            -p 9000:9000 \
            --name sentry-upgrade \
            -e SENTRY_SECRET_KEY='key' \
            sentry upgrade
    fi

    echo "Launching Sentry"
    docker run -d \
        --hostname=sentry-server \
        --network=jason \
        --log-driver=gelf \
        --log-opt gelf-address=udp://127.0.0.1:12201 \
        --log-opt tag="sentry-server" \
        -e REDIS_PORT_6379_TCP_ADDR=redis \
        -e SENTRY_POSTGRES_HOST=postgres \
        -e SENTRY_DB_PASSWORD=secret \
        -e SENTRY_DB_USER=sentry \
        -p 9000:9000 \
        --name sentry-server  -e SENTRY_SECRET_KEY='key' sentry

    echo "Launching Sentry Cron"
    docker run -d \
        --hostname=sentry-cron \
        --network=jason \
        --log-driver=gelf \
        --log-opt gelf-address=udp://127.0.0.1:12201 \
        --log-opt tag="sentry-cron" \
        -e REDIS_PORT_6379_TCP_ADDR=redis \
        -e SENTRY_POSTGRES_HOST=postgres \
        -e SENTRY_DB_PASSWORD=secret \
        -e SENTRY_DB_USER=sentry \
        -e SENTRY_SECRET_KEY='key' \
        --name=sentry-cron \
        sentry run cron

    echo "Launching Sentry Worker"
    docker run -d \
        --hostname=sentry-worker1 \
        --network=jason \
        --log-driver=gelf \
        --log-opt gelf-address=udp://127.0.0.1:12201 \
        --log-opt tag="sentry-worker1" \
        -e REDIS_PORT_6379_TCP_ADDR=redis \
        -e SENTRY_POSTGRES_HOST=postgres \
        -e SENTRY_DB_PASSWORD=secret \
        -e SENTRY_DB_USER=sentry \
        -e SENTRY_SECRET_KEY='key' \
        --name=sentry-worker1 \
        sentry run worker

    echo "Provide Sentry URL (replace localhost):"
    read SENTRY_URL
    echo "Key: $SENTRY_URL"
else
    SENTRY_URL=""
fi

echo "Launching app servers"
docker run -d \
    --hostname=appserver1 \
    --network=jason \
    --name=appserver1 \
    -e "SERVICE_NAME=appserver" \
    -e "SENTRY_URL=$SENTRY_URL" \
    -e "DATADOG_API_KEY=$DATADOG_API_KEY" \
    -e "DATADOG_APP_KEY=$DATADOG_APP_KEY" \
    --log-driver=gelf \
    --log-opt gelf-address=udp://127.0.0.1:12201 \
    --log-opt tag="appserver1" \
    -p 8001 \
    app-server
docker run -d \
    --hostname=appserver2 \
    --network=jason \
    --name=appserver2 \
    -e "SERVICE_NAME=appserver" \
    -e "SENTRY_URL=$SENTRY_URL" \
    -e "DATADOG_API_KEY=$DATADOG_API_KEY" \
    -e "DATADOG_APP_KEY=$DATADOG_APP_KEY" \
    --log-driver=gelf \
    --log-opt gelf-address=udp://127.0.0.1:12201 \
    --log-opt tag="appserver2" \
    -p 8001 \
    app-server

echo "Launching haproxy"
docker run -d \
    --hostname=proxy \
    --network=jason \
    -e "SERVICE_NAME=proxy" \
    --volume=$(pwd)/config/consul-template/templates/haproxy.cfg.ctmpl:/tmp/haproxy.cfg.ctmpl \
    -p 8000:8080 \
    --log-driver=gelf \
    --log-opt gelf-address=udp://127.0.0.1:12201 \
    --log-opt tag="proxy" \
    --name=proxy \
    haproxy

echo "Launching Data Dog"
docker run -d \
    --hostname=datadog \
    --name=datadog \
    --network=jason \
    --log-driver=gelf \
    --log-opt gelf-address=udp://127.0.0.1:12201 \
    --log-opt tag="datadog" \
    --volume=/var/run/docker.sock:/var/run/docker.sock:ro \
    --volume=/proc/:/host/proc/:ro \
    --volume=/sys/fs/cgroup/:/host/sys/fs/cgroup:ro \
    -e API_KEY=$DATADOG_API_KEY \
    -e SD_CONFIG_BACKEND=consul \
    -e SD_BACKEND_HOST=consul-server \
    -e SD_BACKEND_PORT=8500 \
    datadog/docker-dd-agent:latest

docker ps