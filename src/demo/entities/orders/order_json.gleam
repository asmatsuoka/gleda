import demo/entities/orders/order_types.{type Order, Order}
import gleam/dynamic/decode
import gleam/json

pub fn order_decoder() -> decode.Decoder(Order) {
  use id <- decode.field("id", decode.string)
  use unit_price <- decode.field("unit_price", decode.int)
  use quantity <- decode.field("quantity", decode.int)

  decode.success(Order(id: id, unit_price: unit_price, quantity: quantity))
}

pub fn serialize_json_order(order: Order) -> String {
  json.object([
    #("id", json.string(order.id)),
    #("unit_price", json.int(order.unit_price)),
    #("quantity", json.int(order.quantity)),
  ])
  |> json.to_string
}
