#!/usr/bin/env bash
# CREOS — installation du poste de développement (macOS / Linux)
# Lancer depuis le dossier du projet :  bash tools/setup-mac-linux.sh
set -euo pipefail

GODOT_VERSION="4.7.2"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
step() { printf "\n\033[36m==> %s\033[0m\n" "$1"; }

step "uv (pour le MCP Blender)"
command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

step "Godot $GODOT_VERSION"
if [[ "$(uname)" == "Darwin" ]]; then
  GODOT_APP="/Applications/Godot.app"
  if [[ ! -d "$GODOT_APP" ]]; then
    curl -L -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_macos.universal.zip"
    unzip -q -o /tmp/godot.zip -d /Applications
  fi
  GODOT_PATH="$GODOT_APP/Contents/MacOS/Godot"
  command -v node >/dev/null || echo "!! Installe Node.js (https://nodejs.org) puis relance ce script."
  command -v blender >/dev/null || [[ -d /Applications/Blender.app ]] || echo "!! Installe Blender (https://www.blender.org/download/)."
else
  GODOT_DIR="$HOME/.local/share/godot-$GODOT_VERSION"
  GODOT_PATH="$GODOT_DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
  if [[ ! -x "$GODOT_PATH" ]]; then
    mkdir -p "$GODOT_DIR"
    curl -L -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
    unzip -q -o /tmp/godot.zip -d "$GODOT_DIR"
    chmod +x "$GODOT_PATH"
  fi
  command -v node >/dev/null || echo "!! Installe Node.js (paquet nodejs) puis relance ce script."
  command -v blender >/dev/null || echo "!! Installe Blender (paquet blender ou snap)."
fi
echo "  Godot : $GODOT_PATH"

step "Claude Code"
command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash
claude --version

cd "$PROJECT_DIR"
step "MCP Godot"
claude mcp remove godot -s local >/dev/null 2>&1 || true
claude mcp add godot -s local -e GODOT_PATH="$GODOT_PATH" -e DEBUG=true -- npx -y @coding-solo/godot-mcp

step "MCP Blender (coche 'Claude Code' quand il demande)"
uvx mcp-for-blender setup || echo "!! Relance plus tard : uvx mcp-for-blender setup"

step "Import des assets et tests"
"$GODOT_PATH" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT_PATH" --headless --path . --script res://tests/run_tests.gd

printf "\n\033[32mTout est prêt !\033[0m Lance « claude » dans ce dossier et colle le message de docs/DEMARRAGE.md.\n"
