### Repository URL

https://github.com/tjcelaya/omarchy-workspace-icons

### Category

Widgets

### Tags

bar, workspaces, hyprland

### Suggest a missing tag

_No response_

### Maintainer notes

Bar widget replacing the workspace switcher: each workspace number is followed by the icons of the apps on it. Icons come from the same desktop entries as the Omarchy launcher; Omarchy webapp windows are matched back to their launcher entry, and terminals show the program running inside them (found by reading `/proc/*/stat` and `hyprctl clients -j` locally). Pure QML plus a stdlib-only python3 helper; no downloads, no sudo, no services, nothing written outside `~/.config/omarchy/plugins/`. Hovering a workspace opens a panel of its windows; if the separate tjcelaya.modelctl plugin is present its `modelctl-agents` helper is run to list coding agents inside terminals (optional, probed at runtime, not a dependency). Bundles a simplified herdr logo (Apache-2.0, credited in `NOTICE.md`) as the icon for terminals hosting agents. The optional `install.sh` only symlinks a checkout into the plugins dir and edits the bar layout through `omarchy bar` / `omarchy plugin`.

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
