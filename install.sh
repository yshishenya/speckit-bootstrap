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

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$BOOTSTRAP_URL" -o "$tmp"
elif command -v python3 >/dev/null 2>&1; then
  python3 - "$BOOTSTRAP_URL" "$tmp" <<'PY'
import sys
import urllib.request

url, path = sys.argv[1], sys.argv[2]
with urllib.request.urlopen(url, timeout=30) as response:
    data = response.read()
open(path, "wb").write(data)
PY
else
  echo "install.sh: curl or python3 is required" >&2
  exit 1
fi

install -m 0755 "$tmp" "$INSTALL_DIR/speckit-bootstrap"

echo "speckit-bootstrap installed to $INSTALL_DIR/speckit-bootstrap"
echo "Run: speckit-bootstrap [PROJECT_DIR]"
