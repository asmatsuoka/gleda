import gleam/erlang/process
import gleda/common/types.{
  type HandlerOutcome, type QueueSubmissionResult, type StageReply,
}

pub type StageMessage(command, result, reason) {
  Submit(
    event: command,
    queue_submission_reply_to: process.Subject(QueueSubmissionResult),
    result_reply_to: process.Subject(StageReply(result, reason)),
  )

  // Worker related messages
  RegisterWorker(
    worker_id: Int,
    worker_subject: process.Subject(WorkerMessage(command, result, reason)),
    queue_submission_reply_to: process.Subject(Nil),
  )

  WorkerStopped(worker_id: Int)

  WorkerCompleted(
    worker_id: Int,
    outcome: HandlerOutcome(command, result, reason),
    result_reply_to: process.Subject(StageReply(result, reason)),
  )
}

pub type WorkerMessage(command, result, reason) {
  Work(
    command: command,
    result_reply_to: process.Subject(StageReply(result, reason)),
  )
  Stop
}
