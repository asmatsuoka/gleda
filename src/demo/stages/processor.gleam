import demo/entities/orders/order_json
import demo/entities/orders/order_repository
import demo/entities/orders/order_types.{type Order}
import gleam/json
import gleda/common/types.{type HandlerOutcome, Completed, Failed}
import pog

pub fn processor_handler(
  db: pog.Connection,
) -> fn(String) -> HandlerOutcome(String, String, String) {
  fn(command: String) -> HandlerOutcome(String, String, String) {
    case json.parse(from: command, using: order_json.order_decoder()) {
      Error(_) -> Failed("ProcessorHandler Error: Invalid order JSON")
      Ok(order) ->
        case order_repository.create_order(db, command) {
          Error(_) ->
            Failed(
              "ProcessorHandler Error: Error while inserting into database",
            )
          Ok(Nil) -> Completed(serialize_json_processor_result(order))
        }
    }
  }
}

fn serialize_json_processor_result(order: Order) -> String {
  json.object([
    #("order_id", json.string(order.id)),
    #("total_price", json.int(order.unit_price * order.quantity)),
  ])
  |> json.to_string
}
