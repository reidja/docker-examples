#!/bin/bash

set -e

function getIP() {
	name=$1
	echo $(docker inspect --format '{{ .NetworkSettings.Networks.jason.IPAddress }}' $name)
}

CWD=$(pwd)
echo "Stopping and removing old containers"
docker build -f containers/haproxy.Dockerfile -t haproxy .
docker kill $(docker ps -q) &> /dev/null || true
docker rm $(docker ps -a -q) &> /dev/null || true
docker network rm jason &> /dev/null || true
docker network create jason &> /dev/null
echo "Launching consul server"
docker run -d \
	--hostname=consul-server \
	--network=jason \
	--volume=$CWD/config/consul.d:/consul/config \
	-p 8500:8500 \
	--name=consul-server \
	consul consul agent -config-dir=/consul/config -dev -ui -client=0.0.0.0 -bind=0.0.0.0
sleep 2
docker exec -it consul-server consul members
echo "Launching registrator"
docker run -d \
	--hostname=registrator \
	--name=registrator \
	--network=jason \
	--volume=/var/run/docker.sock:/tmp/docker.sock \
	gliderlabs/registrator:latest consul://consul-server:8500
echo "Launching nomad"
docker run -d \
	--hostname=nomad-server \
	--network=jason \
	--volume=/var/run/docker.sock:/var/run/docker.sock \
	vancluever/nomad
echo "Launching helloworld app"
docker run -d \
    --hostname=helloworld1 \
    --network=jason \
    --name=helloworld1 \
    -e "SERVICE_NAME=helloworld" \
    -p 3000 \
    fabriziopandini/hello-hostname
docker run -d \
    --hostname=helloworld2 \
    --network=jason \
    --name=helloworld2 \
    -e "SERVICE_NAME=helloworld" \
    -p 3000 \
    fabriziopandini/hello-hostname
echo "Launching haproxy"
docker run \
	--hostname=proxy \
	--network=jason \
	--volume=$(pwd)/config/consul-template/templates/haproxy.cfg.ctmpl:/tmp/haproxy.cfg.ctmpl \
	-p 8000:8080 \
	--name=proxy haproxy