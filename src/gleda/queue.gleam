import gleam/list
import gleam/option

pub opaque type Queue(a) {
  Queue(front: List(a), back: List(a), size: Int, capacity: Int)
}

pub type PushResult(a) {
  Accepted(Queue(a))
  Full
}

pub fn new(capacity: Int) -> Result(Queue(a), Nil) {
  case capacity > 0 {
    True -> Ok(Queue(front: [], back: [], size: 0, capacity: capacity))
    False -> Error(Nil)
  }
}

pub fn push(queue: Queue(a), item: a) -> PushResult(a) {
  case queue.size >= queue.capacity {
    True -> Full
    False ->
      Accepted(
        Queue(
          ..queue,
          front: queue.front,
          back: [item, ..queue.back],
          size: queue.size + 1,
        ),
      )
  }
}

pub fn pop(queue: Queue(a)) -> #(option.Option(a), Queue(a)) {
  case queue.front {
    [head, ..tail] -> #(
      option.Some(head),
      Queue(..queue, front: tail, size: queue.size - 1),
    )
    [] ->
      case list.reverse(queue.back) {
        [head, ..tail] -> #(
          option.Some(head),
          Queue(..queue, front: tail, back: [], size: queue.size - 1),
        )
        [] -> #(option.None, queue)
      }
  }
}

pub fn size(queue: Queue(a)) -> Int {
  queue.size
}

pub fn capacity(queue: Queue(a)) -> Int {
  queue.capacity
}

pub fn is_empty(queue: Queue(a)) -> Bool {
  queue.size == 0
}

pub fn is_full(queue: Queue(a)) -> Bool {
  queue.size == queue.capacity
}
