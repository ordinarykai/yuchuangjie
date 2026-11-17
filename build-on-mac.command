#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != Darwin ]; then
  echo "This build requires a macOS host; Windows/Linux cannot run it." >&2
  exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/yuchuangjie-macos.XXXXXX")"
if [ -f "$SCRIPT_DIR/assistant-source.tar.gz" ]; then
  SOURCE_ARCHIVE="$SCRIPT_DIR/assistant-source.tar.gz"
else
  SOURCE_ARCHIVE="$WORK_DIR/assistant-source.tar.gz"
  cat "$SCRIPT_DIR"/assistant-source.part-* > "$SOURCE_ARCHIVE"
fi
tar -xzf "$SOURCE_ARCHIVE" -C "$WORK_DIR"
if [ -n "${APP_RELEASE_VERSION:-}" ]; then
  python3 - "$WORK_DIR/assistant/version.json" "$APP_RELEASE_VERSION" <<'PY'
import json
from pathlib import Path
import re
import sys

version = sys.argv[2]
if not re.fullmatch(r"\d+(?:\.\d+){1,3}", version):
    raise SystemExit("APP_RELEASE_VERSION must be numeric semantic version")
Path(sys.argv[1]).write_text(json.dumps({"version": version}) + "\n", encoding="utf-8")
PY
fi
export TARGET_ARCH="${TARGET_ARCH:-$(uname -m)}"
case "$TARGET_ARCH" in arm64|x86_64) ;; *) echo "Unsupported architecture: $TARGET_ARCH" >&2; exit 1 ;; esac
export BUILD_ENV=prod
export BUSINESS_GATEWAY_BASE="https://cqsaigc.com/backend"
export BUSINESS_API_BASE="https://cqsaigc.com/backend/atai-video-business-platform"
export OPENCHATCUT_EDITOR_URL="https://cqsaigc.com/cut/"
export OPENCHATCUT_FRONTEND_DIST="$WORK_DIR/frontend-dist"
export OPENCHATCUT_NODE="$(command -v node)"
case "${MACOS_RELEASE_MODE:-signed}" in
  internal)
    export ALLOW_UNSIGNED_PROD=1
    export NOTARIZE=0
    export CODESIGN_IDENTITY=""
    echo "Internal test build: ad-hoc signature, no Apple notarization, manual installation only."
    ;;
  signed)
    : "${CODESIGN_IDENTITY:?Install a Developer ID certificate and select its identity.}"
    export ALLOW_UNSIGNED_PROD=0
    export NOTARIZE=1
    ;;
  *) echo "MACOS_RELEASE_MODE must be internal or signed" >&2; exit 1 ;;
esac
bash "$WORK_DIR/assistant/packaging/build_macos.sh"
OUTPUT_DIR="$SCRIPT_DIR/output/$TARGET_ARCH"
mkdir -p "$OUTPUT_DIR"
for artifact in "$WORK_DIR/assistant/release/macos/"*; do
  [ -f "$artifact" ] || continue
  name="$(basename "$artifact")"
  name="${name/-macos./-macos-$TARGET_ARCH.}"
  cp "$artifact" "$OUTPUT_DIR/$name"
done
(
  cd "$OUTPUT_DIR"
  for artifact in *.dmg *.zip; do
    [ -f "$artifact" ] || continue
    shasum -a 256 "$artifact" > "$artifact.sha256"
  done
)
printf 'Built artifacts: %s\nBuild workspace retained: %s\n' "$OUTPUT_DIR" "$WORK_DIR"
