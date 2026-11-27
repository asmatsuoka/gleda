import demo/entities/orders/order_json
import gleam/json
import gleda/common/types.{type HandlerOutcome, Failed, Routed}

pub fn parser_handler(
  next_stage_id: types.StageId,
) -> fn(String) -> HandlerOutcome(String, String, String) {
  fn(command: String) -> HandlerOutcome(String, String, String) {
    case json.parse(from: command, using: order_json.order_decoder()) {
      Error(_) -> Failed("ParserHandler Error: Invalid order JSON")
      Ok(order) -> Routed(order_json.serialize_json_order(order), next_stage_id)
    }
  }
}
