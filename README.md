# mb-socket

[![Docker](https://img.shields.io/badge/docker-ready-brightgreen.svg)](https://hub.docker.com/r/edgepro/mb-mqtt)
[![GoDoc](https://godoc.org/github.com/taka-wang/mb-socket?status.svg)](http://godoc.org/github.com/taka-wang/mb-socket)
[![Go Report Card](https://goreportcard.com/badge/github.com/taka-wang/mb-socket?)](https://goreportcard.com/report/github.com/taka-wang/mb-socket)

MQTT service and Websocket for psmb

## Continuous Integration

I do continuous integration and build docker images after git push by self-hosted [drone.io](http://armdrone.cmwang.net) server for armhf platform , [circleci](http://circleci.com) server for x86 platform and [dockerhub](https://hub.docker.com/r/edgepro/mb-mqtt) service.

| CI Server| Target    | Status                                                                                                                                                                     |
|----------|-----------|----------------------------------------------------------------------------------------------------------------------------------|
| Travis   | x86       | [![Build Status](https://travis-ci.org/taka-wang/mb-socket.svg?branch=master)](https://travis-ci.org/taka-wang/mb-socket)|
| CircleCI | x86       | [![CircleCI](https://circleci.com/gh/taka-wang/mb-socket.svg?style=shield)](https://circleci.com/gh/taka-wang/mb-socket)               |
| Drone    | armhf     | [![Build Status](http://armdrone.cmwang.net/api/badges/taka-wang/mb-socket/status.svg)](http://armdrone.cmwang.net/taka-wang/mb-socket)|

## Environment variables

> Why environment variable? Refer to the [12 factors](http://12factor.net/)

- CONF_SOCKET: config file path
- EP_BACKEND: endpoint of remote service discovery server (optional)


## Design principles

- [Separation of concerns](https://en.wikipedia.org/wiki/Separation_of_concerns) - I separate config, route and worker functions to respective packages, link route and worker services by go channels.
- [API-First Design](http://www.api-first.com/)
- [Microservice Design](https://en.wikipedia.org/wiki/Microservices)
- [Object-oriented Design](https://en.wikipedia.org/wiki/Object-oriented_design)
- [12-Factor App Design](http://12factor.net/)


## Documents

- [MQTT API](docs/mqtt.md)

---

## License

MIT
