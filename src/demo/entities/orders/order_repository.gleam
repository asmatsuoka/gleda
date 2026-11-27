import gleam/result
import pog

pub fn create_order(
  db: pog.Connection,
  order_json: String,
) -> Result(Nil, pog.QueryError) {
  pog.query("insert into orders (payload) values ($1)")
  |> pog.parameter(pog.text(order_json))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
}
