// Package worker a zmq backend worker queue
//
// By taka@cmwang.net
//
package worker

import (
	"encoding/json"
	"strconv"
	"sync"
	"time"

	"github.com/taka-wang/psmb"
	"github.com/taka-wang/psmb/viper-conf"
	zmq "github.com/takawang/zmq3"
)

type (

	// dataSource data source: upstream or zmq
	dataSource int

	// job
	job struct {
		source  dataSource
		cmd     string
		payload string
	}

	// worker in worker pool
	worker struct {
		id      int
		service *Service
	}

	// Service service
	Service struct {
		sync.RWMutex
		// jobChan job channel
		jobChan chan job
		// pub ZMQ publisher endpoints
		pub *zmq.Socket
		// sub ZMQ subscriber endpoints
		sub *zmq.Socket
		// isRunning running flag
		isRunning bool
		// isStopped stop channel
		isStopped chan bool
		// chanRequest request message channel
		chanRequest chan [3]string
		// chanResponse message channel
		chanResponse chan [3]string
	}
)

var (
	// pubEndpoint zmq pub endpoint
	pubEndpoint string
	// subEndpoint zmq sub endpoint
	subEndpoint string
	// maxQueueSize the size of job queue
	maxQueueSize int
	// maxWorkers the number of workers to start
	maxWorkers int
	// timeout zmq timeout in ms
	zmqTimeout time.Duration
)

func setDefaults() {
	conf.SetDefault(keyWorkerPub, defaultWorkerPub)
	conf.SetDefault(keyWorkerSub, defaultWorkerSub)
	conf.SetDefault(keyResTimeout, defaultResTimeout)
	conf.SetDefault(keyMaxWorker, defaultMaxWorker)
	conf.SetDefault(keyMaxQueue, defaultMaxQueue)
}

func init() {
	// set default values
	setDefaults()

	// get init values from config file
	pubEndpoint = conf.GetString(keyWorkerPub)
	subEndpoint = conf.GetString(keyWorkerSub)
	maxWorkers = conf.GetInt(keyMaxWorker)
	maxQueueSize = conf.GetInt(keyMaxQueue)
	zmqTimeout = conf.GetDuration(keyResTimeout)
}

// NewService create service
func NewService() (*Service, error) {
	sender, err := zmq.NewSocket(zmq.PUB)
	if err != nil {
		conf.Log.WithError(err).Error("Fail to create sender")
		return nil, err
	}

	receiver, err := zmq.NewSocket(zmq.SUB)
	if err != nil {
		conf.Log.WithError(err).Error("Fail to create receiver")
		return nil, err
	}

	return &Service{
		isRunning:    false,
		pub:          sender,
		sub:          receiver,
		isStopped:    make(chan bool),
		chanRequest:  nil,
		chanResponse: nil,
	}, nil
}

func (b *Service) setChannels(req, resp chan [3]string) {
	b.chanRequest = req
	b.chanResponse = resp
}

// Start start service
func (b *Service) start() {
	b.Lock()
	defer b.Unlock()

	conf.Log.Debug("Start Worker Queue")

	if b.chanRequest == nil {
		conf.Log.Fatal("No request channel existed!")
		return
	}

	if b.chanResponse == nil {
		conf.Log.Fatal("No response channel existed!")
		return
	}

	// only start the service if it hasn't been started yet.
	if b.isRunning {
		conf.Log.Warn("Already Running")
		return
	}

	b.isRunning = true
	b.startZMQ()

	// init the job channel
	b.jobChan = make(chan job, maxQueueSize)

	// create workers
	for i := 0; i < maxWorkers; i++ {
		w := worker{i, b}
		go func(w worker) {
			for j := range b.jobChan {
				w.process(j)
			}
		}(w)
	}

	// start listening
	ticker := time.NewTicker(200 * time.Millisecond)
	go func() {
		for {
			select {
			case <-b.isStopped:
				b.isRunning = false
				return
			case req := <-b.chanRequest:
				conf.Log.WithFields(conf.Fields{
					"cmd":     req[0],
					"payload": req[1],
					"tid":     req[2],
				}).Debug("Recv request from upstream")
				b.dispatch(upstream, req[0], req[1]) // send to worker queue
			case <-ticker.C:
				if b.isRunning {
					if msg, err := b.sub.RecvMessage(zmq.DONTWAIT); err == nil {
						if len(msg) == 2 {
							conf.Log.WithFields(conf.Fields{
								"cmd":     msg[0],
								"payload": msg[1],
							}).Debug("Recv response from psmb")
							b.dispatch(downstream, msg[0], msg[1]) // send to worker queue
						} else {
							conf.Log.WithField("msg", msg).Error(ErrInvalidMessageLength.Error())
						}
					}
					//conf.Log.Debug("waiting..")
				}
			}
		}
	}()
}

func (b *Service) stop() {
	b.Lock()
	defer b.Unlock()

	conf.Log.Debug("Stop Worker Queue")

	if b.isRunning {
		b.isStopped <- true
		b.stopZMQ()
		close(b.jobChan) // close job channel and wait for workers to complete
	}
}

