#!/bin/bash

set -e

docker kill $(docker ps -q) &> /dev/null || true
docker rm $(docker ps -a -q) &> /dev/null || true
docker network rm jason &> /dev/null || true