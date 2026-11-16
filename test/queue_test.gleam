import gleam/option
import gleda/queue

pub fn queue_creation_test() {
  let assert Ok(q) = queue.new(3)

  let capacity = queue.capacity(q)
  let size = queue.size(q)
  let is_empty = queue.is_empty(q)

  assert capacity == 3
  assert size == 0
  assert is_empty == True

  Nil
}

pub fn queue_push_test() {
  let assert Ok(q) = queue.new(3)

  let assert queue.Accepted(q) = queue.push(q, "A")
  let assert queue.Accepted(q) = queue.push(q, "B")
  let assert queue.Accepted(q) = queue.push(q, "C")

  let assert queue.Full = queue.push(q, "D")

  Nil
}

pub fn queue_pop_test() {
  let assert Ok(q) = queue.new(3)

  let assert queue.Accepted(q) = queue.push(q, "A")
  let assert queue.Accepted(q) = queue.push(q, "B")
  let assert queue.Accepted(q) = queue.push(q, "C")

  let assert #(option.Some("A"), q) = queue.pop(q)
  let assert #(option.Some("B"), q) = queue.pop(q)
  let assert #(option.Some("C"), q) = queue.pop(q)

  let assert #(option.None, _q) = queue.pop(q)

  Nil
}

pub fn queue_push_and_pop_test() {
  let assert Ok(q) = queue.new(3)

  let assert queue.Accepted(q) = queue.push(q, "A")
  let assert queue.Accepted(q) = queue.push(q, "B")

  let assert #(option.Some("A"), q) = queue.pop(q)

  let assert queue.Accepted(q) = queue.push(q, "C")
  let assert queue.Accepted(q) = queue.push(q, "D")

  let assert #(option.Some("B"), q) = queue.pop(q)
  let assert #(option.Some("C"), q) = queue.pop(q)
  let assert #(option.Some("D"), q) = queue.pop(q)

  let assert #(option.None, _q) = queue.pop(q)

  Nil
}

pub fn fifo_test() {
  let assert Ok(q) = queue.new(3)

  let assert queue.Accepted(q) = queue.push(q, "A")
  let assert queue.Accepted(q) = queue.push(q, "B")
  let assert queue.Accepted(q) = queue.push(q, "C")

  let assert queue.Full = queue.push(q, "D")

  let assert #(option.Some("A"), q) = queue.pop(q)
  let assert #(option.Some("B"), q) = queue.pop(q)
  let assert #(option.Some("C"), q) = queue.pop(q)

  let assert #(option.None, _q) = queue.pop(q)

  Nil
}
