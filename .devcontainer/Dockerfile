
FROM --platform=linux/amd64 rust:1.86.0-bookworm

RUN apt-get update \
 && apt-get install \
    --assume-yes \
    --no-install-recommends \
    clang \
    pkg-config \
    libc6-dev-arm64-cross \
    libc6-dev-armhf-cross \
    gcc-aarch64-linux-gnu \
    gcc-arm-linux-gnueabihf

COPY rust-toolchain.toml .
RUN rustup show && rm rust-toolchain.toml
