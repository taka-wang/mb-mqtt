#!/bin/bash

#################################################
# MQTT API Tester
#
# Author: Taka Wang
# Date: 2016/10/05
#################################################

## Variable
SLAVE=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' mbsocket_slave_1)
#URL=iot.eclipse.org
URL=aws.cmwang.net
#mosquitto_pub -d -h iot.eclipse.org -i 1564 -t mydevice01/mbtcp/once.read/pub/1234512144 -m '{"fc": 1, "ip": "'"$SLAVE"'", "port": "502", "slave": 1, "addr": 10, "data": 2}'

# color code ---------------
COLOR_REST='\e[0m'
COLOR_GREEN='\e[1;32m';
COLOR_RED='\e[1;31m';


## Unit-Testable Shell Scripts (http://eradman.com/posts/ut-shell-scripts.html)
typeset -i tests_run=0
typeset -i fail_run=0
function try { 
    this="$1"
    if [ "$(uname)" == "Darwin" ]; then
        echo "### " $this    
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        echo -e "${COLOR_RED}### $this${COLOR_REST}"
    fi
}
trap 'printf "$0: exit code $? on line $LINENO\nFAIL: $this\n"; exit 1' ERR
function assert {
    let tests_run+=1
    [ "$1" = "$2" ] && { echo -n "."; return; }
    printf "\nFAIL: $this\n'$1' != '$2'\n"; exit 1
}
function check_ok_status {
    let tests_run+=1
    echo "resp:" $out
    [[ "$1" == *'"status":"ok"'* ]] && { echo "---------------------------------"; return; }
    printf "@@@FAIL: '$1'\n"; let fail_run+=1; echo "---------------------------------";
}
function check_not_ok_status {
    let tests_run+=1
    echo "resp:" $out
    [[ "$1" != *'"status":"ok"'* ]] && { echo "---------------------------------"; return; }
    printf "@@@FAIL: '$1'\n"; let fail_run+=1; echo "---------------------------------";
}
function set_title {
    if [ "$(uname)" == "Darwin" ]; then
        echo "========== $1 =========="
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        echo -e "${COLOR_GREEN}========== $1 ==========${COLOR_REST}"
    fi
}
function subscribe {
    out=$(mosquitto_sub -h $URL -C 1 -t mydevice01/mbtcp/+/sub/#)
}
function publish {
    msgid=$(cat /dev/urandom | tr -dc '0-9' | fold -w 19 | head -n 1)
    mosquitto_pub -h $URL -i 1564 -t mydevice01/mbtcp/$1/pub/$msgid -m "$2"
}
function pubsub {
    ## sync mode
    #msgid=$(cat /dev/urandom | tr -dc '0-9' | fold -w 19 | head -n 1)
    #mosquitto_pub -h $URL -i 1564 -t mydevice01/mbtcp/$1/pub/$msgid -m "$2"
    #out=$(timeout 15s mosquitto_sub -h $URL -C 1 -t mydevice01/mbtcp/+/sub/$msgid)

    ## async mode
    msgid=$(cat /dev/urandom | tr -dc '0-9' | fold -w 19 | head -n 1)
    timeout 15s mosquitto_sub -h $URL -C 1 -t mydevice01/mbtcp/+/sub/$msgid > /tmp/$msgid &  
    mosquitto_pub -h $URL -i 1564 -t mydevice01/mbtcp/$1/pub/$msgid -m "$2"
    sleep 3
    exec 3< /tmp/$msgid  # open the file for reading in the current shell, as fd 3
    out=$(cat <&3)
    rm /tmp/$msgid
}

#######################################################
set_title "TestTimeoutOps"
#######################################################

try "Get timeout 1st round - (1/4)"
pubsub "timeout.read" "{}"
check_ok_status "$out"

try "Set invalid timeout - (2/4)"
pubsub "timeout.update" '{"timeout": 123}'
check_ok_status "$out"

try "Get timeout 2nd round - (3/4)"
publish "timeout.read" "{}"
subscribe
check_ok_status "$out"

try "Set valid timeout - (2/4)"
pubsub "timeout.update" '{"timeout": 410000}'
check_ok_status "$out"

#######################################################
set_title "TestOneOffWriteFC5"
#######################################################

try "FC5 write bit test: port 502 - invalid value(2) - (1/5)"
pubsub "once.write" '{
    "fc": 5,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "data": 2
    }'
