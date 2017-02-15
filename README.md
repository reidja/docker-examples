# docker-examples

## Requirements

* docker
* bash

## Getting Started

```
./start.sh
```

You will be prompted for a Sentry URL. You will need to set-up Sentry (http://localhost:5000), create a project and paste the API url (modify hostname to `sentry-server` not localhost) into the prompt.

```
./start-app3.sh
```

This will start an appserver container (not daemonized) which will add a third `appserver` node (appserver3). If you continually refresh http://localhost:8000 you will be able to see it rotate between all three. If you stop appserver3 you will not see any errors (and you can start it again to have it back in the pool).

# Information 

This command will bring up the following docker containers:
  - Consul (Service discovery)
  - Nomad (Container scheduler [TODO])
  - Registrator (Container service discovery)
  - Elasticsearch/Kibana/Logstash (Logging)
  - PostgreSQL (Relational database)
  - Redis (Pub/sub)
  - Sentry (Application monitoring)
  - Application servers (Application)
  - Dynamically configured proxy (Load balancer)

## Service Discovery

Consul is a key value store with a nice API surrounding it allowing qurom, distributed locks, and service discovery. 

The `registrator` container monitors the docker engine on the host for changes in container status (ex: start/stop). It will automatically register these with the consul servers which allows for dynamic querying of services (see Proxy below).
  
## Network

All containers are started in a custom bridged docker network and are assigned DHCP addresses at random.

Containers are linked together through a DNS server and queryable through consul registry or by direct hostname.

## Logging

All containers are launched with `gelf` docker logging adapter which streams the containers stdout/stderr to `logstash`. 

Logstash streams the logs to `elasticsearch.`

Elasticsearch is a clusterable search engine for log like data.

Kibana is a web interface for viewing and querying `elasticsearch`.

Kibana is accessible at http://localhost:5601.

## Monitoring

Consul is uses `registrator` to monitor the docker engine for containers. It then updates consul with this information.

Consul can then have checks registered against services. For example the proxy is monitored by an HTTP check that ensures "Hello World" is in the body response.

Consul UI is available at http://localhost:8500/ui.

## Application Level

The application is monitored by having exceptions trapped by flask at the application level. The `raven` package is used to stream exception handling
information to a sentry server.

Sentry is a Django app that provides application monitoring. It requires `redis` and `postgresql` to operate.

Sentry is available at http://localhost:5000.

## Proxy

The proxy service will automatically detect `appserver` containers, add them to the haproxy configuration and signal the haproxy process to reload its configuration.

This allows autoscaling or load balancing in a very simple manner and can be used for any kind of `tcp`, `ip`, or `http` service end point.
