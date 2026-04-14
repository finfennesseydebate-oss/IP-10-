#!/usr/bin/env bash
#
# setup-claude-remote.sh
# ----------------------
# One-paste bootstrap for Claude Code on macOS, ready for /remote-control.
#
# Paste this into your Antigravity terminal on your Mac:
#
#   curl -fsSL https://raw.githubusercontent.com/finfennesseydebate-oss/ip-10-/claude/setup-claude-remote-access-YwYCf/scripts/setup-claude-remote.sh | bash
#
# What it does:
#   1. Verifies you're on macOS.
#   2. Installs Homebrew if missing.
#   3. Installs Node.js LTS if missing or too old.
#   4. Installs Claude Code via the official installer (npm fallback).
#   5. Makes sure ~/.local/bin is on your PATH (now and in future shells).
#   6. Launches `claude` in your current directory so you can type:
#        /login            (sign in with your Claude Max account)
#        /remote-control   (pair this session with your phone)
#
# Safe to re-run: every step is idempotent.

set -euo pipefail

# ---------- pretty output ----------
if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'
  YLW=$'\033[33m'; BLU=$'\033[34m'; RST=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GRN=""; YLW=""; BLU=""; RST=""
fi

say()   { printf "%s==>%s %s\n" "$BLU$BOLD" "$RST" "$*"; }
ok()    { printf "%s✅%s %s\n" "$GRN" "$RST" "$*"; }
warn()  { printf "%s⚠️ %s %s\n" "$YLW" "$RST" "$*"; }
die()   { printf "%s❌ %s%s\n" "$RED$BOLD" "$*" "$RST" >&2; exit 1; }

trap 'die "Setup failed on line $LINENO. Re-run the same command — every step is idempotent."' ERR

# ---------- 1. preflight ----------
say "Checking platform"
[ "$(uname -s)" = "Darwin" ] || die "This script is for macOS only (uname -s = $(uname -s))."
ok "macOS detected"

# ---------- 2. Homebrew ----------
say "Checking for Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew not found — installing (you may be prompted for your password)"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Make brew available in this shell, regardless of Apple Silicon vs Intel.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
command -v brew >/dev/null 2>&1 || die "Homebrew install completed but 'brew' is still not on PATH."
ok "Homebrew: $(brew --version | head -n1)"

# ---------- 3. Node.js ----------
say "Checking for Node.js (>= 18)"
need_node_install=1
if command -v node >/dev/null 2>&1; then
  node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  if [ "${node_major:-0}" -ge 18 ]; then
    need_node_install=0
    ok "Node.js $(node -v) already installed"
  else
    warn "Node.js $(node -v) is too old — upgrading"
  fi
fi
if [ "$need_node_install" = "1" ]; then
  brew install node
  ok "Node.js $(node -v) installed"
fi

# ---------- 4. Claude Code ----------
say "Installing Claude Code"
installed_via=""
if curl -fsSL https://claude.ai/install.sh | bash; then
  installed_via="official installer"
else
  warn "Official installer failed — falling back to npm"
  npm install -g @anthropic-ai/claude-code
  installed_via="npm"
fi

# ---------- 5. PATH sanity ----------
say "Ensuring ~/.local/bin is on PATH"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) : ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

ZSHRC="$HOME/.zshrc"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"  # added by setup-claude-remote.sh'
if [ -f "$ZSHRC" ] && grep -Fq "setup-claude-remote.sh" "$ZSHRC"; then
  : # already added
else
  printf '\n%s\n' "$PATH_LINE" >> "$ZSHRC"
  ok "Added ~/.local/bin to PATH in ~/.zshrc"
fi

command -v claude >/dev/null 2>&1 || die "claude was installed via $installed_via but is still not on PATH. Open a new terminal and re-run."
CLAUDE_VER="$(claude --version 2>/dev/null || echo unknown)"
ok "Claude Code installed: $CLAUDE_VER  (via $installed_via)"

# ---------- 6. Project dir ----------
PROJECT_DIR="$(pwd)"
say "Claude will open in: ${BOLD}${PROJECT_DIR}${RST}"

# ---------- 7. Hand off ----------
cat <<EOF

${GRN}${BOLD}All set.${RST} You are about to enter the Claude Code TUI.
Once it opens, type these two slash commands:

  ${BOLD}/login${RST}            ${DIM}# sign in with your Claude Max account${RST}
  ${BOLD}/remote-control${RST}   ${DIM}# pair this session with your phone${RST}

Then follow the pairing prompt on your phone.

${DIM}(Press Enter to launch claude…)${RST}
EOF

# Wait for a keypress only if we have a real TTY on stdin.
# When this script is executed via "curl … | bash", stdin is the pipe, not a TTY,
# so we re-open /dev/tty for the prompt and the exec below.
if [ -t 0 ]; then
  read -r _ || true
  exec claude
else
  if [ -e /dev/tty ]; then
    # shellcheck disable=SC2093
    read -r _ </dev/tty || true
    exec </dev/tty >/dev/tty 2>/dev/tty
    exec claude
  else
    warn "No TTY available — open a new terminal and run: claude"
  fi
fi
