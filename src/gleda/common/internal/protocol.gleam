import gleam/erlang/process
import gleda/common/types.{type SubmissionResult}

pub type StageMessage(event) {
  Submit(event: event, reply_to: process.Subject(SubmissionResult))

  // Worker related messages
  RegisterWorker(
    worker_id: Int,
    worker_subject: process.Subject(WorkerMessage(event)),
  )
  WorkerStopped(worker_id: Int)
  WorkerCompleted(worker_id: Int, result: event)
}

pub type WorkerMessage(event) {
  Work(event)
  Stop
}
