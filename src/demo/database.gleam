import gleam/erlang/process
import gleam/option
import pog

pub fn start() -> process.Name(pog.Message) {
  let pool_name = process.new_name("application_db")
  let db_config =
    pog.default_config(pool_name)
    |> pog.host("localhost")
    |> pog.port(5432)
    |> pog.database("demo_db")
    |> pog.user("postgres")
    |> pog.password(option.Some("postgres"))
    |> pog.pool_size(10)
  let assert Ok(_) = pog.start(db_config)

  pool_name
}

pub fn connection(pool_name: process.Name(pog.Message)) -> pog.Connection {
  pog.named_connection(pool_name)
}
