---
paths:
  - "**/*.rs"
---

# Rust Development Standards

## Commands

- `cargo build` / `cargo build --release` - Build
- `cargo run` - Run the service
- `cargo test` - Run tests
- `cargo fmt` - Format code
- `cargo clippy` - Run linter
- `make run-watch` - Auto-restart on file changes
- `make check` - Run fmt + clippy --fix

## Libraries

- **Async Runtime**: `tokio`
- **Error Handling**: `anyhow`（アプリケーション層）、`thiserror`（ライブラリ層のカスタムエラー型）
- **Serialization**: `serde` + `serde_json`
- **Logging**: `tracing` + `tracing-subscriber`
- **HTTP Client**: `reqwest`
- **CLI**: `clap`
