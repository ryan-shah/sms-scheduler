#!/usr/bin/env bash
# Idempotent cloud/dev bootstrap: pinned Flutter SDK, optional Android SDK, bd (beads).
# Safe to run anywhere; a second run is a fast no-op.
#   WITH_ANDROID_SDK=1 bash tool/setup_cloud.sh   # also install Android SDK (Linux only)
set -uo pipefail

FLUTTER_VERSION=3.44.4   # keep in sync with the workflows' flutter-version
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
ANDROID_SDK_DIR="${ANDROID_SDK_DIR:-$HOME/android-sdk}"
ANDROID_PLATFORM="${ANDROID_PLATFORM:-android-36}"
ANDROID_BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-36.0.0}"
CMDLINE_TOOLS_ZIP="commandlinetools-linux-11076708_latest.zip"

log()  { echo "[setup_cloud] $*"; }
warn() { echo "[setup_cloud] WARN: $*"; }

cd "$(dirname "$0")/.." || exit 1
IS_LINUX=0; [ "$(uname -s)" = "Linux" ] && IS_LINUX=1

flutter_ver() { # prints version of given flutter binary, or nothing (fast path: version file)
  local root vf v; root="$(cd "$(dirname "$1")/.." 2>/dev/null && pwd)"; vf="$root/bin/cache/flutter.version.json"
  if [ -f "$vf" ]; then
    v="$(sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p' "$vf" | head -n1)"
    if [ -n "$v" ]; then echo "$v"; return; fi
  fi
  "$1" --version --machine 2>/dev/null | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p' | head -n1
}

# ---------- Flutter ----------
setup_flutter() {
  local marker="$FLUTTER_HOME/.setup_cloud_version"
  if command -v flutter >/dev/null 2>&1; then
    local v; v="$(flutter_ver "$(command -v flutter)")"
    if [ "$v" = "$FLUTTER_VERSION" ]; then log "flutter $v on PATH; skipping install"; return 0; fi
    warn "flutter on PATH is '${v:-unknown}', pinned is $FLUTTER_VERSION"
  fi
  if [ -x "$FLUTTER_HOME/bin/flutter" ] && [ "$(cat "$marker" 2>/dev/null)" = "$FLUTTER_VERSION" ]; then
    log "flutter $FLUTTER_VERSION already at $FLUTTER_HOME"
    export PATH="$FLUTTER_HOME/bin:$PATH"; return 0
  fi
  if [ "$IS_LINUX" != 1 ]; then
    echo "[setup_cloud] ERROR: flutter $FLUTTER_VERSION not found and auto-install is Linux-only. Install it manually." >&2
    return 1
  fi
  local url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  local tmp; tmp="$(mktemp -d)"
  log "downloading $url"
  if ! curl -fsSL "$url" -o "$tmp/flutter.tar.xz"; then echo "[setup_cloud] ERROR: download failed" >&2; rm -rf "$tmp"; return 1; fi
  rm -rf "$FLUTTER_HOME"; mkdir -p "$(dirname "$FLUTTER_HOME")"
  tar -xf "$tmp/flutter.tar.xz" -C "$tmp" && mv "$tmp/flutter" "$FLUTTER_HOME" || { echo "[setup_cloud] ERROR: extract failed" >&2; rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  export PATH="$FLUTTER_HOME/bin:$PATH"
  git config --global --add safe.directory "$FLUTTER_HOME" 2>/dev/null || true
  flutter config --no-analytics >/dev/null 2>&1 || true
  log "flutter precache --android"
  flutter precache --android || warn "precache failed"
  echo "$FLUTTER_VERSION" > "$marker"
  # persist PATH for later shells in cloud sessions
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then echo "export PATH=\"$FLUTTER_HOME/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"; fi
  log "installed flutter $(flutter_ver "$FLUTTER_HOME/bin/flutter")"
}

# ---------- Android SDK (optional) ----------
setup_android() {
  [ "${WITH_ANDROID_SDK:-0}" = "1" ] || return 0
  local existing="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [ -n "$existing" ] && [ -d "$existing/platforms" ]; then log "Android SDK present at $existing"; return 0; fi
  if [ -d "$ANDROID_SDK_DIR/platforms/$ANDROID_PLATFORM" ] && [ -d "$ANDROID_SDK_DIR/build-tools/$ANDROID_BUILD_TOOLS" ]; then
    log "Android SDK already at $ANDROID_SDK_DIR"
  elif [ "$IS_LINUX" != 1 ]; then
    warn "Android SDK auto-install is Linux-only; skipping"; return 0
  else
    local tmp; tmp="$(mktemp -d)"
    log "installing Android cmdline-tools to $ANDROID_SDK_DIR"
    curl -fsSL "https://dl.google.com/android/repository/$CMDLINE_TOOLS_ZIP" -o "$tmp/ct.zip" \
      && unzip -q "$tmp/ct.zip" -d "$tmp" \
      && mkdir -p "$ANDROID_SDK_DIR/cmdline-tools" \
      && rm -rf "$ANDROID_SDK_DIR/cmdline-tools/latest" \
      && mv "$tmp/cmdline-tools" "$ANDROID_SDK_DIR/cmdline-tools/latest" \
      || { warn "cmdline-tools install failed"; rm -rf "$tmp"; return 0; }
    rm -rf "$tmp"
    local sm="$ANDROID_SDK_DIR/cmdline-tools/latest/bin/sdkmanager"
    yes | "$sm" --sdk_root="$ANDROID_SDK_DIR" --licenses >/dev/null 2>&1 || true
    "$sm" --sdk_root="$ANDROID_SDK_DIR" "platform-tools" "platforms;$ANDROID_PLATFORM" "build-tools;$ANDROID_BUILD_TOOLS" \
      || { warn "sdkmanager install failed"; return 0; }
  fi
  export ANDROID_HOME="$ANDROID_SDK_DIR" ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export ANDROID_HOME=\"$ANDROID_SDK_DIR\" ANDROID_SDK_ROOT=\"$ANDROID_SDK_DIR\"" >> "$CLAUDE_ENV_FILE"
  fi
  if command -v flutter >/dev/null 2>&1; then
    flutter config --android-sdk "$ANDROID_SDK_DIR" >/dev/null 2>&1 || true
    yes | flutter doctor --android-licenses >/dev/null 2>&1 || true
  fi
}

# ---------- bd (best-effort; never rewrites tracked files) ----------
setup_bd() {
  if ! command -v bd >/dev/null 2>&1; then
    if command -v npm >/dev/null 2>&1; then
      log "installing bd via npm"; npm install -g @beads/bd >/dev/null 2>&1 || warn "npm install of @beads/bd failed"
    else warn "bd missing and npm unavailable"; fi
  fi
  command -v bd >/dev/null 2>&1 || return 0
  if bd list >/dev/null 2>&1; then return 0; fi
  log "no usable local bd database; bootstrapping"
  if bd bootstrap --yes >/dev/null 2>&1 && bd list >/dev/null 2>&1; then return 0; fi
  if [ -f .beads/issues.jsonl ]; then
    warn "bd bootstrap failed; importing .beads/issues.jsonl"
    bd import .beads/issues.jsonl >/dev/null 2>&1 && bd list >/dev/null 2>&1 || warn "bd import failed; run 'bd prime' manually"
  else warn "bd bootstrap failed and no .beads/issues.jsonl"; fi
}

rc=0
setup_flutter || rc=1
setup_android || true
setup_bd || true
exit $rc
