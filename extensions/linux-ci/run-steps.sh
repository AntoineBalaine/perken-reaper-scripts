#!/usr/bin/env bash
# Runs the Linux steps of the monorepo's CI workflows inside the container
# (started by linux-ci.sh). The steps mirror .github/workflows/*.yml.
# Build caches and outputs go to /tmp, so the mounted repository only gets
# what the builds themselves write into the source tree.
set -u
LOGS=/logs
mkdir -p "$LOGS"
step() { # package label command...
  local p=$1 label=$2; shift 2
  if (cd "/work/extensions/$p" && "$@" --cache-dir "/tmp/zc/$p" > "$LOGS/$p-$label.log" 2>&1); then
    echo "PASS  $p: $label"
  else
    echo "FAIL  $p: $label   (see $p-$label.log)"
  fi
}
out() { echo "-p /tmp/out/$1"; }
echo "== reaziglib.yml";        step reaziglib test zig build test --summary all
echo "== reavim-ext.yml";       step reavim-ext test zig build test
for t in x86_64-linux-gnu aarch64-linux-gnu x86_64-macos aarch64-macos x86_64-windows aarch64-windows; do
  step reavim-ext "build-$t" zig build -Dtarget=$t -Doptimize=ReleaseSafe -Dversion=dev -p /tmp/out/rv-$t
done
echo "== vr09.yml";             step vr09 test zig build test
for t in x86_64-linux-gnu aarch64-linux-gnu x86_64-macos aarch64-macos x86_64-windows aarch64-windows; do
  step vr09 "build-$t" zig build -Dtarget=$t -Doptimize=ReleaseSafe -Dversion=dev -p /tmp/out/vr09-$t
done
echo "== perken-utilities.yml"; step perken-utilities test zig build test
                                step perken-utilities build zig build -Doptimize=ReleaseSafe -Dversion=dev -p /tmp/out/pu
echo "== console1.yml";         step console1 test zig build test -Dtest=true -Dversion=dev
                                step console1 build zig build -Dversion=dev -p /tmp/out/c1
                                step console1 ui zig build ui -Dversion=dev -p /tmp/out/c1
echo "== mft.yml";              step console1 mft-test zig build mft-test
                                step console1 mft zig build mft -Dversion=dev -p /tmp/out/mft
