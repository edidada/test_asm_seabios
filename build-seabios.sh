#!/usr/bin/env bash
# Build SeaBIOS from the pinned seabios/ submodule.
# Reference: https://github.com/qemu/seabios/blob/master/docs/Build_overview.md
#
# Submodule pinned at: https://github.com/qemu/seabios (see `git submodule status`)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT/seabios"

# Build (default config targets QEMU; menuconfig is interactive, so
# we build with the default configuration in CI)
make -j"$(nproc)"

# Verify build output
ls -lh out/
test -f out/bios.bin
echo "SeaBIOS built OK: out/bios.bin"
