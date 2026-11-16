pub type StageId {
  StageId(String)
}

pub type StageConfig {
  StageConfig(name: String, queue_capacity: Int, worker_count: Int)
}

pub type SubmissionResult {
  Accepted
  QueueFull
  StageUnavailable
}

// Error Type
pub type Error {
  InvalidConfiguration
  StageStartFailure
  WorkerStartFailure
}
