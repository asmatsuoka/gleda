import demo/application
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleda/common/types.{Accepted, CompletedReply, Full}
import gleda/stage

pub fn main() {
  let assert Ok(app) = application.start()

  let order_ids =
    int.range(from: 1, to: 501, with: [], run: list.prepend) |> list.reverse

  let submissions =
    list.map(order_ids, fn(order_id) {
      let reply_subject = process.new_subject()
      let order =
        "{\"id\":\"ORD-"
        <> string.pad_start(int.to_string(order_id), 4, "0")
        <> "\",\"unit_price\":100,\"quantity\":3}"

      case stage.submit(app.parser, order, reply_subject) {
        Accepted -> {
          io.println(
            "Submitted order "
            <> string.pad_start(int.to_string(order_id), 4, "0"),
          )
          Ok(reply_subject)
        }
        Full -> {
          io.println(
            "Queue full for order "
            <> string.pad_start(int.to_string(order_id), 4, "0"),
          )
          Error(Nil)
        }
      }
    })

  let accepted_subject_list =
    list.filter_map(submissions, fn(submission) {
      result.map(submission, fn(subject) { subject })
    })

  let result_list =
    list.map(accepted_subject_list, fn(subject) {
      process.receive(subject, within: 10)
    })

  let completed_list =
    list.filter(result_list, fn(reply) {
      case reply {
        Ok(CompletedReply(_)) -> True
        _ -> False
      }
    })

  io.println("Accepted: " <> int.to_string(list.length(accepted_subject_list)))

  io.println("Completed: " <> int.to_string(list.length(completed_list)))

  io.println(
    "Failed: "
    <> int.to_string(list.length(result_list) - list.length(completed_list)),
  )
}
