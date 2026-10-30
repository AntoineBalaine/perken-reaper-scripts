#!/usr/bin/env bash
# Runs the Linux steps of the monorepo's CI workflows locally, in a Docker
# container matching GitHub's ubuntu-latest, so that Linux-only failures
# (gcc-compiled C++, libstdc++ linking, ...) show up before a push.
#
#   extensions/linux-ci/linux-ci.sh            # arm64 Linux (native on Apple silicon)
#   extensions/linux-ci/linux-ci.sh --amd64    # x86_64 Linux (emulated, slower)
#
# Each step prints PASS or FAIL; its full output is in
# extensions/linux-ci/logs/<arch>/<package>-<step>.log. Build caches and
# outputs stay inside the container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ARCH=arm64
case "${1:-}" in
  "") ;;
  --amd64) ARCH=amd64 ;;
  --arm64) ARCH=arm64 ;;
  *) echo "usage: $0 [--arm64|--amd64]" >&2; exit 1 ;;
esac
ZIG_ARCH=$([ "$ARCH" = amd64 ] && echo x86_64 || echo aarch64)
IMAGE="perken-linux-ci:$ARCH"

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running (start Docker Desktop first)" >&2
  exit 1
fi

docker build -q --platform "linux/$ARCH" --build-arg ZIG_ARCH="$ZIG_ARCH" -t "$IMAGE" "$SCRIPT_DIR" >/dev/null

LOGS="$SCRIPT_DIR/logs/$ARCH"
mkdir -p "$LOGS"
docker run --rm --platform "linux/$ARCH" \
  -v "$REPO_ROOT":/work \
  -v "$SCRIPT_DIR/run-steps.sh":/run-steps.sh:ro \
  -v "$LOGS":/logs \
  "$IMAGE" /run-steps.sh
