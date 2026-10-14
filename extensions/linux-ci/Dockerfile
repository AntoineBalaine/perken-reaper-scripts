# The Linux environment of the monorepo's CI (GitHub's ubuntu-latest):
# Ubuntu 24.04 with gcc/g++ (REAPER's toolchain on Linux), PHP (console1's
# SWELL resource generation) and the pinned Zig version.
FROM ubuntu:24.04
ARG ZIG_ARCH
ARG ZIG_VERSION=0.14.1
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential php-cli curl xz-utils ca-certificates git && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://ziglang.org/download/${ZIG_VERSION}/zig-${ZIG_ARCH}-linux-${ZIG_VERSION}.tar.xz | tar -xJ -C /opt \
 && ln -s /opt/zig-${ZIG_ARCH}-linux-${ZIG_VERSION}/zig /usr/local/bin/zig
