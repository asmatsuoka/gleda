import gleam/erlang/process
import gleda/common/internal/protocol.{WorkerCompleted, WorkerStopped}
import gleda/worker

pub fn worker_processes_event_test() {
  let stage_subject = process.new_subject()

  let assert Ok(worker) =
    worker.start_worker(1, stage_subject, fn(event) { event <> "-processed" })

  worker.work(worker, "test-event")

  let assert Ok(WorkerCompleted(1, "test-event-processed")) =
    process.receive(stage_subject, within: 1000)
}

pub fn worker_stop_test() {
  let stage_subject = process.new_subject()

  let assert Ok(worker) =
    worker.start_worker(1, stage_subject, fn(event) { event <> "-processed" })

  worker.stop(worker)

  let assert Ok(WorkerStopped(1)) = process.receive(stage_subject, within: 1000)
}
