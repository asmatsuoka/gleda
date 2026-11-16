import gleam/erlang/process

pub type StageMessage(event) {

  // Worker related messages
  RegisterWorker(
    worker_id: Int,
    worker: process.Subject(WorkerMessage(event)),
    reply_to: process.Subject(Nil),
  )
  WorkerStopped(worker_id: Int)
  WorkerCompleted(worker_id: Int, result: event)
}

pub type WorkerMessage(event) {
  Work(event)
  Stop
}