check_ok_status "$out"


try "FC5 write bit test: port 502 - miss port - (2/5)"
pubsub "once.write" '{
    "fc": 5,
    "ip": "'"$SLAVE"'",
    "slave": 1,
    "addr": 10,
    "data": 2
    }'
check_ok_status "$out"

try "FC5 write bit test: port 502 - valid value(0) - (3/5)"
pubsub "once.write" '{
    "fc": 5,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "data": 0
    }'
check_ok_status "$out"

try "FC5 write bit test: port 502 - valid value(1) - (4/5)"
pubsub "once.write" '{
    "fc": 5,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "data": 1
    }'
check_ok_status "$out"

try "FC5 invalid function code - (5/5)"
pubsub "once.write" '{
    "fc": 7,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "data": 1
    }'
check_not_ok_status "$out"


#######################################################
set_title "TestOneOffWriteFC6"
#######################################################

try "FC6 write 'DEC' register test: port 502 - valid value (22) - (1/8)"
pubsub "once.write" '{
    "fc": 6,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "hex": false,
	"data": "22"
    }'
check_ok_status "$out"

try "FC6 write 'DEC' register test: port 502 - miss hex type & port - (2/8)"
pubsub "once.write" '{
    "fc": 6,
    "ip": "'"$SLAVE"'",
    "slave": 1,
    "addr": 10,
	"data": "22"
    }'
check_ok_status "$out"

try "FC6 write 'DEC' register test: port 502 - invalid value (array) - (3/8)"
pubsub "once.write" '{
    "fc": 6,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "hex": false,
	"data": "22,11"
    }'
check_ok_status "$out"

try "FC6 write 'DEC' register test: port 502 - invalid hex type - (4/8)"
pubsub "once.write" '{
    "fc": 6,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "hex": false,
	"data": "ABCD1234"
    }'
check_not_ok_status "$out"

try "FC6 write 'HEX' register test: port 502 - valid value (ABCD) - (5/8)"
pubsub "once.write" '{
    "fc": 6,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "hex": true,
	"data": "ABCD"
    }'
check_ok_status "$out"

try "FC6 write 'HEX' register test: port 502 - miss port (ABCD) - (6/8)"
pubsub "once.write" '{
    "fc": 6,
    "ip": "'"$SLAVE"'",
    "slave": 1,
    "addr": 10,
    "hex": true,
	"data": "ABCD"
    }'
check_ok_status "$out"

try "FC6 write 'HEX' register test: port 502 - invalid value (ABCD1234) - (7/8)"
pubsub "once.write" '{
    "fc": 6,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "hex": true,
	"data": "ABCD1234"
    }'
check_ok_status "$out"

try "FC6 write 'HEX' register test: port 502 - invalid hex type - (8/8)"
pubsub "once.write" '{
    "fc": 6,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "hex": true,
	"data": "22,11"
    }'
check_not_ok_status "$out"

#######################################################
set_title "TestOneOffWriteFC15"
#######################################################

try "FC15 write bit test: port 502 - invalid json type - (1/5)"
pubsub "once.write" '{
    "fc": 15,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "len": 4,
	"data": [-1,0,-1,0]
    }'
check_not_ok_status "$out"

try "FC15 write bit test: port 502 - invalid json type - (2/5)"
pubsub "once.write" '{
    "fc": 15,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "len": 4,
	"data": "1,0,1,0"
    }'
check_not_ok_status "$out"

try "FC15 write bit test: port 502 - invalid value(2) - (3/5)"
pubsub "once.write" '{
    "fc": 15,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "len": 4,
	"data": [2,0,2,0]
    }'
check_ok_status "$out"

try "FC15 write bit test: port 502 - miss port - (4/5)"
pubsub "once.write" '{
    "fc": 15,
    "ip": "'"$SLAVE"'",
    "slave": 1,
    "addr": 10,
    "len": 4,
	"data": [2,0,2,0]
    }'
check_ok_status "$out"

try "FC15 write bit test: port 502 - valid value(0) - (5/5)"
pubsub "once.write" '{
    "fc": 15,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "len": 4,
	"data": [0,1,1,0]
    }'
check_ok_status "$out"

#######################################################
set_title "TestOneOffWriteFC16"
#######################################################

