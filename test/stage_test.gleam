import gleam/erlang/process
import gleda/common/types.{
  type StageConfig, Accepted, Completed, CompletedReply, StageConfig, StageId,
}
import gleda/stage

fn test_config() -> StageConfig {
  StageConfig(name: "test-stage-config", queue_capacity: 10, worker_count: 2)
}

pub fn stage_processes_events_test() {
  let assert Ok(stage) =
    stage.start_stage(StageId("test-stage"), test_config(), fn(command) {
      Completed(command <> "-processed")
    })

  let reply_subject = process.new_subject()

  let assert Accepted = stage.submit(stage, "event-1", reply_subject)

  let assert Accepted = stage.submit(stage, "event-2", reply_subject)

  let assert Accepted = stage.submit(stage, "event-3", reply_subject)

  let assert Ok(CompletedReply("event-1-processed")) =
    process.receive(reply_subject, within: 1000)

  let assert Ok(CompletedReply("event-2-processed")) =
    process.receive(reply_subject, within: 1000)

  let assert Ok(CompletedReply("event-3-processed")) =
    process.receive(reply_subject, within: 1000)

  Nil
}

pub fn stage_starts_configured_worker_test() {
  let config = StageConfig(..test_config(), worker_count: 1)

  let assert Ok(_) =
    stage.start_stage(StageId("test-stage-single-worker"), config, fn(command) {
      Completed(command)
    })

  Nil
}

pub fn stage_rejects_invalid_configuration_test() {
  let invalid_config = StageConfig(..test_config(), queue_capacity: 0)

  let assert Error(_) =
    stage.start_stage(
      StageId("invalid-queue-stage"),
      invalid_config,
      fn(command) { Completed(command) },
    )

  let invalid_config = StageConfig(..test_config(), worker_count: 0)

  let assert Error(_) =
    stage.start_stage(
      StageId("invalid-worker-stage"),
      invalid_config,
      fn(command) { Completed(command) },
    )

  let invalid_config = StageConfig(..test_config(), name: "")

  let assert Error(_) =
    stage.start_stage(
      StageId("invalid-name-stage"),
      invalid_config,
      fn(command) { Completed(command) },
    )

  Nil
}
