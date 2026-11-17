import gleam/erlang/process
import gleam/otp/actor
import gleda/common/internal/protocol.{
  type StageMessage, type WorkerMessage, Stop, Work, WorkerCompleted,
  WorkerStopped,
}
import gleda/common/types.{
  type Error, type HandlerOutcome, type StageReply, WorkerStartFailure,
}

// Worker Type
pub type Worker(command, result, reason) {
  Worker(
    id: Int,
    subject: process.Subject(WorkerMessage(command, result, reason)),
  )
}

// Worker State Type
type WorkerState(command, result, reason) {
  WorkerState(
    id: Int,
    stage: process.Subject(StageMessage(command, result, reason)),
    handler: fn(command) -> HandlerOutcome(command, result, reason),
  )
}

// Start a new Worker as an Actor
pub fn start_worker(
  id: Int,
  stage: process.Subject(StageMessage(command, result, reason)),
  handler: fn(command) -> HandlerOutcome(command, result, reason),
) -> Result(Worker(command, result, reason), Error) {
  let initial_state = WorkerState(id, stage, handler)

  case
    actor.new(initial_state)
    |> actor.on_message(handle_message)
    |> actor.start()
  {
    Ok(started_actor) -> Ok(Worker(id: id, subject: started_actor.data))
    Error(_) -> Error(WorkerStartFailure)
  }
}

pub fn work(
  worker: Worker(command, result, reason),
  command: command,
  reply_to: process.Subject(StageReply(result, reason)),
) -> Nil {
  process.send(worker.subject, Work(command, reply_to))
}

pub fn stop(worker: Worker(command, result, reason)) -> Nil {
  process.send(worker.subject, Stop)
}

pub fn get_id(worker: Worker(command, result, reason)) -> Int {
  worker.id
}

fn handle_message(
  state: WorkerState(command, result, reason),
  message: WorkerMessage(command, result, reason),
) -> actor.Next(
  WorkerState(command, result, reason),
  WorkerMessage(command, result, reason),
) {
  case message {
    Work(command, reply_to) -> {
      let outcome = state.handler(command)

      process.send(
        state.stage,
        WorkerCompleted(
          worker_id: state.id,
          outcome: outcome,
          result_reply_to: reply_to,
        ),
      )

      actor.continue(state)
    }

    Stop -> {
      process.send(state.stage, WorkerStopped(state.id))
      actor.stop()
    }
  }
}