try "FC16 write write 'DEC' register test: port 502 - valid value (11,22,33,44) - (1/8)"
pubsub "once.write" '{
    "fc": 16,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "len": 4,
	"hex": false,
    "data": "11,22,33,44"
    }'
check_ok_status "$out"

try "FC16 write write 'DEC' register test: port 502 - miss hex type & port - (2/8)"
pubsub "once.write" '{
    "fc": 16,
    "ip": "'"$SLAVE"'",
    "slave": 1,
    "addr": 10,
    "len": 4,
    "data": "11,22,33,44"
    }'
check_ok_status "$out"

try "FC16 write write 'DEC' register test: port 502 - invalid hex type - (3/8)"
pubsub "once.write" '{
    "fc": 16,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "len": 4,
	"hex": false,
    "data": "ABCD1234"
    }'
check_not_ok_status "$out"

try "FC16 write write 'DEC' register test: port 502 - invalid length - (4/8)"
pubsub "once.write" '{
    "fc": 16,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "len": 8,
	"hex": false,
    "data": "11,22,33,44"
    }'
check_ok_status "$out"

try "FC16 write write 'HEX' register test: port 502 - valid value (ABCD1234) - (5/8)"
pubsub "once.write" '{
    "fc": 16,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "len": 4,
	"hex": true,
    "data": "ABCD1234"
    }'
check_ok_status "$out"

try "FC16 write write 'HEX' register test: port 502 - miss port (ABCD) - (6/8)"
pubsub "once.write" '{
    "fc": 16,
    "ip": "'"$SLAVE"'",
    "slave": 1,
    "addr": 10,
    "len": 4,
	"hex": true,
    "data": "ABCD1234"
    }'
check_ok_status "$out"

try "FC16 write write 'HEX' register test: port 502 - invalid hex type (11,22,33,44) - (7/8)"
pubsub "once.write" '{
    "fc": 16,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "len": 4,
	"hex": true,
    "data": "11,22,33,44"
    }'
check_not_ok_status "$out"

try "FC16 write write 'HEX' register test: port 502 - invalid length - (8/8)"
pubsub "once.write" '{
    "fc": 16,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 10,
    "len": 8,
	"hex": true,
    "data": "ABCD1234"
    }'
check_ok_status "$out"

#######################################################
set_title "TestOneOffReadFC1"
#######################################################

try "FC1 read bits test: port 502 - miss ip - (1/5)"
pubsub "once.read" '{
    "fc": 1,
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 1
    }'
check_not_ok_status "$out"

try "FC1 read bits test: port 502 - length 1 - (2/5)"
pubsub "once.read" '{
    "fc": 1,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 8,
    "len": 1
    }'
check_ok_status "$out"

try "FC1 read bits test: port 502 - length 7 - (3/5)"
pubsub "once.read" '{
    "fc": 1,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 7
    }'
check_ok_status "$out"

try "FC1 read bits test: port 502 - Illegal data address - (4/5)"
pubsub "once.read" '{
    "fc": 1,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 20000,
    "len": 7
    }'
check_not_ok_status "$out"

try "FC1 read bits test: port 503 - length 7 - (5/5)"
pubsub "once.read" '{
    "fc": 1,
    "ip": "'"$SLAVE"'",
    "port": "503",
    "slave": 1,
    "addr": 3,
    "len": 7
    }'
check_ok_status "$out"


#######################################################
set_title "TestOneOffReadFC2"
#######################################################

try "FC2 read bits test: port 502 - length 1 - (1/4)"
pubsub "once.read" '{
    "fc": 2,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 1
    }'
check_ok_status "$out"

try "FC2 read bits test: port 502 - length 7 - (2/4)"
pubsub "once.read" '{
    "fc": 2,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 7
    }'
check_ok_status "$out"

try "FC2 read bits test: port 502 - Illegal data address - (3/4)"
pubsub "once.read" '{
    "fc": 2,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 20000,
    "len": 7
    }'
check_not_ok_status "$out"

try "FC2 read bits test: port 503 - length 7 - (4/4)"
pubsub "once.read" '{
    "fc": 2,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 7
    }'
check_ok_status "$out"

#######################################################
set_title "TestOneOffReadFC3"
#######################################################

try "FC3 read bytes Type 1 test: port 502 - (1/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 7,
    "type": 1
    }'
