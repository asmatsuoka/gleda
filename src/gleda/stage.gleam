import gleam/erlang/process
import gleam/list
import gleam/option
import gleam/otp/actor
import gleda/common/internal/protocol.{
  type StageMessage, RegisterWorker, Submit, Work, WorkerCompleted,
  WorkerStopped,
}
import gleda/common/types.{
  type Error, type HandlerOutcome, type QueueSubmissionResult, type StageConfig,
  type StageId, type StageReply, Accepted, Completed, Failed, Forwarded, Full,
  InvalidConfiguration, StageStartFailure,
}
import gleda/queue
import gleda/worker

pub opaque type Stage(command, result, reason) {
  Stage(subject: process.Subject(StageMessage(command, result, reason)))
}

type StageState(command, result, reason) {
  StageState(
    stage_id: StageId,
    queue: queue.Queue(#(command, process.Subject(StageReply(result, reason)))),
    workers: List(worker.Worker(command, result, reason)),
    available_workers: List(worker.Worker(command, result, reason)),
    stopped_worker_ids: List(Int),
  )
}

pub fn start_stage(
  id: StageId,
  config: StageConfig,
  handler: fn(command) -> HandlerOutcome(command, result, reason),
) -> Result(Stage(command, result, reason), Error) {
  case
    config.queue_capacity > 0 && config.worker_count > 0 && config.name != ""
  {
    False -> Error(InvalidConfiguration)
    True -> {
      let assert Ok(queue) = queue.new(config.queue_capacity)

      let initial_state =
        StageState(
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

pub fn submit(
  stage: Stage(command, result, reason),
  command: command,
  result_reply_to: process.Subject(StageReply(result, reason)),
) -> QueueSubmissionResult {
  process.call(stage.subject, 5000, fn(reply_to) {
    Submit(
      event: command,
      queue_submission_reply_to: reply_to,
      result_reply_to: result_reply_to,
    )
  })
}

fn handle_message(
  state: StageState(command, result, reason),
  message: StageMessage(command, result, reason),
) -> actor.Next(
  StageState(command, result, reason),
  StageMessage(command, result, reason),
) {
  case message {
    RegisterWorker(worker_id, worker_subject, reply_to) -> {
      let w = worker.Worker(worker_id, worker_subject)
      process.send(reply_to, Nil)
      actor.continue(
        StageState(..state, workers: [w, ..state.workers], available_workers: [
          w,
          ..state.available_workers
        ]),
      )
    }
    Submit(command, queue_submission_reply_to, result_reply_to) -> {
      case queue.push(state.queue, #(command, result_reply_to)) {
        queue.Full -> {
          process.send(queue_submission_reply_to, Full)
          actor.continue(state)
        }
        queue.Accepted(updated_queue) -> {
          process.send(queue_submission_reply_to, Accepted)
          actor.continue(dispatch(StageState(..state, queue: updated_queue)))
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
                StageState(..state, stopped_worker_ids: [
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

    WorkerCompleted(worker_id, outcome, result_reply_to) -> {
      case find_state_worker(worker_id, state.workers) {
        option.None -> actor.continue(state)
        option.Some(worker) -> {
          actor.continue(
            dispatch(handle_outcome(
              StageState(..state, available_workers: [
                worker,
                ..state.available_workers
              ]),
              outcome,
              result_reply_to,
            )),
          )
        }
      }
    }
  }
}

fn handle_outcome(
  state: StageState(command, result, reason),
  outcome: HandlerOutcome(command, result, reason),
  reply_to: process.Subject(StageReply(result, reason)),
) -> StageState(command, result, reason) {
  case outcome {
    Completed(result) -> {
      process.send(reply_to, types.CompletedReply(result))
      state
    }
    Failed(reason) -> {
      process.send(reply_to, types.FailedReply(reason))
      state
    }
    Forwarded(command, target_id) -> {
      todo
    }
  }
}

fn register_workers(
  worker_id: Int,
  stage_subject: process.Subject(StageMessage(command, result, reason)),
  count: Int,
  handler: fn(command) -> HandlerOutcome(command, result, reason),
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

fn dispatch(
  state: StageState(command, result, reason),
) -> StageState(command, result, reason) {
  case state.available_workers {
    [] -> state
    [worker, ..remaining_workers] -> {
      let #(next_item, updated_queue) = queue.pop(state.queue)

      case next_item {
        option.None -> state
        option.Some(#(command, reply_to)) -> {
          process.send(worker.subject, Work(command, reply_to))
          dispatch(
            StageState(
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
  workers: List(worker.Worker(command, result, reason)),
) -> option.Option(worker.Worker(command, result, reason)) {
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
