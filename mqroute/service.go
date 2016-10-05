// Package mqroute a mqtt-based routing
//
// By taka@cmwang.net
//
package mqroute

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"sync"
	"time"

	// only init remote package
	MQTT "github.com/eclipse/paho.mqtt.golang"
	psmb "github.com/taka-wang/psmb"
	"github.com/taka-wang/psmb/viper-conf"
)

var (
	// version version string
	version string
	// iam who am I for zmq
	iam string
	// defaultMbPort default modbus slave port number
	defaultMbPort string
	// minConnTimeout minimal modbus tcp connection timeout
	minConnTimeout int64
	// options mqtt client options
	options *MQTT.ClientOptions
	// brokerURL mqtt broker URL
	brokerURL string
	// subTopic generic subscribe topic
	subTopic string
	// pubQos publish qos
	pubQos byte
	// pollerTimeout poller ticker
	pollerTimeout time.Duration
	// chanRequest request message channel
	chanRequest chan [3]string
	// chanResponse message channel
	chanResponse chan [3]string
	// idMap transaction and message ID
	idMap = struct {
		sync.RWMutex
		m map[string]string
	}{m: make(map[string]string)}
)

type (
	// Service mqtt servicce
	Service struct {
		// client MQTT client
		client MQTT.Client
		// isRunning running flag
		isRunning bool
		// isStopped stop channel
		isStopped chan bool
	}
)

func setDefaults() {
	conf.SetDefault(keyMqttDeviceID, defaultMqttDeviceID)
	conf.SetDefault(keyMqttScheme, defaultMqttScheme)
	conf.SetDefault(keyMqttHost, defaultMqttHost)
	conf.SetDefault(keyMqttPort, defaultMqttPort)
	conf.SetDefault(keyMqttUsername, defaultMqttUsername)
	conf.SetDefault(keyMqttPassword, defaultMqttPassword)
	conf.SetDefault(keyMqttPubQos, defaultMqttPubQos)
	conf.SetDefault(keyMqttSubQos, defaultMqttSubQos)
	conf.SetDefault(keyMqttCleanSession, defaultMqttCleanSession)
	conf.SetDefault(keyMqttOrder, defaultMqttOrder)
	conf.SetDefault(keyMqttWill, defaultMqttWill)
	conf.SetDefault(keyMqttWillTopic, defaultMqttWillTopic)
	conf.SetDefault(keyMqttWillPayload, defaultMqttWillPayload)
	conf.SetDefault(keyMqttWillQos, defaultMqttWillQos)
	conf.SetDefault(keyMqttWillRetain, defaultMqttKeepAliveInterval)
	conf.SetDefault(keyMqttKeepAlive, defaultMqttDeviceID)
	conf.SetDefault(keyMqttPingTimeout, defaultMqttPingTimeout)
	conf.SetDefault(keyMqttConnTimeout, defaultMqttConnTimeout)
	conf.SetDefault(keyMqttReconnectInterval, defaultMqttReconnectInterval)
	conf.SetDefault(keyMqttAutoReconnect, defaultMqttAutoReconnect)
	conf.SetDefault(keyMqttDepthSize, defaultMqttDepthSize)
	conf.SetDefault(keyMqttWriteTimeout, defaultMqttWriteTimeout)
	conf.SetDefault(keyMqttSubTimeout, defaultMqttSubTimeout)
	conf.SetDefault(keyMqttVersion, defaultMqttVersion)
	conf.SetDefault(keyMqttIAM, defaultMqttIAM)
}

