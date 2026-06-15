#!/usr/bin/env bash
# Compatibility wrapper for the canonical safe macOS maintenance runner.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CANONICAL="$(cd -- "$SCRIPT_DIR/../.." && pwd)/zsh/macos_maintenance.sh"
exec "$CANONICAL" "$@"
