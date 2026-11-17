import gleam/erlang/process
import gleda/common/types.{
  type StageConfig, Accepted, Completed, CompletedReply, Routed,
  RoutingUnavailable, StageConfig, StageId,
}
import gleda/stage

fn test_config(name: String) -> StageConfig {
  StageConfig(name: name, queue_capacity: 10, worker_count: 2)
}

pub fn stage_processes_events_test() {
  let assert Ok(stage) =
    stage.start_stage(
      StageId("test-stage"),
      test_config("test-stage-config"),
      fn(command) { Completed(command <> "-processed") },
    )

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
  let config = StageConfig(..test_config("test-stage-config"), worker_count: 1)

  let assert Ok(_) =
    stage.start_stage(StageId("test-stage-single-worker"), config, fn(command) {
      Completed(command)
    })

  Nil
}

pub fn stage_rejects_invalid_configuration_test() {
  let invalid_config =
    StageConfig(..test_config("test-stage-config"), queue_capacity: 0)

  let assert Error(_) =
    stage.start_stage(
      StageId("invalid-queue-stage"),
      invalid_config,
      fn(command) { Completed(command) },
    )

  let invalid_config =
    StageConfig(..test_config("test-stage-config"), worker_count: 0)

  let assert Error(_) =
    stage.start_stage(
      StageId("invalid-worker-stage"),
      invalid_config,
      fn(command) { Completed(command) },
    )

  let invalid_config = StageConfig(..test_config("test-stage-config"), name: "")

  let assert Error(_) =
    stage.start_stage(
      StageId("invalid-name-stage"),
      invalid_config,
      fn(command) { Completed(command) },
    )

  Nil
}

pub fn stage_routes_command_to_target_stage_test() {
  let stage_a_id = StageId("stage-1")
  let stage_b_id = StageId("stage-2")

  let assert Ok(stage_a) =
    stage.start_stage(stage_a_id, test_config("stage-a"), fn(command) {
      Routed(command <> "-routed", stage_b_id)
    })

  let assert Ok(stage_b) =
    stage.start_stage(stage_b_id, test_config("stage-b"), fn(command) {
      Completed(command <> "-completed")
    })

  stage.connect(stage_a, stage_b_id, stage_b)

  let reply_subject = process.new_subject()

  let assert Accepted = stage.submit(stage_a, "command", reply_subject)
  let assert Ok(CompletedReply("command-routed-completed")) =
    process.receive(reply_subject, within: 1000)

  Nil
}

pub fn stage_returns_error_for_missing_route_test() {
  let stage_a_id = StageId("stage-1")
  let stage_b_id = StageId("stage-2")

  let assert Ok(stage_a) =
    stage.start_stage(stage_a_id, test_config("stage-a"), fn(command) {
      Routed(command <> "-routed", stage_b_id)
    })

  let reply_subject = process.new_subject()

  let assert Accepted = stage.submit(stage_a, "command", reply_subject)

  let assert Ok(RoutingUnavailable(_stage_b_id)) =
    process.receive(reply_subject, within: 1000)

  Nil
}

pub fn stage_replaces_existing_route_test() {
  let stage_a_id = StageId("stage-a-replace")
  let stage_b_id = StageId("stage-b-replace")

  let assert Ok(stage_a) =
    stage.start_stage(stage_a_id, test_config("stage-a-replace"), fn(command) {
      Routed(command, stage_b_id)
    })

  let assert Ok(stage_b_old) =
    stage.start_stage(stage_b_id, test_config("stage-b-old"), fn(command) {
      Completed("old-" <> command)
    })

  let assert Ok(stage_b_new) =
    stage.start_stage(stage_b_id, test_config("stage-b-new"), fn(command) {
      Completed("new-" <> command)
    })

  stage.connect(stage_a, stage_b_id, stage_b_old)
  stage.connect(stage_a, stage_b_id, stage_b_new)

  let reply_subject = process.new_subject()

  let assert Accepted = stage.submit(stage_a, "command", reply_subject)

  let assert Ok(CompletedReply("new-command")) =
    process.receive(reply_subject, within: 1000)

  Nil
}
