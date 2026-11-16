//import gleam/erlang/process
import gleda/common/types.{type StageConfig, Accepted, StageConfig, StageId}
import gleda/stage

fn test_config() -> StageConfig {
  StageConfig(name: "test-stage-config", queue_capacity: 10, worker_count: 2)
}

pub fn stage_processes_events_test() {
  let assert Ok(stage) =
    stage.start_stage(StageId("test-stage"), test_config(), fn(event) { event })

  let assert Accepted = stage.submit(stage, "event-1")
  let assert Accepted = stage.submit(stage, "event-2")
  let assert Accepted = stage.submit(stage, "event-3")

  Nil
}

pub fn stage_starts_configured_worker_test() {
  let config = StageConfig(..test_config(), worker_count: 1)
  let assert Ok(_) =
    stage.start_stage(StageId("test-stage"), config, fn(event) { event })
  Nil
}

pub fn stage_rejects_invalid_configuration_test() {
  let invalid_config = StageConfig(..test_config(), queue_capacity: 0)
  let assert Error(_) =
    stage.start_stage(StageId("test-stage"), invalid_config, fn(event) { event })

  let invalid_config = StageConfig(..test_config(), worker_count: 0)
  let assert Error(_) =
    stage.start_stage(StageId("test-stage"), invalid_config, fn(event) { event })

  let invalid_config = StageConfig(..test_config(), name: "")
  let assert Error(_) =
    stage.start_stage(StageId("test-stage"), invalid_config, fn(event) { event })

  Nil
}
