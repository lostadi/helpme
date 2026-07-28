#!/usr/bin/env bash
# helpme install.sh — bootstrap helpme on any machine
#
# Required dependency: Ostadix-lang
#   https://github.com/lostadi/Ostadix-lang
#   shipped as git submodule at ./Ostadix-lang (see .gitmodules, deps.toml)
#
# Usage:
#   git clone --recurse-submodules https://github.com/lostadi/helpme.git ~/helpme
#   cd ~/helpme && ./install.sh
#
# Environment overrides:
#   OLANG_DIR    — where to find/clone Ostadix-lang
#                  (default: ./Ostadix-lang if present, else ~/Ostadix-lang)
#   HELPME_DIR   — where helpme data lives       (default: ~/.local/share/helpme)
#   HELPME_BIN   — where to install the wrapper  (default: ~/.local/bin)

set -euo pipefail

HELPME_DIR="${HELPME_DIR:-${HOME}/.local/share/helpme}"
HELPME_BIN="${HELPME_BIN:-${HOME}/.local/bin}"
OLANG_REPO="https://github.com/lostadi/Ostadix-lang.git"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prefer vendored/submodule Ostadix-lang next to install.sh, then ~/Ostadix-lang
if [[ -z "${OLANG_DIR:-}" ]]; then
    if [[ -f "${REPO_DIR}/Ostadix-lang/Cargo.toml" ]]; then
        OLANG_DIR="${REPO_DIR}/Ostadix-lang"
    else
        OLANG_DIR="${HOME}/Ostadix-lang"
    fi
fi
OLANG_BIN="${OLANG_DIR}/target/release/O"

log()  { printf '\033[1;32m[helpme]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[helpme]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[helpme]\033[0m %s\n' "$*" >&2; exit 1; }

# --- Step 0: Ostadix-lang submodule (required dependency) --- #
if [[ -f "${REPO_DIR}/.gitmodules" ]] && [[ -d "${REPO_DIR}/.git" ]]; then
    if [[ ! -f "${REPO_DIR}/Ostadix-lang/Cargo.toml" ]]; then
        log "Initializing Ostadix-lang git submodule (required dependency)..."
        git -C "$REPO_DIR" submodule update --init --recursive \
            || die "Failed to init Ostadix-lang submodule. Run: git submodule update --init --recursive"
    fi
fi

# --- Step 1: Ostadix-lang (build) --- #
log "Checking Ostadix-lang (required dependency)..."
if [[ -x "$OLANG_BIN" ]]; then
    log "Ostadix-lang binary found: $OLANG_BIN"
else
    if [[ ! -f "${OLANG_DIR}/Cargo.toml" ]]; then
        if [[ -d "$OLANG_DIR" ]] && [[ ! -d "$OLANG_DIR/.git" ]] && [[ ! -f "$OLANG_DIR/.git" ]]; then
            die "OLANG_DIR exists but is not an Ostadix-lang tree: $OLANG_DIR"
        fi
        log "Cloning Ostadix-lang into $OLANG_DIR..."
        log "  (required dep: $OLANG_REPO)"
        git clone "$OLANG_REPO" "$OLANG_DIR"
    elif [[ -d "$OLANG_DIR/.git" ]] || [[ -f "$OLANG_DIR/.git" ]]; then
        log "Updating Ostadix-lang..."
        git -C "$OLANG_DIR" pull --ff-only || warn "git pull failed — using existing tree"
    else
        log "Using local Ostadix-lang tree: $OLANG_DIR"
    fi
    command -v cargo &>/dev/null || die "cargo not found (needed to build Ostadix-lang). Install Rust: https://rustup.rs"
    log "Building Ostadix-lang (release)..."
    cargo build --release --manifest-path="${OLANG_DIR}/Cargo.toml"
    [[ -x "$OLANG_BIN" ]] || die "Build done but binary missing at $OLANG_BIN"
    log "Ostadix-lang ready: $OLANG_BIN"
fi

# --- Step 2: directory structure --- #
log "Setting up ${HELPME_DIR}..."
mkdir -p "${HELPME_DIR}/db" "${HELPME_BIN}"

# Symlink backends from Ostadix-lang repo
if [[ ! -d "${OLANG_DIR}/backends" ]]; then
    die "Backends directory missing: ${OLANG_DIR}/backends"
fi
ln -sfn "${OLANG_DIR}/backends" "${HELPME_DIR}/backends"
log "Backends → ${OLANG_DIR}/backends"

# --- Step 3: copy .O programs (Ostadix-lang surface area) --- #
PROGS=(
    reindex.O
    lookup.O
    ai_explain.O
    search.O
    map.O
    doctor.O
    stats.O
    undoc.O
    topics.O
    system.O
    setup.O
)
for prog in "${PROGS[@]}"; do
    if [[ ! -f "${REPO_DIR}/${prog}" ]]; then
        warn "Skipping missing ${prog}"
        continue
    fi
    cp "${REPO_DIR}/${prog}" "${HELPME_DIR}/${prog}"
    chmod +x "${HELPME_DIR}/${prog}"
    log "Installed ${prog}"
done

# --- Step 4: install wrapper --- #
# Bake the resolved OLANG path into the installed wrapper so it works
# without requiring OLANG to be set in the environment.
sed "s|^OLANG=\"\${OLANG:-.*}\"|OLANG=\"\${OLANG:-${OLANG_BIN}}\"|" \
    "${REPO_DIR}/helpme" > "${HELPME_BIN}/helpme"
chmod +x "${HELPME_BIN}/helpme"
log "Wrapper installed: ${HELPME_BIN}/helpme"
log "  OLANG default: ${OLANG_BIN}"

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$HELPME_BIN"; then
    warn "$HELPME_BIN not in \$PATH."
    warn "Add to your shell rc:  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
fi

# --- Step 5: initial reindex --- #
export HELPME_DB="${HELPME_DIR}/db/index.db"
export OLANG="$OLANG_BIN"
export HELPME_DIR

log "Installing/upgrading optional deps for this system (man, tldr, bat, …)..."
if "${HELPME_BIN}/helpme" setup; then
    log "Optionals setup finished."
else
    warn "Optionals setup had errors — run: helpme setup"
fi

log "Running initial reindex (takes a few minutes)..."
"${HELPME_BIN}/helpme" reindex

log ""
log "✓ Done. helpme makes hidden CLI knowledge visible."
log "  Try:"
log "    helpme setup        — install/upgrade optional deps for this OS"
log "    helpme system       — machine, package managers, essential commands"
log "    helpme              — fuzzy-browse every indexed command"
log "    helpme map          — PATH / Termux / coverage map"
log "    helpme doctor       — what's missing on this machine"
log "    helpme search zip   — find tools by what they do"
log "    helpme topics       — Termux/shell knowledge that isn't a binary"
log "    helpme git          — man / --help / tldr for one command"
log "    helpme ai git       — plain-language summary (local LLM)"
