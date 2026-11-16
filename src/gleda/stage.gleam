import gleam/erlang/process
import gleam/list
import gleam/option
import gleam/otp/actor
import gleda/common/internal/protocol.{
  type StageMessage, RegisterWorker, Submit, Work, WorkerCompleted,
  WorkerStopped,
}
import gleda/common/types.{
  type Error, type StageConfig, type StageId, type SubmissionResult, Accepted,
  InvalidConfiguration, QueueFull, StageStartFailure,
}
import gleda/queue
import gleda/worker

pub opaque type Stage(event) {
  Stage(subject: process.Subject(StageMessage(event)))
}

type State(event) {
  State(
    stage_id: StageId,
    queue: queue.Queue(event),
    workers: List(worker.Worker(event)),
    available_workers: List(worker.Worker(event)),
    stopped_worker_ids: List(Int),
  )
}

pub fn start_stage(
  id: StageId,
  config: StageConfig,
  handler: fn(event) -> event,
) -> Result(Stage(event), Error) {
  case
    config.queue_capacity > 0 && config.worker_count > 0 && config.name != ""
  {
    False -> Error(InvalidConfiguration)
    True -> {
      let assert Ok(queue) = queue.new(config.queue_capacity)

      let initial_state =
        State(
          stage_id: id,
          queue: queue,
          workers: [],
          available_workers: [],
          stopped_worker_ids: [],
        )

      case
        actor.new(initial_state)
        |> actor.on_message(handle_message)
        |> actor.start()
      {
        Error(_) -> Error(StageStartFailure)
        Ok(started) -> {
          let stage_subject = started.data
          case
            register_workers(1, stage_subject, config.worker_count, handler)
          {
            Error(error) -> Error(error)
            Ok(Nil) -> Ok(Stage(subject: stage_subject))
          }
        }
      }
    }
  }
}

pub fn submit(stage: Stage(event), event: event) -> SubmissionResult {
  process.call(stage.subject, 5000, fn(reply_to) {
    Submit(event: event, reply_to: reply_to)
  })
}

fn handle_message(
  state: State(event),
  message: StageMessage(event),
) -> actor.Next(State(event), StageMessage(event)) {
  case message {
    RegisterWorker(worker_id, worker_subject, reply_to) -> {
      let w = worker.Worker(worker_id, worker_subject)
      process.send(reply_to, Nil)
      actor.continue(
        State(..state, workers: [w, ..state.workers], available_workers: [
          w,
          ..state.available_workers
        ]),
      )
    }
    Submit(event, reply_to) -> {
      case queue.push(state.queue, event) {
        queue.Full -> {
          process.send(reply_to, QueueFull)
          actor.continue(state)
        }
        queue.Accepted(updated_queue) -> {
          process.send(reply_to, Accepted)
          let updated_state = State(..state, queue: updated_queue)

          actor.continue(dispatch(updated_state))
        }
      }
    }

    WorkerStopped(worker_id) -> {
      case find_state_worker(worker_id, state.workers) {
        option.None -> actor.continue(state)
        option.Some(_) -> {
          case !list.contains(state.stopped_worker_ids, worker_id) {
            False -> actor.continue(state)
            True -> {
              let updated_state = {
                State(..state, stopped_worker_ids: [
                  worker_id,
                  ..state.stopped_worker_ids
                ])
              }
              actor.continue(updated_state)
            }
          }
        }
      }
    }

    WorkerCompleted(worker_id, _result) -> {
      case find_state_worker(worker_id, state.workers) {
        option.None -> actor.continue(state)
        option.Some(worker) -> {
          let updated_state =
            State(..state, available_workers: [
              worker,
              ..state.available_workers
            ])
          actor.continue(dispatch(updated_state))
        }
      }
    }
  }
}

fn register_workers(
  worker_id: Int,
  stage_subject: process.Subject(StageMessage(event)),
  count: Int,
  handler: fn(event) -> event,
) -> Result(Nil, Error) {
  case count > 0 {
    False -> Ok(Nil)
    True -> {
      case worker.start_worker(worker_id, stage_subject, handler) {
        Error(error) -> Error(error)
        Ok(worker) -> {
          process.call(stage_subject, 5000, fn(reply_to) {
            RegisterWorker(worker_id, worker.subject, reply_to)
          })
          register_workers(worker_id + 1, stage_subject, count - 1, handler)
        }
      }
    }
  }
}

fn dispatch(state: State(event)) -> State(event) {
  case state.available_workers {
    [] -> state
    [worker, ..remaining_workers] -> {
      let #(next_item, updated_queue) = queue.pop(state.queue)

      case next_item {
        option.None -> state
        option.Some(queued) -> {
          process.send(worker.subject, Work(queued))
          dispatch(
            State(
              ..state,
              queue: updated_queue,
              available_workers: remaining_workers,
            ),
          )
        }
      }
    }
  }
}

fn find_state_worker(
  id: Int,
  workers: List(worker.Worker(event)),
) -> option.Option(worker.Worker(event)) {
  case workers {
    [] -> option.None
    [worker, ..tail] -> {
      case worker.id == id {
        True -> option.Some(worker)
        False -> find_state_worker(id, tail)
      }
    }
  }
}
