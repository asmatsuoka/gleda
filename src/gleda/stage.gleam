import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/option
import gleam/otp/actor
import gleda/common/internal/protocol.{
  type StageMessage, RegisterRoute, RegisterWorker, Route, Submit, Work,
  WorkerCompleted, WorkerStopped,
}
import gleda/common/types.{
  type Error, type HandlerOutcome, type QueueSubmissionResult, type StageConfig,
  type StageId, type StageReply, Accepted, Completed, CompletedReply, Failed,
  FailedReply, Full, InvalidConfiguration, RouteNotFound, RouteQueueFull, Routed,
  StageStartFailure,
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
    routes: List(
      #(StageId, process.Subject(StageMessage(command, result, reason))),
    ),
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
          routes: [],
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
      command: command,
      queue_submission_reply_to: reply_to,
      result_reply_to: result_reply_to,
    )
  })
}

pub fn connect(
  source: Stage(command, result, reason),
  target_id: StageId,
  target: Stage(command, result, reason),
) -> Nil {
  process.call(source.subject, 5000, fn(result_reply_to) {
    RegisterRoute(target_id, target.subject, result_reply_to)
  })

  Nil
}

fn handle_message(
  state: StageState(command, result, reason),
  message: StageMessage(command, result, reason),
) -> actor.Next(
  StageState(command, result, reason),
  StageMessage(command, result, reason),
) {
  case message {
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

    RegisterRoute(target_id, target_subject, result_reply_to) -> {
      let updated_routes = case find_state_route(target_id, state.routes) {
        option.None -> {
          [#(target_id, target_subject), ..state.routes]
        }
        option.Some(_) -> {
          replace_state_route(target_id, target_subject, state.routes)
        }
      }
      process.send(result_reply_to, Nil)
      actor.continue(StageState(..state, routes: updated_routes))
    }

    Route(command, result_reply_to) -> {
      case queue.push(state.queue, #(command, result_reply_to)) {
        queue.Full -> {
          let types.StageId(stage_id) = state.stage_id
          io.println("Queue full at stage: " <> stage_id)
          process.send(result_reply_to, RouteQueueFull(state.stage_id))
          actor.continue(state)
        }
        queue.Accepted(updated_queue) -> {
          actor.continue(dispatch(StageState(..state, queue: updated_queue)))
        }
      }
    }

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
      process.send(reply_to, CompletedReply(result))
      state
    }
    Failed(reason) -> {
      process.send(reply_to, FailedReply(reason))
      state
    }
    Routed(command, target_id) -> {
      case find_state_route(target_id, state.routes) {
        option.None -> {
          process.send(reply_to, RouteNotFound(target: target_id))
          state
        }
        option.Some(#(_stage_id, target_subject)) -> {
          process.send(target_subject, Route(command, reply_to))
          state
        }
      }
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

fn find_state_route(
  target_id: StageId,
  routes: List(
    #(StageId, process.Subject(StageMessage(command, result, reason))),
  ),
) -> option.Option(
  #(StageId, process.Subject(StageMessage(command, result, reason))),
) {
  case routes {
    [] -> option.None
    [#(stage_id, subject), ..tail] -> {
      case stage_id == target_id {
        True -> option.Some(#(stage_id, subject))
        False -> find_state_route(target_id, tail)
      }
    }
  }
}

fn replace_state_route(
  target_id: StageId,
  target_subject: process.Subject(StageMessage(command, result, reason)),
  routes: List(
    #(StageId, process.Subject(StageMessage(command, result, reason))),
  ),
) -> List(#(StageId, process.Subject(StageMessage(command, result, reason)))) {
  case routes {
    [] -> [#(target_id, target_subject)]
    [#(id, subject), ..rest] -> {
      case id == target_id {
        True -> [#(target_id, target_subject), ..rest]
        False -> [
          #(id, subject),
          ..replace_state_route(target_id, target_subject, rest)
        ]
      }
    }
  }
}
