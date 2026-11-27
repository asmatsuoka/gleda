import demo/database/database
import demo/stages/parser
import demo/stages/processor
import demo/stages/validator
import gleda/common/types.{type Error, StageId}
import gleda/stage

pub type Application {
  Application(
    parser: stage.Stage(String, String, String),
    validator: stage.Stage(String, String, String),
    processor: stage.Stage(String, String, String),
  )
}

const parser_id = StageId("parser")

const validator_id = StageId("validator")

const processor_id = StageId("processor")

pub fn start() -> Result(Application, Error) {
  let db_pool_name = database.start()
  let parser_handler = parser.parser_handler(validator_id)
  let validator_handler = validator.validator_handler(processor_id)
  let processor_handler =
    processor.processor_handler(database.connection(db_pool_name))
  let assert Ok(processor) =
    stage.start_stage(
      processor_id,
      types.StageConfig(name: "processor", queue_capacity: 500, worker_count: 5),
      processor_handler,
    )

  let assert Ok(validator) =
    stage.start_stage(
      validator_id,
      types.StageConfig(name: "validator", queue_capacity: 100, worker_count: 5),
      validator_handler,
    )

  let assert Ok(parser) =
    stage.start_stage(
      parser_id,
      types.StageConfig(name: "parser", queue_capacity: 350, worker_count: 5),
      parser_handler,
    )

  stage.connect(parser, validator_id, validator)
  stage.connect(validator, processor_id, processor)

  Ok(Application(parser: parser, validator: validator, processor: processor))
}
