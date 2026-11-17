import gleam/erlang/process
import gleda/common/types.{
  type HandlerOutcome, type QueueSubmissionResult, type StageId, type StageReply,
}

pub type StageMessage(command, result, reason) {
  Submit(
    command: command,
    queue_submission_reply_to: process.Subject(QueueSubmissionResult),
    result_reply_to: process.Subject(StageReply(result, reason)),
  )

  // Routing / Forwarding Stage by Stage
  RegisterRoute(
    target_id: StageId,
    target_subject: process.Subject(StageMessage(command, result, reason)),
    result_reply_to: process.Subject(Nil),
  )

  Route(
    command: command,
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
