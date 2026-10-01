# CLAUDE.md

omarchy-shell (Quickshell/QML) bar-widget plugin `tjcelaya.workspace-icons`.

- `Workspaces.qml` is the widget; `bin/wsicons-state` (python3, stdlib only) does all
  window → icon-name resolution and prints one JSON line. Keep resolution logic in the helper;
  the QML only maps names to image paths and lays them out.
- Host APIs come from `/usr/share/omarchy/shell` (`qs.Commons`, `qs.Ui`; the stock switcher is
  `plugins/bar/widgets/Workspaces.qml`). Bar clicks only reach registered `WidgetButton`s, so
  clickable parts must be `WidgetButton`s, not bare `MouseArea`s.
- The installed plugin is a symlink to this checkout. The shell's plugin reload keeps its QML
  component cache, so QML edits only show after `omarchy-restart-shell`.
- The bar's shared tooltip (`bar.showTooltip`) centers plain text, so the widget draws its own
  `PopupWindow` hover panel (windows, then agents inside each) and passes `tooltipText: ""` to
  `WidgetButton`. `hoverCell` tracks the hovered cell; `panelCell` keeps the panel open for a
  short grace period and while the panel itself is hovered.
- Agent rows come from `modelctl-agents` (tjcelaya.modelctl) when it exists. Keep that a soft
  runtime probe in `bin/wsicons-state`; never add it to the manifest or require it.
- Don't warp the user's cursor (`hyprctl dispatch movecursor`) to test hover while they're
  working; ask them to hover instead. A fullscreen window hides the bar entirely.
  Check errors with `quickshell log -p /usr/share/omarchy/shell | grep -v StatusNotifier`.
- Screenshot the bar to verify rendering: `grim -g "0,0 1400x30" out.png`.
- Changes to the bar layout (`~/.config/omarchy/shell.json`) must be recorded in
  `~/src/tjcelaya/docs/omarchy-customization.md`.
