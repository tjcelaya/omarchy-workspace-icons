#!/usr/bin/env bash
# Put the stock workspace switcher back and unlink this plugin.
set -euo pipefail

ID="tjcelaya.workspace-icons"
DEST="$HOME/.config/omarchy/plugins/$ID"

omarchy bar put omarchy.workspaces --before "$ID" || omarchy plugin enable omarchy.workspaces
omarchy plugin disable "$ID" || true
[[ -L $DEST ]] && rm "$DEST"
omarchy-shell shell rescanPlugins
echo "removed $ID"
