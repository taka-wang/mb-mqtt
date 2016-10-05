package mqroute

import (
	"fmt"
	"testing"
	"time"

	MQTT "github.com/eclipse/paho.mqtt.golang"
	"github.com/takawang/sugar"
)

var (
	chanReq, chanResp chan [3]string
	opts              *MQTT.ClientOptions
	client            MQTT.Client
)

func init() {
	chanReq = make(chan [3]string, 100)  // non-blocking
	chanResp = make(chan [3]string, 100) // non-blocking
	// tester
	opts := MQTT.NewClientOptions().AddBroker(brokerURL).SetClientID("hello-12345").SetCleanSession(true)
	client = MQTT.NewClient(opts)
}

func TestSubscribe(t *testing.T) {
	s := sugar.New(t)
	s.Assert("Test receive from frontend", func(logf sugar.Log) bool {

		mqsrv, _ := NewService()
		mqsrv.SetChannels(chanReq, chanResp)
		go mqsrv.Start()
		time.Sleep(time.Duration(1000) * time.Millisecond)

		// pub
		if token := client.Connect(); token.Wait() && token.Error() != nil {
			return false
		}

		done := make(chan bool, 1)

		go func() {
			//fmt.Println(msg)
			req := <-chanReq
			fmt.Println(req)
			time.Sleep(time.Duration(500) * time.Millisecond)
			done <- true
		}()

		token := client.Publish("mydevice01/mbtcp/timeout.read/pub/1234512132", 2, false, "hello world")
		token.Wait()
		//token2 := client.Publish("mydevice01/mbtcp/timeout.update/pub/1234512132", 2, false, `{ "timeout": 210000 }`)
		//token2.Wait()
		//time.Sleep(time.Duration(100) * time.Millisecond)

		ok := <-done
		//
		// cleanup
		//client.Disconnect(250)
		mqsrv.Stop()
		return ok
	})
}
