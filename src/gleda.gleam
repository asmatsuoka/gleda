import demo/application
import gleam/erlang/process
import gleam/io
import gleda/common/types.{
  Accepted, CompletedReply, FailedReply, Full, RouteNotFound, RouteQueueFull,
}
import gleda/stage

pub fn main() {
  let assert Ok(app) = application.start()

  let reply_subject = process.new_subject()

  let order = "{\"id\":\"ORD-0001\",\"unit_price\":100,\"quantity\":3}"

  case stage.submit(app.parser, order, reply_subject) {
    Accepted -> {
      io.println("Order accepted!")

      case process.receive(reply_subject, within: 5000) {
        Ok(CompletedReply(result)) -> io.println("Order processed:" <> result)
        Ok(FailedReply(reason)) -> io.println_error("Order failed: " <> reason)
        Ok(RouteNotFound(_)) -> io.println_error("Route not found")
        Ok(RouteQueueFull(_)) -> io.println("Target queue full")
        Error(_) -> io.println_error("Processing error")
      }
    }
    Full -> io.println("Initial Staged queue is full")
  }
}