check_ok_status "$out"

try "FC3 read bytes Type 2 test: port 502 - (2/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 7,
    "type": 2
    }'
check_ok_status "$out"

try "FC3 read bytes Type 3 length 4 test: port 502 - (3/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 4,
    "type": 3,
    "range":{
        "a": 0,
        "b": 65535,
        "c": 100,
        "d": 500
        }
    }'
check_ok_status "$out"

try "FC3 read bytes Type 3 length 7 test: port 502 - invalid length - (4/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 7,
    "type": 3,
    "range":{
        "a": 0,
        "b": 65535,
        "c": 100,
        "d": 500
        }
    }'
check_not_ok_status "$out"

try "FC3 read bytes Type 4 length 4 test: port 502 - Order: AB - (5/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 4,
    "type": 4,
    "order": 1
    }'
check_ok_status "$out"

try "FC3 read bytes Type 4 length 4 test: port 502 - Order: BA - (6/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 4,
    "type": 4,
    "order": 2
    }'
check_ok_status "$out"

try "FC3 read bytes Type 4 length 4 test: port 502 - miss order - (7/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 4,
    "type": 4
    }'
check_ok_status "$out"

try "FC3 read bytes Type 5 length 4 test: port 502 - Order: AB - (8/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 4,
    "type": 5,
    "order": 1
    }'
check_ok_status "$out"

try "FC3 read bytes Type 5 length 4 test: port 502 - Order: BA - (9/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 4,
    "type": 5,
    "order": 2
    }'
check_ok_status "$out"

try "FC3 read bytes Type 5 length 4 test: port 502 - miss order - (10/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 4,
    "type": 5
    }'
check_ok_status "$out"

try "FC3 read bytes Type 6 length 8 test: port 502 - Order: AB - (11/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 6,
    "order": 1
    }'
check_ok_status "$out"

try "FC3 read bytes Type 6 length 8 test: port 502 - Order: BA - (12/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 6,
    "order": 2
    }'
check_ok_status "$out"

try "FC3 read bytes Type 6 length 8 test: port 502 - miss order - (13/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 6
    }'
check_ok_status "$out"

try "FC3 read bytes Type 6 length 7 test: port 502 - invalid length - (14/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 7,
    "type": 6,
    "order": 2
    }'
check_not_ok_status "$out"

try "FC3 read bytes Type 7 length 8 test: port 502 - Order: AB - (15/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 7,
    "order": 1
    }'
check_ok_status "$out"

try "FC3 read bytes Type 7 length 8 test: port 502 - Order: BA - (16/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 7,
    "order": 2
    }'
check_ok_status "$out"

try "FC3 read bytes Type 7 length 8 test: port 502 - miss order - (17/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 7
    }'
check_ok_status "$out"

try "FC3 read bytes Type 7 length 7 test: port 502 - invalid length - (18/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 7,
    "type": 7,
    "order": 2
    }'
check_not_ok_status "$out"

try "FC3 read bytes Type 8 length 8 test: port 502 - order: ABCD - (19/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 8,
    "order": 1
    }'
check_ok_status "$out"

try "FC3 read bytes Type 8 length 8 test: port 502 - order: DCBA - (20/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 8,
    "order": 2
    }'
check_ok_status "$out"

try "FC3 read bytes Type 8 length 8 test: port 502 - order: BADC - (21/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 8,
    "order": 3
    }'
check_ok_status "$out"

try "FC3 read bytes Type 8 length 8 test: port 502 - order: CDAB - (22/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 8,
    "order": 4
    }'
check_ok_status "$out"

try "FC3 read bytes Type 8 length 7 test: port 502 - invalid length - (23/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 7,
    "type": 8,
    "order": 1
    }'
check_not_ok_status "$out"

try "FC3 read bytes: port 502 - invalid type - (24/24)"
pubsub "once.read" '{
    "fc": 3,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 9,
    "order": 1
    }'
check_ok_status "$out"


#######################################################
set_title "TestOneOffReadFC4"
#######################################################

try "FC4 read bytes Type 1 test: port 502 - (1/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 7,
    "type": 1
    }'
check_ok_status "$out"

try "FC4 read bytes Type 2 test: port 502 - (2/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 7,
    "type": 2
    }'
check_ok_status "$out"

