import demo/application
import gleam/erlang/process
import gleam/io
import gleda/common/types.{
  Accepted, CompletedReply, FailedReply, Full, RouteNotFound, RouteQueueFull,
  StageId,
}
import gleda/stage

pub fn main() {
  let assert Ok(app) = application.start()

  io.println("Gleda application demo started successfully!")

  let reply_subject = process.new_subject()
  case stage.submit(app.parser, "test-message", reply_subject) {
    Accepted -> {
      io.println("Message accepted in Queue.")

      case process.receive(reply_subject, within: 5000) {
        Ok(CompletedReply(result)) ->
          io.println("Processing complete: " <> result)
        Ok(FailedReply(reason)) ->
          io.println_error("Processing failed: " <> reason)
        Ok(RouteNotFound(route_stage_id)) ->
          case route_stage_id {
            StageId(stage_id) ->
              io.println("Could not find Route: " <> stage_id)
          }
        Ok(RouteQueueFull(route_stage_id)) -> {
          case route_stage_id {
            StageId(stage_id) ->
              io.println("Target stage queue is full: " <> stage_id)
          }
        }
        Error(_) -> io.println_error("Error while processing message!")
      }
    }
    Full -> io.println("Queue was already full.")
  }
}
