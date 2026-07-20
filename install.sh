#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${SPECKIT_BOOTSTRAP_INSTALL_DIR:-$HOME/.local/bin}"
REPOSITORY="yshishenya/speckit-bootstrap"
BOOTSTRAP_VERSION="${SPECKIT_BOOTSTRAP_VERSION:-latest}"
BOOTSTRAP_URL="${SPECKIT_BOOTSTRAP_URL:-}"
EXPECTED_SHA256="${SPECKIT_BOOTSTRAP_SHA256:-}"
ALLOW_UNVERIFIED="${SPECKIT_BOOTSTRAP_ALLOW_UNVERIFIED:-0}"

mkdir -p "$INSTALL_DIR"

tmp="$(mktemp)"
checksum_tmp="$(mktemp)"
install_tmp=""
cleanup() {
  rm -f "$tmp" "$checksum_tmp"
  [[ -z "$install_tmp" ]] || rm -f "$install_tmp"
}
trap cleanup EXIT

if ! command -v curl >/dev/null 2>&1; then
  echo "install.sh: curl is required" >&2
  exit 1
fi

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo "install.sh: shasum or sha256sum is required" >&2
    return 1
  fi
}

resolve_latest_version() {
  local effective_url
  effective_url="$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$REPOSITORY/releases/latest")"
  basename "$effective_url"
}

if [[ -n "$BOOTSTRAP_URL" ]]; then
  curl -fsSL "$BOOTSTRAP_URL" -o "$tmp"
  if [[ -z "$EXPECTED_SHA256" && "$ALLOW_UNVERIFIED" != "1" ]]; then
    echo "install.sh: SPECKIT_BOOTSTRAP_URL requires SPECKIT_BOOTSTRAP_SHA256" >&2
    echo "install.sh: set SPECKIT_BOOTSTRAP_ALLOW_UNVERIFIED=1 only for a reviewed local source" >&2
    exit 1
  fi
  source_description="$BOOTSTRAP_URL"
else
  if [[ "$BOOTSTRAP_VERSION" == "latest" ]]; then
    BOOTSTRAP_VERSION="$(resolve_latest_version)"
  fi
  if [[ -z "$BOOTSTRAP_VERSION" ]]; then
    echo "install.sh: could not resolve the latest release" >&2
    exit 1
  fi

  release_base="https://github.com/$REPOSITORY/releases/download/$BOOTSTRAP_VERSION"
  if curl -fsSL "$release_base/speckit-bootstrap" -o "$tmp" && \
     curl -fsSL "$release_base/speckit-bootstrap.sha256" -o "$checksum_tmp"; then
    EXPECTED_SHA256="$(awk 'NF {print $1; exit}' "$checksum_tmp")"
    source_description="$release_base/speckit-bootstrap"
  elif [[ "$ALLOW_UNVERIFIED" == "1" ]]; then
    BOOTSTRAP_URL="https://raw.githubusercontent.com/$REPOSITORY/$BOOTSTRAP_VERSION/bin/speckit-bootstrap"
    echo "install.sh: WARNING release assets are unavailable; using unverified $BOOTSTRAP_URL" >&2
    curl -fsSL "$BOOTSTRAP_URL" -o "$tmp"
    source_description="$BOOTSTRAP_URL"
  else
    echo "install.sh: verified release assets are unavailable for $BOOTSTRAP_VERSION" >&2
    echo "install.sh: wait for the release workflow or explicitly set SPECKIT_BOOTSTRAP_ALLOW_UNVERIFIED=1" >&2
    exit 1
  fi
fi

if [[ -n "$EXPECTED_SHA256" ]]; then
  if ! printf '%s\n' "$EXPECTED_SHA256" | grep -Eq '^[0-9A-Fa-f]{64}$'; then
    echo "install.sh: invalid SHA-256 value" >&2
    exit 1
  fi
  actual_sha256="$(sha256_file "$tmp")"
  actual_sha256_lower="$(printf '%s' "$actual_sha256" | tr '[:upper:]' '[:lower:]')"
  expected_sha256_lower="$(printf '%s' "$EXPECTED_SHA256" | tr '[:upper:]' '[:lower:]')"
  if [[ "$actual_sha256_lower" != "$expected_sha256_lower" ]]; then
    echo "install.sh: checksum mismatch" >&2
    echo "install.sh: expected $EXPECTED_SHA256" >&2
    echo "install.sh: actual   $actual_sha256" >&2
    exit 1
  fi
fi

bash -n "$tmp"
install_tmp="$(mktemp "$INSTALL_DIR/.speckit-bootstrap.XXXXXX")"
install -m 0755 "$tmp" "$install_tmp"
mv -f "$install_tmp" "$INSTALL_DIR/speckit-bootstrap"
install_tmp=""

echo "speckit-bootstrap installed to $INSTALL_DIR/speckit-bootstrap"
echo "Source: $source_description"
case ":${PATH:-}:" in
  *":$INSTALL_DIR:"*) ;;
  *) printf 'Add it to PATH for this shell: export PATH="%s:%sPATH"\n' "$INSTALL_DIR" '$' ;;
esac
echo "Run: $INSTALL_DIR/speckit-bootstrap [PROJECT_DIR]"
