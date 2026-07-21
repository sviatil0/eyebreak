#!/bin/bash
# EyeBreak one-line installer (issue #14).
# Installs via Homebrew with --no-quarantine so macOS never shows the
# "Apple cannot check it for malicious software" dialog.
#
#   curl -fsSL https://raw.githubusercontent.com/sviatil0/eyebreak/main/scripts/install.sh | bash
#
# Safe to re-run: upgrades an existing install or no-ops.
set -euo pipefail

say() { printf '\n==> %s\n' "$*"; }

# Homebrew may be installed but not on PATH in this shell.
find_brew() {
  command -v brew >/dev/null 2>&1 && return 0
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$b" ]; then
      eval "$("$b" shellenv)"
      return 0
    fi
  done
  return 1
}

say "EyeBreak installer — open-source 20-20-20 eye-break app"

if ! find_brew; then
  say "Homebrew not found — installing it first (Apple may ask for your password)."
  # Homebrew's installer is interactive; when this script is piped into bash,
  # stdin is the pipe, so re-attach the installer to the terminal.
  if [ -t 0 ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
  fi
  find_brew || { echo "Homebrew install did not complete. Please install from https://brew.sh and re-run."; exit 1; }
fi

say "Adding tap sviatil0/tap"
brew tap sviatil0/tap

# Homebrew 6 refuses short cask names from third-party taps ("untrusted
# tap"); the fully qualified name expresses explicit user intent and works.
CASK="sviatil0/tap/eyebreak"
if brew list --cask eyebreak >/dev/null 2>&1; then
  say "EyeBreak already installed — upgrading if a newer version exists"
  brew upgrade --cask "$CASK" 2>/dev/null || true
else
  say "Installing EyeBreak"
  brew install --cask "$CASK"
fi

# Older Homebrew quarantines cask apps (newer versions dropped the
# --no-quarantine flag along with the behavior); strip it either way so
# first launch never hits the Gatekeeper dialog.
xattr -d com.apple.quarantine /Applications/EyeBreak.app 2>/dev/null || true

say "Launching EyeBreak"
open -a EyeBreak

cat <<'DONE'

Done. Look for the eye icon in your menu bar (top right).
EyeBreak reminds you every 20 minutes to look ~20 feet away for 20 seconds.
Click the icon for settings, pause, and stats. May reduce eye strain and
dry-eye symptoms by supporting healthier screen habits.

Source: https://github.com/sviatil0/eyebreak
DONE
