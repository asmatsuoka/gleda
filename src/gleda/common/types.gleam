pub type StageId {
  StageId(String)
}

pub type StageConfig {
  StageConfig(name: String, queue_capacity: Int, worker_count: Int)
}

pub type QueueSubmissionResult {
  Accepted
  Full
}

pub type HandlerOutcome(command, result, reason) {
  Completed(result: result)
  Failed(reason: reason)
  Routed(command: command, target: StageId)
}

pub type StageReply(result, reason) {
  CompletedReply(result: result)
  FailedReply(reason: reason)
  RoutingUnavailable(target: StageId)
}

// Error Type
pub type Error {
  InvalidConfiguration
  StageStartFailure
  WorkerStartFailure
}
