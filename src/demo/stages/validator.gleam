import demo/entities/orders/order_json
import gleam/json
import gleda/common/types.{type HandlerOutcome, Failed, Routed}

pub fn validator_handler(
  next_stage_id: types.StageId,
) -> fn(String) -> HandlerOutcome(String, String, String) {
  fn(command: String) -> HandlerOutcome(String, String, String) {
    case json.parse(from: command, using: order_json.order_decoder()) {
      Error(_) -> Failed("ValidatorHandler Error: Invalid order JSON")
      Ok(order) -> {
        case order.unit_price, order.quantity {
          u, _ if u <= 0 ->
            Failed(
              "ValidatorHandler Error: Unit Price has to be Greater than 0.",
            )
          _, q if q <= 0 ->
            Failed("ValidatorHandler Error: Quantity has to be Greater than 0.")
          _, _ -> Routed(order_json.serialize_json_order(order), next_stage_id)
        }
      }
    }
  }
}
