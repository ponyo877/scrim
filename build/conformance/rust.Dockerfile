# The Rust SDK's conformance client of Agones (test/sdk/rust), unchanged.
# The SDK compiles its protocol buffers when it is built, so protoc is
# needed, and the .proto files of protobuf's own types, which Debian keeps
# in libprotobuf-dev. RUN_ASYNC=true in the environment runs its async half.
FROM rust:1.99.1 AS build
ARG agones=third_party/agones
RUN apt-get update && apt-get install -y --no-install-recommends protobuf-compiler libprotobuf-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /agones
COPY ${agones}/sdks/rust sdks/rust
COPY ${agones}/test/sdk/rust test/sdk/rust
RUN cd test/sdk/rust && cargo build --release

FROM debian:trixie-slim
COPY --from=build /agones/test/sdk/rust/target/release/rust-simple /client
ENTRYPOINT ["/client"]
