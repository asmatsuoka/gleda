import gleam/dynamic/decode
import gleam/json
import gleda/common/types.{
  type Error, type HandlerOutcome, Completed, Failed, Routed, StageId,
}
import gleda/stage

type Order {
  Order(id: String, unit_price: Int, quantity: Int)
}

pub type Application {
  Application(
    parser: stage.Stage(String, String, String),
    validator: stage.Stage(String, String, String),
    processor: stage.Stage(String, String, String),
  )
}

const parser_id = StageId("parser")

const validator_id = StageId("validator")

const processor_id = StageId("enrichment")

pub fn start() -> Result(Application, Error) {
  let assert Ok(processor) =
    stage.start_stage(
      processor_id,
      types.StageConfig(name: "processor", queue_capacity: 100, worker_count: 2),
      processor_handler,
    )

  let assert Ok(validator) =
    stage.start_stage(
      validator_id,
      types.StageConfig(name: "validator", queue_capacity: 100, worker_count: 2),
      validator_handler,
    )

  let assert Ok(parser) =
    stage.start_stage(
      parser_id,
      types.StageConfig(name: "parser", queue_capacity: 100, worker_count: 2),
      parser_handler,
    )

  stage.connect(parser, validator_id, validator)
  stage.connect(validator, processor_id, processor)

  Ok(Application(parser: parser, validator: validator, processor: processor))
}

// stage worker handlers

fn parser_handler(command: String) -> HandlerOutcome(String, String, String) {
  case json.parse(from: command, using: order_decoder()) {
    Error(_) -> Failed("ParserHandler Error: Invalid order JSON")
    Ok(order) -> Routed(serialize_json_order(order), validator_id)
  }
}

fn validator_handler(
  command: String,
) -> HandlerOutcome(String, String, String) {
  case json.parse(from: command, using: order_decoder()) {
    Error(_) -> Failed("ValidatorHandler Error: Invalid order JSON")
    Ok(order) -> {
      case order.unit_price, order.quantity {
        u, _ if u < 0 ->
          Failed("ValidatorHandler Error: Unit Price has to be Greater than 0.")
        _, q if q < 0 ->
          Failed("ValidatorHandler Error: Quantity has to be Greater than 0.")
        _, _ -> Routed(serialize_json_order(order), processor_id)
      }
    }
  }
}

fn processor_handler(
  command: String,
) -> HandlerOutcome(String, String, String) {
  case json.parse(from: command, using: order_decoder()) {
    Error(_) -> Failed("ProcessorHandler Error: Invalid order JSON")
    Ok(order) -> Completed(serialize_json_processor_result(order))
  }
}

// helpers

fn order_decoder() -> decode.Decoder(Order) {
  use id <- decode.field("id", decode.string)
  use unit_price <- decode.field("unit_price", decode.int)
  use quantity <- decode.field("quantity", decode.int)

  decode.success(Order(id: id, unit_price: unit_price, quantity: quantity))
}

fn serialize_json_order(order: Order) -> String {
  json.object([
    #("id", json.string(order.id)),
    #("unit_price", json.int(order.unit_price)),
    #("quantity", json.int(order.quantity)),
  ])
  |> json.to_string
}

fn serialize_json_processor_result(order: Order) -> String {
  json.object([
    #("order_id", json.string(order.id)),
    #("total_price", json.int(order.unit_price * order.quantity)),
  ])
  |> json.to_string
}
