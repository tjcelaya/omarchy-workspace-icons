#!/usr/bin/env bash
# Link this checkout in as an omarchy-shell plugin and put it in the bar where the stock
# workspace switcher was.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
ID="tjcelaya.workspace-icons"
DEST="$HOME/.config/omarchy/plugins/$ID"

mkdir -p "$(dirname "$DEST")"
if [[ -e $DEST && ! -L $DEST ]]; then
  echo "$DEST exists and is not a symlink; remove it first" >&2
  exit 1
fi
ln -sfn "$SRC" "$DEST"

omarchy-shell shell rescanPlugins
if omarchy plugin list --json | jq -e '.. | objects | select(.id? == "omarchy.workspaces" and (.enabled? // false))' >/dev/null 2>&1; then
  omarchy bar put "$ID" --after omarchy.workspaces
  omarchy plugin disable omarchy.workspaces
else
  omarchy plugin enable "$ID"
fi
echo "installed $ID -> $SRC"
