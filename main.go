package main

import (
	"os"
	"os/signal"
	"syscall"

	mq "github.com/taka-wang/mb-socket/mqroute"
	"github.com/taka-wang/mb-socket/worker"
)

var (
	mqsrv *mq.Service
)

func main() {

	c := make(chan os.Signal, 2)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-c
		// start cleanup
		mqsrv.Stop()
		// stop cleanup
		os.Exit(0)
	}()

	chanRequest := make(chan [3]string, 100)  // non-blocking
	chanResponse := make(chan [3]string, 100) // non-blocking

	worker.SetChannels(chanRequest, chanResponse)
	worker.Start()
	mqsrv, _ = mq.NewService()
	mqsrv.SetChannels(chanRequest, chanResponse)
	mqsrv.Start()

}
