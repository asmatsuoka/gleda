# GLEDA

**A lightweight stage-based concurrency library project for Gleam.**

**GLEDA** is an experimental implementation of the [SEDA (Staged Event-Driven Architecture)](https://dl.acm.org/doi/10.1145/502059.502057) concurrency model for Gleam.
The name **GLEDA** (*Gleam Staged Event-Driven Architecture*) stems from **LEDA** (*Lua Staged Event-Driven Architecture*), an implementation based on the SEDA model for Lua.

This project provides building blocks for creating concurrent applications by splitting workloads into independent stages, each with its own bounded message queue and cofigurable worker pool.

## Core Concepts

### Stages

A stage is an independent processing unit responsible for handling incoming commands(events).
Each stage hands off the command to an underlying *Worker Pool*, and then has to handle the outcomes associated with the processing/handling of the commands.

### Workers

Workers are responsible for executing a stage's handler independently.
Each worker processes one command at a time and returns the outcome back to the related stage.

### Routing

Stages can *Route* commands to other stages.
**GLEDA** preserves the original caller's reply destination throughout the routing process, allowing commands to travel through multiple stages while delivering the final result directly to the original caller.

### Queueing vs Processing

Queue submission and processing completion are separate operations. This is very important for the concurrency model and serves as a mechanism of *Back Pressure*.

### Concurrency, Architecture and the BEAM

**GLEDA** builds on the concurrency primitives provided by the Erlang Virtual Machine (BEAM), using [Gleam OTP](https://gleam-otp.hexdocs.pm/0.5.0/index.html)'s Actor Model abstraction.
Rather than implementing its own concurrency runtime, **GLEDA** delegates process execution, scheduling, message passing, and memory management to the BEAM.

Each **GLEDA** stage runs as independent BEAM process and maintains its own application-level message queue, routing configuration and worker pool. The workers also run as independent processes, executing stage handlers and reporting their outcomes back to their related stage through async messaging.

Scheduling of these processes (stages and workers) is completely up to the BEAM, enabling a concurrency using native resources.

## Development

### Requirements

- [Gleam](https://gleam.run/)
- Erlang/OTP

### Run the example

```sh
gleam run
```

### Run tests

```sh
gleam test
```

### Type check

```sh
gleam check
```

## References

Gleda is inspired by:

- [SEDA: An Architecture for Well-Conditioned, Scalable Internet Services](https://dl.acm.org/doi/10.1145/502059.502057)
- [ERLDA](https://github.com/fernandoareias/erlda)
- [ERLDA: Explorando Concorrência e Resiliência com SEDA em Erlang](https://sol.sbc.org.br/index.php/se4fp/article/view/37105)