#!/bin/bash

echo $USER

/usr/local/bin/consul-template -consul-addr consul-server:8500 \
  -template "/tmp/haproxy.cfg.ctmpl:/etc/haproxy/haproxy.cfg:/haproxy.sh"