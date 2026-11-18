#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != Darwin ]; then
  echo "This build requires a native macOS host." >&2
  exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/yuchuangjie-macos.XXXXXX")"
python3 - "$SCRIPT_DIR" "$WORK_DIR" <<'PY'
import hashlib
import json
from pathlib import Path
import shlex
import sys
import tarfile

kit, work = map(Path, sys.argv[1:])
manifest = json.loads((kit / "manifest.json").read_text(encoding="utf-8"))
archive = work / "assistant-source.tar.gz"
digest = hashlib.sha256()
with archive.open("wb") as target:
    for part in manifest["sourceParts"]:
        if Path(part["name"]).name != part["name"]:
            raise SystemExit("Invalid source part name")
        raw = (kit / part["name"]).read_bytes()
        if len(raw) != part["bytes"]:
            raise SystemExit("Source part size differs from manifest")
        digest.update(raw)
        target.write(raw)
if digest.hexdigest() != manifest["sourceArchiveSha256"]:
    raise SystemExit("Source input differs from manifest")
with tarfile.open(archive) as source:
    for item in source.getmembers():
        path = Path(item.name)
        if path.is_absolute() or ".." in path.parts or not item.isfile():
            raise SystemExit("Invalid source archive entry")
        destination = work / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(source.extractfile(item).read())
        destination.chmod(item.mode)
settings = {
    "INPUT_VERSION": manifest["version"],
    "BUSINESS_GATEWAY_BASE": manifest["gateway"],
    "BUSINESS_API_BASE": manifest["api"],
    "OPENCHATCUT_EDITOR_URL": manifest["editor"],
}
(work / "input-env.sh").write_text(
    "".join("export " + key + "=" + shlex.quote(value) + "\n" for key, value in settings.items()),
    encoding="utf-8",
)
PY
source "$WORK_DIR/input-env.sh"
if [ -n "${APP_RELEASE_VERSION:-}" ] && [ "$APP_RELEASE_VERSION" != "$INPUT_VERSION" ]; then
  echo "Version override differs from frozen inputs; regenerate the kit with --version." >&2
  exit 1
fi
export TARGET_ARCH="${TARGET_ARCH:-$(uname -m)}"
case "$TARGET_ARCH" in arm64|x86_64) ;; *) echo "Unsupported architecture: $TARGET_ARCH" >&2; exit 1 ;; esac
if [ "$TARGET_ARCH" != "$(uname -m)" ]; then
  echo "Use a native $TARGET_ARCH runner for Python, Node, FFmpeg and Chrome." >&2
  exit 1
fi
export BUILD_ENV=prod
export OPENCHATCUT_FRONTEND_DIST="$WORK_DIR/frontend-dist"
export OPENCHATCUT_NODE="$(command -v node)"
case "${MACOS_RELEASE_MODE:-internal}" in
  internal)
    export ALLOW_UNSIGNED_PROD=1 NOTARIZE=0 CODESIGN_IDENTITY=""
    echo "Ad-hoc signature only; no Apple notarization; manual installation only."
    ;;
  signed)
    : "${CODESIGN_IDENTITY:?Install a Developer ID Application certificate and select its identity.}"
    export ALLOW_UNSIGNED_PROD=0 NOTARIZE=1
    ;;
  *) echo "MACOS_RELEASE_MODE must be internal or signed" >&2; exit 1 ;;
esac
bash "$WORK_DIR/assistant/packaging/build_macos.sh"
OUTPUT_DIR="$SCRIPT_DIR/output/$TARGET_ARCH"
mkdir -p "$OUTPUT_DIR"
for artifact in "$WORK_DIR/assistant/release/macos/"*.dmg "$WORK_DIR/assistant/release/macos/"*.zip; do
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
