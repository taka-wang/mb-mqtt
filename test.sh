#!/bin/bash

#mosquitto_pub -d -h iot.eclipse.org -i 1564 -t mydevice01/mbtcp/once.read/pub/1234512132 -m '{"fc": 1,"ip": "172.18.0.1","port": "502","slave": 1,"addr": 10,"data": 2}'

SLAVE=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' mbsocket_slave_1)
mosquitto_pub -d -h iot.eclipse.org -i 1564 -t mydevice01/mbtcp/once.read/pub/1234512144 -m '{"fc": 1, "ip": "'"$SLAVE"'", "port": "502", "slave": 1, "addr": 10, "data": 2}'
