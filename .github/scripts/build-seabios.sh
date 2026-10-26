#!/usr/bin/env bash
# Build SeaBIOS, following the steps described in README.md
# Reference: https://github.com/qemu/seabios/blob/master/docs/Build_overview.md

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# 1. Clone SeaBIOS source (shallow clone to keep CI fast)
if [ ! -d seabios ]; then
    git clone --depth 1 https://github.com/qemu/seabios.git
fi

cd seabios

# 2. Build (default config targets QEMU; menuconfig is interactive, so
#    we build with the default configuration in CI)
make -j"$(nproc)"

# 3. Verify build output
ls -lh out/
test -f out/bios.bin
echo "SeaBIOS built OK: out/bios.bin"
