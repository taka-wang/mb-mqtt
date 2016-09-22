package worker

// dataSource
const (
	_ dataSource = iota
	upstream
	downstream
)

// [worker]
const (
	statusOK          = "ok"
	keyWorkerPub      = "worker.pub"
	keyWorkerSub      = "worker.sub"
	keyResTimeout     = "worker.timeout"
	keyMaxWorker      = "worker.max_worker"
	keyMaxQueue       = "worker.max_queue"
	defaultResTimeout = 1000
	defaultWorkerPub  = "ipc:///tmp/to.psmb"
	defaultWorkerSub  = "ipc:///tmp/from.psmb"
	defaultMaxWorker  = 6
	defaultMaxQueue   = 100
)