func init() {

	// get init values from config file
	brokerURL = fmt.Sprintf("%s://%s:%s",
		conf.GetString(keyMqttScheme),
		conf.GetString(keyMqttHost),
		conf.GetString(keyMqttPort))

	// <device_id>/mbtcp/<command>/sub/<message_id>
	subTopic = conf.GetString(keyMqttDeviceID) + "/mbtcp/+/pub/#"

	version = conf.GetString(keyMqttVersion)
	iam = conf.GetString(keyMqttIAM)
	defaultMbPort = conf.GetString(keyTCPDefaultPort)
	minConnTimeout = conf.GetInt64(keyMinConnectionTimout)
	pollerTimeout = conf.GetDuration(keyMqttSubTimeout)
	pubQos = byte(conf.GetInt(keyMqttPubQos))

	options = MQTT.NewClientOptions().
		AddBroker(brokerURL).
		SetClientID(conf.GetString(keyMqttDeviceID)).
		SetUsername(conf.GetString(keyMqttUsername)).
		SetPassword(conf.GetString(keyMqttPassword)).
		SetCleanSession(conf.GetBool(keyMqttCleanSession)).
		SetOrderMatters(conf.GetBool(keyMqttOrder)).
		SetKeepAlive(conf.GetDuration(keyMqttKeepAlive) * time.Second).
		SetPingTimeout(conf.GetDuration(keyMqttPingTimeout) * time.Second).
		SetWriteTimeout(conf.GetDuration(keyMqttWriteTimeout) * time.Second).
		SetConnectTimeout(conf.GetDuration(keyMqttConnTimeout) * time.Second).
		SetMaxReconnectInterval(conf.GetDuration(keyMqttReconnectInterval) * time.Second).
		SetAutoReconnect(conf.GetBool(keyMqttAutoReconnect)).
		SetMessageChannelDepth(uint(conf.GetInt(keyMqttDepthSize))).
		//SetTLSConfig()
		//SetStore()
		//SetWill
		SetDefaultPublishHandler(messageHandler).
		SetOnConnectHandler(onConnectHandler).
		SetConnectionLostHandler(connectionLostHandler)

	// set will handler if enabled
	if conf.GetBool(keyMqttWill) {
		options.SetWill(conf.GetString(keyMqttWillTopic),
			conf.GetString(keyMqttWillPayload),
			byte(conf.GetInt(keyMqttWillQos)),
			conf.GetBool(keyMqttWillRetain))
	}
}

// NewService create service
func NewService() (*Service, error) {
	return &Service{
		isRunning: false,
		client:    MQTT.NewClient(options),
		isStopped: make(chan bool),
	}, nil
}

// SetChannels set request and response channels, format:
//  {cmd, payload, tid}
func (b *Service) SetChannels(req, resp chan [3]string) {
	chanRequest = req
	chanResponse = resp
}

// Start start service
func (b *Service) Start() {
	conf.Log.Debug("start service")

	if chanRequest == nil {
		conf.Log.Fatal("No request channel existed!")
		return
	}

	if chanResponse == nil {
		conf.Log.Fatal("No response channel existed!")
		return
	}

	// only start the service if it hasn't been started yet.
	if b.isRunning {
		conf.Log.Warn("Already Running.")
		return
	}

	b.isRunning = true

	// connect to broker
	if token := b.client.Connect(); token.Wait() && token.Error() != nil {
		conf.Log.WithError(token.Error()).Error("Fail to connect to broker.")
		return
	}

	conf.Log.Debug("Succeed to connect to mqtt broker.")

	// loop to waiting for worker response
	for {
		select {
		case <-b.isStopped:
			b.isRunning = false
			conf.Log.Debug("Stopped")
			break
		case resp := <-chanResponse: // receive response from worker
			conf.Log.WithFields(conf.Fields{
				"cmd":     resp[0],
				"payload": resp[1],
				"ts":      resp[2],
			}).Debug("recv response from backend worker")

			// get msg id from idMap
			idMap.RLock()
			msgID, ok := idMap.m[resp[2]]
			idMap.RUnlock()
			if !ok {
				conf.Log.Warn("Cannot retrieve msg ID")
				return
			}

			// remove from idMap
			idMap.Lock()
			delete(idMap.m, resp[2])
			idMap.Unlock()

			retain := false // can be alter in switch cases
			var topic, payload string

			switch resp[0] {
			case psmb.CmdMbtcpOnceRead:
				topic = fmt.Sprintf("%s/mbtcp/%s/sub/%s", options.ClientID, mbtcpOnceRead, msgID)
				payload = resp[1]
			case psmb.CmdMbtcpOnceWrite:
				topic = fmt.Sprintf("%s/mbtcp/%s/sub/%s", options.ClientID, mbtcpOnceWrite, msgID)
				payload = resp[1]
			case psmb.CmdMbtcpGetTimeout:
				topic = fmt.Sprintf("%s/mbtcp/%s/sub/%s", options.ClientID, mbtcpGetTimeout, msgID)
				payload = resp[1]
			case psmb.CmdMbtcpSetTimeout:
				topic = fmt.Sprintf("%s/mbtcp/%s/sub/%s", options.ClientID, mbtcpSetTimeout, msgID)
				payload = resp[1]
			case psmb.CmdMbtcpCreatePoll:
				//
			case psmb.CmdMbtcpUpdatePoll:
				//
			case psmb.CmdMbtcpGetPoll:
				//
			case psmb.CmdMbtcpDeletePoll:
				//
			case psmb.CmdMbtcpTogglePoll:
				//
			case psmb.CmdMbtcpGetPolls:
				//
			case psmb.CmdMbtcpDeletePolls:
				//
			case psmb.CmdMbtcpTogglePolls:
				//
			case psmb.CmdMbtcpImportPolls:
				//
			case psmb.CmdMbtcpExportPolls:
				//
			case psmb.CmdMbtcpGetPollHistory:
				//
			case psmb.CmdMbtcpCreateFilter:
				//
			case psmb.CmdMbtcpUpdateFilter:
				//
			case psmb.CmdMbtcpGetFilter:
				//
			case psmb.CmdMbtcpDeleteFilter:
				//
			case psmb.CmdMbtcpToggleFilter:
				//
			case psmb.CmdMbtcpGetFilters:
				//
			case psmb.CmdMbtcpDeleteFilters:
				//
			case psmb.CmdMbtcpToggleFilters:
				//
			case psmb.CmdMbtcpImportFilters:
				//
			case psmb.CmdMbtcpExportFilters:
				//
			case psmb.CmdMbtcpData:
				//
			default:
				conf.Log.Warn("Unsupported response")
				return
			}

			// @@@publish back
			sendResponse(b.client, topic, payload, pubQos, retain)
		case <-time.After(time.Millisecond * pollerTimeout):
			// do nothing
		}
	}
}