func (b *Service) stopZMQ() {
	conf.Log.Debug("Stop ZMQ")
	if err := b.pub.Disconnect(pubEndpoint); err != nil {
		conf.Log.WithError(err).Debug("Fail to disconnect from publisher endpoint")
	}
	if err := b.sub.Disconnect(subEndpoint); err != nil {
		conf.Log.WithError(err).Debug("Fail to disconnect from subscribe endpoint")
	}
}

func (b *Service) startZMQ() {
	conf.Log.Debug("Start ZMQ")

	// publish to psmb
	if err := b.pub.Connect(pubEndpoint); err != nil {
		conf.Log.WithError(err).Error("Fail to connect to publisher endpoint")
		return
	}
	// subscribe from psmb
	if err := b.sub.Connect(subEndpoint); err != nil {
		conf.Log.WithError(err).Error("Fail to connect to subscriber endpoint")
		return
	}
	// filter
	if err := b.sub.SetSubscribe(""); err != nil {
		conf.Log.WithError(err).Error("Fail to set subscriber's filter")
		return
	}
}

// dispatch create job and push it to the job channel
func (b *Service) dispatch(source dataSource, command, payload string) {
	job := job{source, command, payload}
	go func() {
		b.Lock()
		defer b.Unlock()
		b.jobChan <- job
	}()
}

// process handle request
func (w worker) process(j job) {
	switch j.source {
	case upstream:
		conf.Log.WithFields(conf.Fields{
			"cmd":     j.cmd,
			"payload": j.payload,
		}).Debug("Processing frontend request")
		w.service.sendRequest(j.cmd, j.payload)
	default:
		conf.Log.WithFields(conf.Fields{
			"cmd":     j.cmd,
			"payload": j.payload,
		}).Debug("Processing psmb response")
		w.service.sendResponse(j.cmd, j.payload)
	}
}

func (b *Service) sendRequest(command, payload string) {
	for {
		b.pub.Send(command, zmq.SNDMORE)
		b.pub.Send(payload, 0)
		break
	}
}

func (b *Service) sendResponse(command, payload string) {
	b.Lock()
	defer b.Unlock()

	var timestamp string
	switch command {
	case psmb.CmdMbtcpOnceRead:

		var res psmb.MbtcpReadRes
		if err := json.Unmarshal([]byte(payload), &res); err != nil {
			conf.Log.WithError(err).Error(ErrUnmarshal.Error())
			return
		}

		// check response status
		var resp psmb.MbtcpReadRes
		if res.Status != statusOK {
			resp = psmb.MbtcpReadRes{Status: res.Status}
		} else {
			resp = psmb.MbtcpReadRes{
				Status: res.Status,
				Type:   res.Type,
				Bytes:  res.Bytes,
				Data:   res.Data,
			}
		}

		// send response to frontend
		js, _ := json.Marshal(resp)
		timestamp = strconv.FormatInt(res.Tid, 10)
		b.chanResponse <- [3]string{command, string(js), timestamp}
	case psmb.CmdMbtcpOnceWrite:
		// unmarshal response from psmb
		var res psmb.MbtcpSimpleRes
		if err := json.Unmarshal([]byte(payload), &res); err != nil {
			conf.Log.WithError(err).Error(ErrUnmarshal.Error())
			return
		}

		resp := psmb.MbtcpSimpleRes{Status: res.Status}

		// send response to frontend
		js, _ := json.Marshal(resp)
		timestamp = strconv.FormatInt(res.Tid, 10)
		b.chanResponse <- [3]string{command, string(js), timestamp}
	case psmb.CmdMbtcpSetTimeout:
		// unmarshal response from psmb
		var res psmb.MbtcpTimeoutRes
		if err := json.Unmarshal([]byte(payload), &res); err != nil {
			conf.Log.WithError(err).Error(ErrUnmarshal.Error())
			return
		}

		resp := psmb.MbtcpSimpleRes{Status: res.Status}

		// send response to frontend
		js, _ := json.Marshal(resp)
		timestamp = strconv.FormatInt(res.Tid, 10)
		b.chanResponse <- [3]string{command, string(js), timestamp}
	case psmb.CmdMbtcpGetTimeout:
		// unmarshal response from psmb
		var res psmb.MbtcpTimeoutRes
		if err := json.Unmarshal([]byte(payload), &res); err != nil {
			conf.Log.WithError(err).Error(ErrUnmarshal.Error())
			return
		}

		// check response status
		var resp psmb.MbtcpTimeoutRes
		if res.Status != statusOK {
			resp = psmb.MbtcpTimeoutRes{Status: res.Status}
		} else {
			resp = psmb.MbtcpTimeoutRes{Status: res.Status, Data: res.Data}
		}
		// send response to frontend
		js, _ := json.Marshal(resp)
		timestamp = strconv.FormatInt(res.Tid, 10)
		b.chanResponse <- [3]string{command, string(js), timestamp}
	default:
		conf.Log.Warn(ErrResponseNotSupport.Error())
	}
}
