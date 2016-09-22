// Package worker a zmq backend worker queue
//
// By taka@cmwang.net
//
package worker

var defaultSrv, _ = NewService()

/*
// RequestHandler http request handler
func RequestHandler(ts int64, command, payload string, w http.ResponseWriter) {
	(*defaultSrv).requestHandler(ts, command, payload, w)
}
*/

// SetChannels set request and response channels
func SetChannels(req, resp chan [3]string) {
	(*defaultSrv).setChannels(req, resp)
}

// Start start service
func Start() {
	(*defaultSrv).start()
}

// Stop stop service
func Stop() {
	(*defaultSrv).stop()
}
