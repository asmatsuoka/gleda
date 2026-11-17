import gleam/erlang/process
import gleda/common/internal/protocol.{WorkerCompleted, WorkerStopped}
import gleda/common/types.{Completed, CompletedReply}
import gleda/worker

pub fn worker_processes_event_test() {
  let stage_subject = process.new_subject()
  let reply_subject = process.new_subject()

  let assert Ok(worker) =
    worker.start_worker(1, stage_subject, fn(command) {
      Completed(command <> "-processed")
    })

  worker.work(worker, "test-event", reply_subject)

  let assert Ok(WorkerCompleted(
    worker_id: 1,
    outcome: Completed("test-event-processed"),
    result_reply_to: received_reply_subject,
  )) = process.receive(stage_subject, within: 1000)

  process.send(received_reply_subject, CompletedReply("test-event-processed"))

  let assert Ok(CompletedReply("test-event-processed")) =
    process.receive(reply_subject, within: 1000)
}

pub fn worker_stop_test() {
  let stage_subject = process.new_subject()

  let assert Ok(worker) =
    worker.start_worker(1, stage_subject, fn(command) {
      Completed(command <> "-processed")
    })

  worker.stop(worker)

  let assert Ok(WorkerStopped(1)) = process.receive(stage_subject, within: 1000)
}
