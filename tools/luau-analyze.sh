#!/usr/bin/env bash
# luau-analyze.sh — run luau-lsp's analyzer over the project (or given paths) using
# the binary + Roblox type defs bundled with the VS Code luau-lsp extension, plus
# the Rojo sourcemap so cross-module require()s and Instance types resolve.
#
# Jungle has TWO Rojo trees, each with its own project file and sourcemap:
#   GAME  = sync/<Service>/        (default.project.json      -> sourcemap.json)
#   LOBBY = lobby/sync/<Service>/  (lobby/default.project.json -> lobby/sourcemap.json)
# The right sourcemap must be used or every cross-module require() reports "Unknown require".
#
# Usage:
#   tools/luau-analyze.sh                              # all GAME service folders
#   tools/luau-analyze.sh --lobby                      # all LOBBY service folders
#   tools/luau-analyze.sh path/to/File.luau [more...]  # specific files; the tree is
#                                                      # inferred from a leading lobby/
#
# Exit code is non-zero if any diagnostics are reported.
set -uo pipefail
cd "$(dirname "$0")/.."   # repo root
REPO_ROOT="$PWD"

# --- pick the tree (GAME by default; LOBBY via --lobby or a lobby/ path) ---
TREE="game"
if [[ "${1:-}" == "--lobby" ]]; then
  TREE="lobby"
  shift
elif [[ "${1:-}" == lobby/* ]]; then
  TREE="lobby"
fi

# --- locate the luau-lsp binary (bundled in the VS Code extension) ---
LSP="$(ls -d "$HOME"/.vscode*/extensions/johnnymorganz.luau-lsp-*/bin/server.exe 2>/dev/null | sort -V | tail -1)"
if [[ -z "${LSP:-}" || ! -f "$LSP" ]]; then
  echo "ERROR: luau-lsp server.exe not found. Install the 'JohnnyMorganz.luau-lsp' VS Code extension." >&2
  exit 2
fi

# --- locate the Roblox global type definitions (downloaded by the extension) ---
DEFS="$(ls "$HOME"/AppData/Roaming/Code*/User/globalStorage/johnnymorganz.luau-lsp/globalTypes*.d.luau 2>/dev/null | sort -V | tail -1)"
if [[ -z "${DEFS:-}" || ! -f "$DEFS" ]]; then
  echo "ERROR: globalTypes.d.luau not found. Open a .luau file in VS Code once so the extension downloads it." >&2
  exit 2
fi

# --- enter the chosen tree; its sourcemap paths are relative to that directory ---
if [[ "$TREE" == "lobby" ]]; then
  cd lobby
  echo "[luau-analyze] tree: LOBBY (lobby/)"
else
  echo "[luau-analyze] tree: GAME"
fi

# --- keep the sourcemap fresh (autogenerate in settings won't run in a headless shell) ---
if command -v rojo >/dev/null 2>&1 && [[ -f default.project.json ]]; then
  rojo sourcemap default.project.json --output sourcemap.json >/dev/null 2>&1 || true
fi

# --- targets: strip the lobby/ prefix, since we already cd'd into it ---
TARGETS=()
for arg in "$@"; do
  if [[ "$TREE" == "lobby" ]]; then
    TARGETS+=("${arg#lobby/}")
  else
    TARGETS+=("$arg")
  fi
done
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=(sync/ReplicatedStorage sync/ReplicatedFirst sync/ServerScriptService sync/ServerStorage sync/StarterPlayer)
fi

SETTINGS_ARG=()
[[ -f "$REPO_ROOT/.vscode/settings.json" ]] && SETTINGS_ARG=(--settings="$REPO_ROOT/.vscode/settings.json")

"$LSP" analyze \
  --sourcemap=sourcemap.json \
  --defs="$DEFS" \
  "${SETTINGS_ARG[@]}" \
  --platform=roblox \
  "${TARGETS[@]}" 2>&1 | grep -vE "^\[INFO\]|^\[WARN\]"
exit "${PIPESTATUS[0]}"