try "FC4 read bytes Type 3 length 4 test: port 502 - (3/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 4,
    "type": 3,
    "range":{
        "a": 0,
        "b": 65535,
        "c": 100,
        "d": 500
        }
    }'
check_ok_status "$out"

try "FC4 read bytes Type 3 length 7 test: port 502 - invalid length - (4/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 7,
    "type": 3,
    "range":{
        "a": 0,
        "b": 65535,
        "c": 100,
        "d": 500
        }
    }'
check_not_ok_status "$out"

try "FC4 read bytes Type 4 length 4 test: port 502 - Order: AB - (5/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 4,
    "type": 4,
    "order": 1
    }'
check_ok_status "$out"

try "FC4 read bytes Type 4 length 4 test: port 502 - Order: BA - (6/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 4,
    "type": 4,
    "order": 2
    }'
check_ok_status "$out"

try "FC4 read bytes Type 4 length 4 test: port 502 - miss order - (7/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 4,
    "type": 4
    }'
check_ok_status "$out"

try "FC4 read bytes Type 5 length 4 test: port 502 - Order: AB - (8/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 4,
    "type": 5,
    "order": 1
    }'
check_ok_status "$out"

try "FC4 read bytes Type 5 length 4 test: port 502 - Order: BA - (9/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 4,
    "type": 5,
    "order": 2
    }'
check_ok_status "$out"

try "FC4 read bytes Type 5 length 4 test: port 502 - miss order - (10/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 4,
    "type": 5
    }'
check_ok_status "$out"

try "FC4 read bytes Type 6 length 8 test: port 502 - Order: AB - (11/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 6,
    "order": 1
    }'
check_ok_status "$out"

try "FC4 read bytes Type 6 length 8 test: port 502 - Order: BA - (12/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 6,
    "order": 2
    }'
check_ok_status "$out"

try "FC4 read bytes Type 6 length 8 test: port 502 - miss order - (13/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 6
    }'
check_ok_status "$out"

try "FC4 read bytes Type 6 length 7 test: port 502 - invalid length - (14/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 7,
    "type": 6,
    "order": 2
    }'
check_not_ok_status "$out"

try "FC4 read bytes Type 7 length 8 test: port 502 - Order: AB - (15/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 7,
    "order": 1
    }'
check_ok_status "$out"

try "FC4 read bytes Type 7 length 8 test: port 502 - Order: BA - (16/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 7,
    "order": 2
    }'
check_ok_status "$out"

try "FC4 read bytes Type 7 length 8 test: port 502 - miss order - (17/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 7
    }'
check_ok_status "$out"

try "FC4 read bytes Type 7 length 7 test: port 502 - invalid length - (18/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 7,
    "type": 7,
    "order": 2
    }'
check_not_ok_status "$out"

try "FC4 read bytes Type 8 length 8 test: port 502 - order: ABCD - (19/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 8,
    "order": 1
    }'
check_ok_status "$out"

try "FC4 read bytes Type 8 length 8 test: port 502 - order: DCBA - (20/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 8,
    "order": 2
    }'
check_ok_status "$out"

try "FC4 read bytes Type 8 length 8 test: port 502 - order: BADC - (21/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 8,
    "order": 3
    }'
check_ok_status "$out"

try "FC4 read bytes Type 8 length 8 test: port 502 - order: CDAB - (22/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 8,
    "order": 4
    }'
check_ok_status "$out"

try "FC4 read bytes Type 8 length 7 test: port 502 - invalid length - (23/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 7,
    "type": 8,
    "order": 1
    }'
check_not_ok_status "$out"

try "FC4 read bytes: port 502 - invalid type - (24/24)"
pubsub "once.read" '{
    "fc": 4,
    "ip": "'"$SLAVE"'",
    "port": "502",
    "slave": 1,
    "addr": 3,
    "len": 8,
    "type": 9,
    "order": 1
    }'
check_ok_status "$out"

###############################################################
echo
if [ "$(uname)" == "Darwin" ]; then
    echo "PASS: $tests_run tests run"
    echo "FAIL: $fail_run tests run"
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    echo -e "${COLOR_GREEN}PASS: $tests_run tests run${COLOR_REST}"
    echo -e "${COLOR_RED}FAIL: $fail_run tests run${COLOR_REST}"
fi
echo "---------------------------------" # end
