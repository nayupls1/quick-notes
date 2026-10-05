# quick-notes

Voice quick notes for [Omarchy](https://omarchy.org). Hold a hotkey, say what's on your mind, let go — [voxtype](https://github.com/peteonrails/voxtype) transcribes it, [Codex](https://github.com/openai/codex) turns it into short checklist items, and they land in a markdown notepad. A note icon in the bar shows the list.

```
hold SUPER+N → speak → release → - [ ] Buy milk tomorrow
                                 - [ ] Email Sam about the invoice before Friday
```

## Features

- **Hold-to-talk hotkey.** Press to record, release to save. No windows pop up.
- **Bar widget.** The icon pulses while you're recording and shows an hourglass while Codex is writing. Click it to open the checklist, where you can tick, delete or type notes, clear finished items, or open the file.
- **Plain markdown.** Notes go to `~/notes/quick-notes.md` as `- [ ]` / `- [x]` lines, so any editor or sync tool can use them.
- **Nothing gets lost.** If Codex fails, the raw transcript is saved as a note.
- **Optional notifications.** Turn the "notes added" notifications on or off. Errors always notify.

## Requirements

- Omarchy (Hyprland plus the Quickshell-based `omarchy-shell`)
- `voxtype` with its daemon running (`systemctl --user enable --now voxtype`)
- `codex` CLI, logged in (`codex login`)
- `jq`, `notify-send`, `flock`

## Install

```bash
git clone https://github.com/nayupls1/quick-notes.git
cd quick-notes
./install.sh
```

The installer:

1. links `bin/quick-notes` into `~/.local/bin`
2. copies `plugin/` to `~/.config/omarchy/plugins/local.quick-notes` (Omarchy doesn't accept symlinked plugin folders) and adds it to the right side of the bar
3. asks which hotkey to use (default `SUPER + N`) and adds a marked block to `~/.config/hypr/bindings.lua`. If the key is already taken, it shows the existing binding and asks before unbinding it. `bindings.lua` is backed up first.

To skip the prompt, run `./install.sh --key "SUPER + ALT + N"`. Run `./install.sh` again after pulling changes. To remove everything, run `./install.sh --uninstall`; your notes file is not touched.

## Usage

| Action | How |
|---|---|
| Dictate a note | Hold the hotkey, speak, release |
| Open the checklist | Click the bar icon |
| Start dictating from the bar | Right-click the icon (click **Stop** in the panel to finish) |
| Open the notes file | Middle-click the icon |
| Notifications on/off | Bell in the panel, or `quick-notes notifications on\|off\|toggle` |

The CLI can also be used on its own:

```
quick-notes start | stop | cancel
quick-notes add <text>        # run text through Codex
quick-notes add-raw <text>    # append verbatim
quick-notes toggle <line> | remove <line> | clear-done
quick-notes notifications [on|off|toggle]
quick-notes path
```

## Configuration

| Setting | Where |
|---|---|
| Notes file | `QUICK_NOTES_FILE` env var (default `~/notes/quick-notes.md`). The bar widget reads `notesFile` from its entry in `~/.config/omarchy/shell.json` |
| Notifications | `~/.config/quick-notes/config` (`notifications=on\|off`) |
| Codex reasoning effort | `QUICK_NOTES_EFFORT` (default `low` for speed) |
| Extra Codex flags | `QUICK_NOTES_CODEX_ARGS`, e.g. `-m <model>` |

Codex runs with `codex exec` in a read-only sandbox and without saving the session (`--ephemeral`). A JSON schema forces its reply into the form `{"items": [...]}`, so the output can always be parsed.

## Known issues

- With a modifier hotkey, letting go of the modifier before the letter may cause Hyprland to miss the release. If recording gets stuck, click **Stop** in the panel. voxtype also stops on its own at `max_duration_secs`. A single key such as `F10` avoids this.

## License

MIT
