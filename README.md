# quick-notes

Voice quick notes for [Omarchy](https://omarchy.org). Hold a hotkey, say what's on your mind, let go — [voxtype](https://github.com/peteonrails/voxtype) transcribes it, an agent ([Codex](https://github.com/openai/codex) or [Claude Code](https://github.com/anthropics/claude-code), your choice) turns it into short checklist items, and they land in a markdown notepad. A note icon in the bar shows the list.

```
hold SUPER+N → speak → release → - [ ] Buy milk tomorrow
                                 - [ ] Email Sam about the invoice before Friday
```

## Features

- **Hold-to-talk hotkey.** Press to record, release to save. No windows pop up.
- **Codex or Claude Code.** Choose the agent at install time, switch it with one click in the panel, or run `quick-notes agent`.
- **Bar widget.** The icon pulses while you're recording and shows an hourglass while the agent is writing. Click it to open the checklist, where you can tick, delete or type notes, clear finished items, or open the file.
- **Plain markdown.** Notes go to `~/notes/quick-notes.md` as `- [ ]` / `- [x]` lines, so any editor or sync tool can use them.
- **Nothing gets lost.** If the agent fails, the raw transcript is saved as a note.
- **Optional notifications.** Turn the "notes added" notifications on or off. Errors always notify.

## Requirements

- Omarchy (Hyprland plus the Quickshell-based `omarchy-shell`)
- `voxtype` with its daemon running (`systemctl --user enable --now voxtype`)
- At least one agent CLI, logged in: `codex` (`codex login`) or `claude` (Claude Code)
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
3. asks which agent to use (if both are installed)
4. asks which hotkey to use (default `SUPER + N`) and adds a marked block to `~/.config/hypr/bindings.lua`. If the key is already taken, it shows the existing binding and asks before unbinding it. `bindings.lua` is backed up first.

To skip the prompts, run `./install.sh --key "SUPER + ALT + N" --agent claude`. Run `./install.sh` again after pulling changes. To remove everything, run `./install.sh --uninstall`; your notes file is not touched.

## Usage

| Action | How |
|---|---|
| Dictate a note | Hold the hotkey, speak, release |
| Open the checklist | Click the bar icon |
| Start dictating from the bar | Right-click the icon (click **Stop** in the panel to finish) |
| Open the notes file | Middle-click the icon |
| Switch agent | **CODEX / CLAUDE** button in the panel, or `quick-notes agent codex\|claude\|toggle` |
| Notifications on/off | Bell in the panel, or `quick-notes notifications on\|off\|toggle` |

The CLI can also be used on its own:

```
quick-notes start | stop | cancel
quick-notes add <text>        # run text through the agent
quick-notes add-raw <text>    # append verbatim
quick-notes toggle <line> | remove <line> | clear-done
quick-notes notifications [on|off|toggle]
quick-notes agent [codex|claude|toggle]
quick-notes path
```

## Configuration

| Setting | Where |
|---|---|
| Notes file | `QUICK_NOTES_FILE` env var (default `~/notes/quick-notes.md`). The bar widget reads `notesFile` from its entry in `~/.config/omarchy/shell.json` |
| Agent | `~/.config/quick-notes/config` (`agent=codex\|claude`). The `QUICK_NOTES_AGENT` env var overrides it |
| Notifications | `~/.config/quick-notes/config` (`notifications=on\|off`) |
| Reasoning effort | `QUICK_NOTES_EFFORT` (default `low` for speed), used by both agents |
| Extra agent flags | `QUICK_NOTES_CODEX_ARGS` / `QUICK_NOTES_CLAUDE_ARGS`, e.g. `--model <model>` |

Both agents get the same prompt plus a JSON schema that forces the reply into the form `{"items": [...]}`, so the output can always be parsed:

- **Codex** runs with `codex exec` in a read-only sandbox and without saving the session (`--ephemeral`).
- **Claude Code** runs with `claude -p --json-schema` with all tools disabled (`--tools ""`) and without saving the session (`--no-session-persistence`). It runs from its own runtime directory (`$XDG_RUNTIME_DIR/quick-notes`), so no project `CLAUDE.md` is loaded.

In testing, Claude Code took about 6s per note and Codex about 15s.

## Known issues

- With a modifier hotkey, letting go of the modifier before the letter may cause Hyprland to miss the release. If recording gets stuck, click **Stop** in the panel. voxtype also stops on its own at `max_duration_secs`. A single key such as `F10` avoids this.

## License

MIT
