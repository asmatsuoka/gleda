import gleam/erlang/process
import gleam/otp/actor
import gleda/common/internal/protocol.{
  type StageMessage, type WorkerMessage, Stop, Work, WorkerCompleted,
  WorkerStopped,
}
import gleda/common/types.{type Error, WorkerStartFailure}

// Worker Type
pub type Worker(event) {
  Worker(id: Int, subject: process.Subject(WorkerMessage(event)))
}

// Worker State Type
type WorkerState(event) {
  WorkerState(
    id: Int,
    stage: process.Subject(StageMessage(event)),
    handler: fn(event) -> event,
  )
}

// Start a new Worker as an Actor
pub fn start_worker(
  id: Int,
  stage: process.Subject(StageMessage(event)),
  handler: fn(event) -> event,
) -> Result(Worker(event), Error) {
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

pub fn work(worker: Worker(event), event: event) -> Nil {
  process.send(worker.subject, Work(event))
}

pub fn stop(worker: Worker(event)) -> Nil {
  process.send(worker.subject, Stop)
}

pub fn get_id(worker: Worker(event)) -> Int {
  worker.id
}

// Handle incoming messages for the Worker Actor. If the message is a Work event, it will call the handler function and continue processing
fn handle_message(
  state: WorkerState(event),
  message: WorkerMessage(event),
) -> actor.Next(WorkerState(event), WorkerMessage(event)) {
  case message {
    Work(event) -> {
      let result = state.handler(event)
      process.send(state.stage, WorkerCompleted(state.id, result))
      actor.continue(state)
    }
    Stop -> {
      process.send(state.stage, WorkerStopped(state.id))
      actor.stop()
    }
  }
}
