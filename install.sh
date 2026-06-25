#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${SPECKIT_BOOTSTRAP_INSTALL_DIR:-$HOME/.local/bin}"
BOOTSTRAP_URL="${SPECKIT_BOOTSTRAP_URL:-https://raw.githubusercontent.com/yshishenya/speckit-bootstrap/main/bin/speckit-bootstrap}"

mkdir -p "$INSTALL_DIR"

tmp="$(mktemp)"
cleanup() {
  rm -f "$tmp"
}
trap cleanup EXIT

if ! command -v curl >/dev/null 2>&1; then
  echo "install.sh: curl is required" >&2
  exit 1
fi

curl -fsSL "$BOOTSTRAP_URL" -o "$tmp"
install -m 0755 "$tmp" "$INSTALL_DIR/speckit-bootstrap"

echo "speckit-bootstrap installed to $INSTALL_DIR/speckit-bootstrap"
echo "Run: speckit-bootstrap [PROJECT_DIR]"