// Stop stop service
func (b *Service) Stop() {
	conf.Log.Debug("stop service")
	if b.isRunning {
		b.isStopped <- true
		b.client.Disconnect(250)
		conf.Log.Debug("Disconnect from mqtt broker.")
	}
}

// onConnectHandler on connected handler,
// 	register subscriber topic
var onConnectHandler MQTT.OnConnectHandler = func(client MQTT.Client) {
	conf.Log.Debug("On connected, setup subscribe topic")
	token := client.Subscribe(subTopic, byte(conf.GetInt(keyMqttSubQos)), nil)
	if token.Wait() && token.Error() != nil {
		conf.Log.WithError(token.Error()).Error("Fail to subscribe")
	}
}

// connectionLostHandler connection lost handler
var connectionLostHandler MQTT.ConnectionLostHandler = func(client MQTT.Client, err error) {
	conf.Log.WithError(err).Warn("Connection lost")
}

// messageHandler handle all MQTT requests from upstream
var messageHandler MQTT.MessageHandler = func(client MQTT.Client, msg MQTT.Message) {
	conf.Log.WithFields(conf.Fields{
		"Topic": msg.Topic(),
		"Msg":   string(msg.Payload()),
	}).Debug("Recv MQTT request")

	// split mqtt topic into array,
	// 0: device id; 1: mbtcp; 2: command; 3: pub; 4: msg id
	topics := strings.Split(msg.Topic(), "/")

	if len(topics) != 5 {
		conf.Log.Warn("Invalid MQTT topic length")
		return
	}

	if topics[1] != "mbtcp" {
		conf.Log.WithField("topic", topics[2]).Debug("Not mbtcp command")
		return
	}

	var command, payload, timestamp string

	switch topics[2] {
	case mbtcpOnceRead:
		command = psmb.CmdMbtcpOnceRead
		var req psmb.MbtcpReadReq
		if err := json.Unmarshal(msg.Payload(), &req); err != nil {
			conf.Log.WithError(err).Warn("Fail to unmarshal payload")
			return
		}
		switch req.FC {
		case 1, 2, 3, 4:
			// enhance: check non-ignorable fields

			// ip
			// port
			// slave
			// addr
			// fc 1~4
			// order
			// type
			// scale
			tid := time.Now().UTC().UnixNano()
			req.From = iam
			req.Tid = tid
			js, _ := json.Marshal(req)
			payload = string(js)
			timestamp = strconv.FormatInt(tid, 10)
		default:
			conf.Log.WithField("FC", req.FC).Debug("Invalid function code for once read")
			// send error back
			go sendErrorResponse(client, topics[2], topics[4], "Invalid function code for once read", false)
			return
		}
	case mbtcpOnceWrite:
		command = psmb.CmdMbtcpOnceWrite
		// partial unmarshal
		var data json.RawMessage
		req := psmb.MbtcpWriteReq{Data: &data}
		if err := json.Unmarshal(msg.Payload(), &req); err != nil {
			conf.Log.WithError(err).Warn("Fail to unmarshal payload")
			return
		}

		switch req.FC {
		case 5, 6, 15, 16:
			// enhance: check non-ignorable fields

			tid := time.Now().UTC().UnixNano()
			req.From = iam
			req.Tid = tid
			js, _ := json.Marshal(req)
			payload = string(js)
			timestamp = strconv.FormatInt(tid, 10)
		default:
			conf.Log.WithField("FC", req.FC).Warn("Invalid function code for once write")
			// send error back
			go sendErrorResponse(client, topics[2], topics[4], "Invalid function code for once write", false)
			return
		}

	case mbtcpGetTimeout: // done
		command = psmb.CmdMbtcpGetTimeout
		tid := time.Now().UTC().UnixNano()
		js, _ := json.Marshal(psmb.MbtcpTimeoutReq{From: iam, Tid: tid})
		payload = string(js)
		timestamp = strconv.FormatInt(tid, 10)
	case mbtcpSetTimeout: // done
		command = psmb.CmdMbtcpSetTimeout
		var req psmb.MbtcpTimeoutReq

		if err := json.Unmarshal(msg.Payload(), &req); err != nil {
			conf.Log.WithError(err).Warn("Fail to unmarshal payload")
			return
		}

		// check timeout
		if req.Data < minConnTimeout {
			conf.Log.Warn("Invalid timeout value, set to minimal")
			req.Data = minConnTimeout
		}

		tid := time.Now().UTC().UnixNano()
		req.From = iam
		req.Tid = tid
		js, _ := json.Marshal(req)
		payload = string(js)
		timestamp = strconv.FormatInt(tid, 10)
	case mbtcpCreatePoll:
		command = psmb.CmdMbtcpCreatePoll
	case mbtcpUpdatePoll:
		command = psmb.CmdMbtcpUpdatePoll
	case mbtcpGetPoll:
		command = psmb.CmdMbtcpGetPoll
	case mbtcpDeletePoll:
		command = psmb.CmdMbtcpDeletePoll
	case mbtcpTogglePoll:
		command = psmb.CmdMbtcpTogglePoll
	case mbtcpGetPollHistory:
		command = psmb.CmdMbtcpGetPollHistory
	case mbtcpGetPolls:
		command = psmb.CmdMbtcpGetPolls
	case mbtcpDeletePolls:
		command = psmb.CmdMbtcpDeletePolls
	case mbtcpTogglePolls:
		command = psmb.CmdMbtcpTogglePolls
	case mbtcpImportPolls:
		command = psmb.CmdMbtcpImportPolls
	case mbtcpExportPolls:
		command = psmb.CmdMbtcpExportPolls
	case mbtcpData:
		command = psmb.CmdMbtcpData
	case mbtcpCreateFilter:
		command = psmb.CmdMbtcpCreateFilter
	case mbtcpUpdateFilter:
		command = psmb.CmdMbtcpUpdateFilter
	case mbtcpGetFilter:
		command = psmb.CmdMbtcpGetFilter
	case mbtcpDeleteFilter:
		command = psmb.CmdMbtcpDeleteFilter
	case mbtcpToggleFilter:
		command = psmb.CmdMbtcpToggleFilter
	case mbtcpGetFilters:
		command = psmb.CmdMbtcpGetFilters
	case mbtcpDeleteFilters:
		command = psmb.CmdMbtcpDeleteFilters
	case mbtcpToggleFilters:
		command = psmb.CmdMbtcpToggleFilters
	case mbtcpImportFilters:
		command = psmb.CmdMbtcpImportFilters
	case mbtcpExportFilters:
		command = psmb.CmdMbtcpExportFilters
	default:
		conf.Log.Warn("Unsupported request")
		return
	}

	// add msgid to idmap
	idMap.Lock()
	idMap.m[timestamp] = topics[4]
	idMap.Unlock()

	// send to backend worker {cmd, payload, msg id} via channel
	chanRequest <- [3]string{command, payload, timestamp}
}

// sendResponse publish response message to upfront
func sendResponse(client MQTT.Client, topic string, payload string, qos byte, retained bool) {
	conf.Log.WithFields(conf.Fields{
		"topic":   topic,
		"qos":     qos,
		"payload": payload,
	}).Debug("publish to broker")

	token := client.Publish(topic, qos, retained, payload)
	token.Wait()
}

// sendErrorResponse publish error response message to upfront
func sendErrorResponse(client MQTT.Client, cmd string, msgid string, reason string, retained bool) {
	topic := fmt.Sprintf("%s/mbtcp/%s/sub/%s", options.ClientID, cmd, msgid)
	payload := fmt.Sprintf("{'status': '%s'}", reason)
	sendResponse(client, topic, payload, pubQos, retained)
}
