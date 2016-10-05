# MQTT API

## Table of contents

<!-- TOC depthFrom:2 depthTo:6 insertAnchor:false orderedList:false updateOnSave:true withLinks:true -->

- [Table of contents](#table-of-contents)
- [1. One-off requests](#1-one-off-requests)
    - [1.1 Read coil/register (**mbtcp.once.read**)](#11-read-coilregister-mbtcponceread)
    - [1.2 Write coil/register (**mbtcp.once.write**)](#12-write-coilregister-mbtcponcewrite)
    - [1.3 Get TCP connection timeout (**mbtcp.timeout.read**)](#13-get-tcp-connection-timeout-mbtcptimeoutread)
    - [1.4 Set TCP connection timeout (**mbtcp.timeout.update**)](#14-set-tcp-connection-timeout-mbtcptimeoutupdate)
- [2. Polling requests](#2-polling-requests)
    - [2.1 Add poll request (**mbtcp.poll.create**)](#21-add-poll-request-mbtcppollcreate)
    - [2.2 Update poll request interval (**mbtcp.poll.update**)](#22-update-poll-request-interval-mbtcppollupdate)
    - [2.3 Read poll request status (**mbtcp.poll.read**)](#23-read-poll-request-status-mbtcppollread)
    - [2.4 Delete poll request (**mbtcp.poll.delete**)](#24-delete-poll-request-mbtcppolldelete)
    - [2.5 Enable/Disable poll request (**mbtcp.poll.toggle**)](#25-enabledisable-poll-request-mbtcppolltoggle)
    - [2.6 Read all poll requests status (**mbtcp.polls.read**)](#26-read-all-poll-requests-status-mbtcppollsread)
    - [2.7 Delete all poll requests (**mbtcp.polls.delete**)](#27-delete-all-poll-requests-mbtcppollsdelete)
    - [2.8 Enable/Disable all poll requests (**mbtcp.polls.toggle**)](#28-enabledisable-all-poll-requests-mbtcppollstoggle)
    - [2.9 Import poll requests (**mbtcp.polls.import**)](#29-import-poll-requests-mbtcppollsimport)
    - [2.10 Export poll requests (**mbtcp.polls.export**)](#210-export-poll-requests-mbtcppollsexport)
    - [2.11 Read history (**mbtcp.poll.history**)](#211-read-history-mbtcppollhistory)
    - [2.12 Data (**mbtcp.data**)](#212-data-mbtcpdata)
- [3. Filter requests](#3-filter-requests)
    - [3.1 Add filter request (**mbtcp.filter.create**)](#31-add-filter-request-mbtcpfiltercreate)
    - [3.2 Update filter request (**mbtcp.filter.update**)](#32-update-filter-request-mbtcpfilterupdate)
    - [3.3 Read filter request status (**mbtcp.filter.read**)](#33-read-filter-request-status-mbtcpfilterread)
    - [3.4 Delete filter request (**mbtcp.filter.delete**)](#34-delete-filter-request-mbtcpfilterdelete)
    - [3.5 Enable/Disable filter request (**mbtcp.filter.toggle**)](#35-enabledisable-filter-request-mbtcpfiltertoggle)
    - [3.6 Read all filter requests (**mbtcp.filters.read**)](#36-read-all-filter-requests-mbtcpfiltersread)
    - [3.7 Delete all filter requests (**mbtcp.filters.delete**)](#37-delete-all-filter-requests-mbtcpfiltersdelete)
    - [3.8 Enable/Disable all filter requests (**mbtcp.filters.toggle**)](#38-enabledisable-all-filter-requests-mbtcpfilterstoggle)
    - [3.9 Import filter requests (**mbtcp.filters.import**)](#39-import-filter-requests-mbtcpfiltersimport)
    - [3.10 Export filter requests (**mbtcp.filters.export**)](#310-export-filter-requests-mbtcpfiltersexport)

<!-- /TOC -->

## 1. One-off requests

### 1.1 Read coil/register (**mbtcp.once.read**)

- **Request**

```bash
<devicename>/mbtcp/once.read/pub/<messageId>
```

- FC1, 2

    ```JavaScript
    {
        "fc": 1,
        "ip": "192.168.3.2",
        "port": "502",
        "slave": 1,
        "addr": 10,
        "len": 4
    }
    ```

- FC3, 4 - type 1, 2

    ```JavaScript
    {
        "fc": 3,
        "ip": "192.168.3.2",
        "port": "502",
        "slave": 1,
        "addr": 10,
        "len": 4,
        "type": 1
    }
    ```

- FC3, 4 - type 3

    ```JavaScript
    {
        "fc": 3,
        "ip": "192.168.3.2",
        "port": "502",
        "slave": 1,
        "addr": 10,
        "len": 4,
        "type": 3,
        "range":{
            "a": 1,
            "b": 2,
            "c": 3,
            "d": 4
        }
    }
    ```

- FC3, 4 - type 4, 5, 6, 7, 8

    ```JavaScript
    {
        "fc": 3,
        "ip": "192.168.3.2",
        "port": "502",
        "slave": 1,
        "addr": 10,
        "len": 4,
        "type": 4,
        "order": 1
    }
    ```

- **Response**

```bash
<devicename>/mbtcp/once.read/sub/<messgeId>
```

- Example: Bits read (FC1, FC2)

    - Success

    ```JavaScript
    {
        "status": "ok",
        "data": [0,1,0,1,0,1]
    }
    ```

    - Fail

    ```JavaScript
    {
        "status": "timeout"
    }
    ```

- Examples: Register read (FC3, FC4) - type 1, 2 (raw)

    - Success - type 1 (RegisterArray):

    ```JavaScript
    {
        "status": "ok",
        "type": 1,
        "bytes": [0XFF, 0X34, 0XAB],
        "data": [255, 1234, 789]
    }
    ```

    - Success - type 2 (Hex String):

    ```JavaScript
    {
        "status": "ok",
        "type": 2,
        "bytes": [0XFF, 0X34, 0XAB],
        "data": "112C004F12345678"
    }
    ```

    - Fail:

    ```JavaScript
    {
        "type": 2,
        "status": "timeout"
    }
    ```

- Examples: Register read (FC3, FC4) - type 3 (scale)

    - Success:

    ```JavaScript
    {
        "status": "ok",
        "type": 3,
        "bytes": [0XAB, 0X12, 0XCD, 0XED, 0X12, 0X34],
        "data": [22.34, 33.12, 44.56]
    }
    ```

    - Fail:

    ```JavaScript
    {
        "type": 3,
        "bytes": null,
        "status": "timeout"
    }
    ```

- Examples: Register read (FC3, FC4) - type 4, 5 (16-bit)

    - Success:

    ```JavaScript
    {
        "status": "ok",
        "type": 4,
        "bytes": [0XAB, 0X12, 0XCD, 0XED, 0X12, 0X34],
        "data": [255, 1234, 789]
    }
    ```

    - Fail:

    ```JavaScript
    {
        "type": 4,
        "bytes": null,
        "status": "timeout"
    }
    ```

- Examples: Register read (FC3, FC4) - type 6, 7, 8 (32-bit)

    - Success - type 6, 7 (UInt32, Int32):

    ```JavaScript
    {
        "status": "ok",
        "type": 6,
        "bytes": [0XAB, 0X12, 0XCD, 0XED, 0X12, 0X34],
        "data": [255, 1234, 789]
    }
    ```

    - Success - type 8 (Float32):

    ```JavaScript
    {
        "status": "ok",
        "type": 8,
        "bytes": [0XAB, 0X12, 0XCD, 0XED, 0X12, 0X34],
        "data": [22.34, 33.12, 44.56]
    }
    ```

    - Fail:

    ```JavaScript
    {
        "type": 8,
        "bytes": null,
        "status": "timeout"
    }
    ```

---

### 1.2 Write coil/register (**mbtcp.once.write**)

- **Request**

```bash
<devicename>/mbtcp/once.write/pub/<messageId>
```

- FC5

    ```JavaScript
        {
            "fc": 5,
            "ip": "192.168.3.2",
            "port": "502",
            "slave": 1,
            "addr": 10,
            "data": 1
        }
    ```

- FC6 (DEC)

    ```JavaScript
        {
            "fc": 6,
            "ip": "192.168.3.2",
            "port": "502",
            "slave": 1,
            "addr": 10,
            "hex": false,
            "data": "22"
        }
    ```

- FC6 (HEX)

    ```JavaScript
        {
            "fc": 6,
            "ip": "192.168.3.2",
            "port": "502",
            "slave": 1,
            "addr": 10,
            "hex": true,
            "data": "ABCD"
        }
    ```

- FC15

    ```JavaScript
        {
            "fc": 15,
            "ip": "192.168.3.2",
            "port": "502",
            "slave": 1,
            "addr": 10,
            "len": 4,
            "data": [1,0,1,0]
        }
    ```

- FC16 (DEC)

    ```JavaScript
        {
            "fc": 16,
            "ip": "192.168.3.2",
            "port": "502",
            "slave": 1,
            "addr": 10,
            "len": 4,
            "hex": false,
            "data": "11,22,33,44"
        }
    ```

- FC16 (HEX)

    ```JavaScript
        {
            "fc": 16,
            "ip": "192.168.3.2",
            "port": "502",
            "slave": 1,
            "addr": 10,
            "len": 4,
            "hex": true,
            "data": "ABCD1234EFAB1234"
        }
    ```

- **Response**

```bash
<devicename>/mbtcp/once.write/sub/<messgeId>
```

- Success:

    ```JavaScript
    {
        "status": "ok"
    }
    ```

- Fail:

    ```JavaScript
    {
        "status": "timeout"
    }
    ```

---

### 1.3 Get TCP connection timeout (**mbtcp.timeout.read**)

- **Request**

```bash
<devicename>/mbtcp/timeout.read/pub/<messageId>
```

payload:

```JavaScript
{}
```

- **Response**

```bash
<devicename>/mbtcp/timeout.read/sub/<messageId>
```

- Success:

    ```JavaScript
    {
        "status": "ok",
        "timeout": 210000
    }
    ```

- Fail:

    ```JavaScript
    {
        "status": "timeout"
    }
    ```

---

### 1.4 Set TCP connection timeout (**mbtcp.timeout.update**)

- **Request**

```bash
<devicename>/mbtcp/timeout.update/pub/<messageId>
```

payload:

```JavaScript
{ "timeout": 210000 }
```

- **Response**

```bash
<devicename>/mbtcp/timeout.update/sub/<messageId>
```

- Success:

    ```JavaScript
    {
        "status": "ok"
    }
    ```

- Fail:

    ```JavaScript
    {
        "status": "fail"
    }
    ```

---

## 2. Polling requests

### 2.1 Add poll request (**mbtcp.poll.create**)

- **Request**

```bash
<devicename>/mbtcp/poll.create/pub/<messageId>
```

payload:

```JavaScript
{
    "name": "led-1",
    "fc": 1,
    "ip": "192.168.3.2",
    "port": "502",
    "slave": 22,
    "addr": 250,
    "len": 10,
    "interval" : 3
}
```

- **Response**

```bash
<devicename>/mbtcp/poll.create/sub/<messageId>
```

- Success:

```JavaScript
{
    "status": "ok"
}
```

- Fail:

```JavaScript
{
    "status": "timeout"
}
```

---

### 2.2 Update poll request interval (**mbtcp.poll.update**)

- **Request**

```bash
<devicename>/mbtcp/poll.update/pub/<messageId>
```

payload:

```JavaScript
{
    "name": "led_1",
    "interval" : 3
}
```

- **Response**

```bash
<devicename>/mbtcp/poll.update/sub/<messageId>
```

- Success:

```JavaScript
{
    "status": "ok"
}
```

- Fail:

```JavaScript
{
    "status": "timeout"
}
```

---

### 2.3 Read poll request status (**mbtcp.poll.read**)

- **Request**

```bash
<devicename>/mbtcp/poll.read/pub/<messageId>
```

payload:

```JavaScript
{
    "name": "led_1"
}
```

- **Response**

```bash
<devicename>/mbtcp/poll.read/sub/<messageId>
```

- Success:

    ```JavaScript
    {
        "fc": 1,
        "ip": "192.168.3.2",
        "port": "502",
        "slave": 22,
        "addr": 250,
        "len": 10,
        "interval" : 3,
        "status": "ok",
        "enabled": true
    }
    ```

- Fail:

    ```JavaScript
    {
        "status": "not exist"
    }
    ```

---

### 2.4 Delete poll request (**mbtcp.poll.delete**)

- **Request**

```bash
<devicename>/mbtcp/poll.delete/pub/<messageId>
```

payload:

```JavaScript
{
    "name": "led_1"
}
```

- **Response**

```bash
<devicename>/mbtcp/poll.delete/sub/<messageId>
```

- Success:

    ```JavaScript
    {
        "status": "ok"
    }
    ```

- Fail:

    ```JavaScript
    {
        "status": "timeout"
    }
    ```

---

### 2.5 Enable/Disable poll request (**mbtcp.poll.toggle**)

- **Request**

```bash
<devicename>/mbtcp/poll.toggle/pub/<messageId>
```

payload:

```JavaScript
{
    "name": "led_1",
    "enabled": true
}
```

- **Response**

```bash
<devicename>/mbtcp/poll.toggle/sub/<messageId>
```

- Success:

    ```JavaScript
    {
        "status": "ok"
    }
    ```

- Fail:

    ```JavaScript
    {
        "status": "timeout"
    }
    ```

---

### 2.6 Read all poll requests status (**mbtcp.polls.read**)

- **Request**

```bash
<devicename>/mbtcp/polls.read/pub/<messageId>
```

payload:

```JavaScript
{}
```


- **Response**

```bash
<devicename>/mbtcp/polls.read/sub/<messageId>
```

- Success:

    ```JavaScript
    {
        "status": "ok",
        "polls": [
            {
                "name": "led_1",
                "fc": 1,
                "ip": "192.168.3.2",
                "port": "502",
                "slave": 22,
                "addr": 250,
                "len": 10,
                "interval" : 3,
                "status": "ok",
                "enabled": true
            },
            {
                "name": "led_2",
                "fc": 1,
                "ip": "192.168.3.2",
                "port": "502",
                "slave": 22,
                "addr": 250,
                "len": 10,
                "interval" : 3,
                "status": "ok",
                "enabled": true
            }]
    }
    ```

- Fail:

    ```JavaScript
    {
        "status": "timeout"
    }
    ```

---

### 2.7 Delete all poll requests (**mbtcp.polls.delete**)

- **Request**

```bash
<devicename>/mbtcp/polls.delete/pub/<messageId>
```

payload:

```JavaScript
{}
```

- **Response**

```bash
<devicename>/mbtcp/polls.delete/sub/<messageId>
```

- Success:

    ```JavaScript
    {
        "status": "ok"
    }
    ```

- Fail:

    ```JavaScript
    {
        "status": "timeout"
    }
    ```

---

### 2.8 Enable/Disable all poll requests (**mbtcp.polls.toggle**)

- **Request**

```bash
<devicename>/mbtcp/polls.toggle/pub/<messageId>
```

payload:

```JavaScript
{
    "enabled": true
}
```

- **Response**

```bash
<devicename>/mbtcp/polls.toggle/sub/<messageId>
```

- Success:

    ```JavaScript
    {
        "status": "ok"
    }
    ```

- Fail:

    ```JavaScript
    {
        "status": "timeout"
    }
    ```

---

### 2.9 Import poll requests (**mbtcp.polls.import**)

- **Request**

```bash
<devicename>/mbtcp/polls.import/pub/<messageId>
```

payload:

```JavaScript
{
    "polls": [
        {
            "name": "led_1",
            "fc": 1,
            "ip": "192.168.3.2",
            "port": "502",
            "slave": 22,
            "addr": 250,
            "len": 10,
            "interval" : 3,
            "status": "ok",
            "enabled": true
        },
        {
            "name": "led_2",
            "fc": 1,
            "ip": "192.168.3.2",
            "port": "502",
            "slave": 22,
            "addr": 250,
            "len": 10,
            "interval" : 3,
            "status": "ok",
            "enabled": true
        }]
}
```

- **Response**

```bash
<devicename>/mbtcp/polls.import/sub/<messageId>
```

- Success:

    ```JavaScript
    {
        "status": "ok"
    }
    ```

- Fail:

    ```JavaScript
    {
        "status": "timeout"
    }
    ```

---

### 2.10 Export poll requests (**mbtcp.polls.export**)

- **Request**

```bash
<devicename>/mbtcp/polls.export/pub/<messageId>
```

payload:

```JavaScript
{}
```

- **Response**

```bash
<devicename>/mbtcp/polls.export/sub/<messageId>
```

- Success:

    ```JavaScript
    {
        "status": "ok",
        "polls": [
            {
                "name": "led_1",
                "fc": 1,
                "ip": "192.168.3.2",
                "port": "502",
                "slave": 22,
                "addr": 250,
                "len": 10,
                "interval" : 3,
                "status": "ok",
                "enabled": true
            },
            {
                "name": "led_2",
                "fc": 1,
                "ip": "192.168.3.2",
                "port": "502",
                "slave": 22,
                "addr": 250,
                "len": 10,
                "interval" : 3,
                "status": "ok",
                "enabled": true
            }]
    }
    ```

- Fail:

    ```JavaScript
    {
        "status": "timeout"
    }
    ```

---

### 2.11 Read history (**mbtcp.poll.history**)

- **Request**

```bash
<devicename>/mbtcp/poll.history/pub/<messageId>
```

payload:

```JavaScript
{
    "name": "led_1"
}
```

- **Response**

```bash
<devicename>/mbtcp/poll.history/sub/<messageId>
```

- Success (len=1):

    ```JavaScript
    {
        "status": "ok",
        "data":[{"data": [1], "ts": 2012031203},
                {"data": [0], "ts": 2012031205},
                {"data": [1], "ts": 2012031207}]
    }
    ```

- Success (len=n):

    ```JavaScript
    {
        "status": "ok",
        "data":[{"data": [1,0,1], "ts": 2012031203},
                {"data": [1,1,1], "ts": 2012031205},
                {"data": [0,0,1], "ts": 2012031207}]
    }
    ```

- Fail:

    ```JavaScript
    {
        "status": "not exist"
    }
    ```

### 2.12 Data (**mbtcp.data**)

No request

- **Response**

```bash
<devicename>/mbtcp/data/sub/<messageId>
```

**TODO**

---

## 3. Filter requests

### 3.1 Add filter request (**mbtcp.filter.create**)

- **Request**

```bash
<devicename>/mbtcp/filter.create/pub/<messageId>
```

- **Response**

```bash
<devicename>/mbtcp/filter.create/sub/<messageId>
```

---

### 3.2 Update filter request (**mbtcp.filter.update**)

- **Request**

```bash
<devicename>/mbtcp/filter.update/pub/<messageId>
```

- **Response**

```bash
<devicename>/mbtcp/filter.update/sub/<messageId>
```

---

### 3.3 Read filter request status (**mbtcp.filter.read**)

- **Request**

```bash
<devicename>/mbtcp/filter.read/pub/<messageId>
```

- **Response**

```bash
<devicename>/mbtcp/filter.read/sub/<messageId>
```

---

### 3.4 Delete filter request (**mbtcp.filter.delete**)

- **Request**

```bash
<devicename>/mbtcp/filter.delete/pub/<messageId>
```

- **Response**

```bash
<devicename>/mbtcp/filter.delete/sub/<messageId>
```

---

### 3.5 Enable/Disable filter request (**mbtcp.filter.toggle**)

- **Request**

```bash
<devicename>/mbtcp/filter.toggle/pub/<messageId>
```

- **Response**

```bash
<devicename>/mbtcp/filter.toggle/sub/<messageId>
```

---

### 3.6 Read all filter requests (**mbtcp.filters.read**)

- **Request**

```bash
<devicename>/mbtcp/filters.read/pub/<messageId>
```

- **Response**

```bash
<devicename>/mbtcp/filters.read/sub/<messageId>
```

---

### 3.7 Delete all filter requests (**mbtcp.filters.delete**)

- **Request**

```bash
<devicename>/mbtcp/filters.delete/pub/<messageId>
```

- **Response**

```bash
<devicename>/mbtcp/filters.delete/sub/<messageId>
```

---

### 3.8 Enable/Disable all filter requests (**mbtcp.filters.toggle**)

- **Request**

```bash
<devicename>/mbtcp/filters.toggle/pub/<messageId>
```

- **Response**

```bash
<devicename>/mbtcp/filters.toggle/sub/<messageId>
```

---

### 3.9 Import filter requests (**mbtcp.filters.import**)

- **Request**

```bash
<devicename>/mbtcp/filters.import/pub/<messageId>
```

- **Response**

```bash
<devicename>/mbtcp/filters.import/sub/<messageId>
```

---

### 3.10 Export filter requests (**mbtcp.filters.export**)

- **Request**

```bash
<devicename>/mbtcp/filters.export/pub/<messageId>
```

- **Response**

```bash
<devicename>/mbtcp/filters.export/sub/<messageId>
```

---
