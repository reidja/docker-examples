#!/bin/bash

set -e

docker kill appserver3 &> /dev/null || true
docker rm appserver3 &> /dev/null || true