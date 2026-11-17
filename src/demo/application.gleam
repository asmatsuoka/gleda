import gleda/common/types.{
  type Error, type HandlerOutcome, Completed, Routed, StageConfig, StageId,
}
import gleda/stage

pub type Application {
  Application(
    parser: stage.Stage(String, String, String),
    enrichment: stage.Stage(String, String, String),
  )
}

pub fn start() -> Result(Application, Error) {
  let parser_id = StageId("parser")
  let enrichment_id = StageId("enrichment")

  case
    stage.start_stage(
      parser_id,
      StageConfig(name: "parser", queue_capacity: 100, worker_count: 2),
      parser_handler,
    )
  {
    Error(error) -> Error(error)
    Ok(parser_stage) -> {
      case
        stage.start_stage(
          enrichment_id,
          StageConfig(name: "enrichment", queue_capacity: 50, worker_count: 1),
          enrichment_handler,
        )
      {
        Error(error) -> Error(error)
        Ok(enrichment_stage) -> {
          stage.connect(parser_stage, enrichment_id, enrichment_stage)
          Ok(Application(parser: parser_stage, enrichment: enrichment_stage))
        }
      }
    }
  }
}

fn parser_handler(command: String) -> HandlerOutcome(String, String, String) {
  let parsed_command = "Parsed: " <> command
  Routed(parsed_command, StageId("enrichment"))
}

fn enrichment_handler(
  command: String,
) -> HandlerOutcome(String, String, String) {
  Completed("Enriched: " <> command)
}
