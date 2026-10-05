#!/usr/bin/env bash
# Install quick-notes: links the CLI, copies the bar plugin into the Omarchy
# shell config, adds it to the bar, and binds a hold-to-dictate hotkey.
#
#   ./install.sh                     interactive (asks for the hotkey)
#   ./install.sh --key "SUPER + N"   non-interactive
#   ./install.sh --uninstall
#
# Re-run after editing anything in this repo to update the installed copy.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="local.quick-notes"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
BIN="$HOME/.local/bin/quick-notes"
BINDINGS="$HOME/.config/hypr/bindings.lua"
BEGIN_MARK="-- >>> quick-notes (managed by $REPO/install.sh)"
END_MARK="-- <<< quick-notes"
DEFAULT_KEY="SUPER + N"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m! %s\033[0m\n' "$*"; }

remove_bindings_block() {
  [[ -f $BINDINGS ]] || return 0
  sed -i "\|^$BEGIN_MARK|,\|^$END_MARK|d" "$BINDINGS"
  # Also catch blocks written from a different repo path.
  sed -i '/^-- >>> quick-notes /,/^-- <<< quick-notes/d' "$BINDINGS"
}

reload_hyprland() {
  hyprctl reload >/dev/null
  local errors
  errors=$(hyprctl configerrors)
  if [[ -n ${errors//[[:space:]]/} && $errors != *"no errors"* ]]; then
    warn "Hyprland reported config errors:"
    echo "$errors"
    return 1
  fi
}

# "super+shift+n" -> "SUPER + SHIFT + N"
normalize_key() {
  local raw="${1^^}" out="" part
  IFS='+' read -ra parts <<<"$raw"
  for part in "${parts[@]}"; do
    part="${part//[[:space:]]/}"
    [[ -n $part ]] || continue
    out+="${out:+ + }$part"
  done
  echo "$out"
}

# "SUPER + SHIFT + N" -> "SUPER SHIFT + N" (the form `omarchy menu keybindings --print` uses)
display_key() {
  local key="$1"
  local last="${key##* + }" mods="${key% + *}"
  [[ $mods == "$key" ]] && { echo "$last"; return; }
  echo "${mods// + / } + $last"
}

existing_binding() {
  local shown
  shown=$(display_key "$1")
  omarchy menu keybindings --print 2>/dev/null \
    | grep -F -- "$shown " \
    | grep -E "^$(printf '%s' "$shown" | sed 's/[]\[\.*^$+]/\\&/g')[[:space:]]+→" \
    | grep -v "Quick note" || true
}

uninstall() {
  bold "Uninstalling quick-notes"
  quick-notes cancel 2>/dev/null || true
  remove_bindings_block
  reload_hyprland || true
  omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1 || true
  rm -rf "$PLUGIN_DIR"
  [[ -L $BIN ]] && rm -f "$BIN"
  echo "Done. Your notes file was left untouched."
}

key=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --key) key="$2"; shift 2 ;;
    --key=*) key="${1#*=}"; shift ;;
    --uninstall) uninstall; exit 0 ;;
    -h|--help) sed -n '2,9s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

bold "Checking dependencies"
missing=0
for cmd in voxtype codex jq notify-send flock hyprctl omarchy; do
  if ! command -v "$cmd" >/dev/null; then
    warn "missing: $cmd"
    missing=1
  fi
done
[[ $missing -eq 0 ]] || { echo "Install the missing tools and re-run." >&2; exit 1; }
systemctl --user is-active --quiet voxtype || warn "voxtype daemon isn't running (systemctl --user enable --now voxtype)"
codex login status >/dev/null 2>&1 || warn "codex doesn't look logged in (run: codex login)"

bold "Installing CLI → $BIN"
mkdir -p "$(dirname "$BIN")"
chmod +x "$REPO/bin/quick-notes"
ln -sfn "$REPO/bin/quick-notes" "$BIN"

bold "Installing bar plugin → $PLUGIN_DIR"
# Omarchy refuses symlinked plugin folders, so copy.
rm -rf "$PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR"
cp -r "$REPO/plugin/." "$PLUGIN_DIR/"
omarchy plugin validate "$PLUGIN_DIR"

if ! jq -e --arg id "$PLUGIN_ID" '[.bar.layout[]?[]?.id] | index($id)' "$HOME/.config/omarchy/shell.json" >/dev/null 2>&1; then
  # The shell needs a moment to discover a freshly copied plugin.
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    omarchy plugin list 2>/dev/null | grep -q "^$PLUGIN_ID " && break
    sleep 0.5
  done
  omarchy plugin enable "$PLUGIN_ID" --section right --index 0
fi

if [[ -z $key ]]; then
  current=$(sed -n "/^-- >>> quick-notes /,/^-- <<< quick-notes/s/^o.bind(\"\([^\"]*\)\".*/\1/p" "$BINDINGS" 2>/dev/null | head -1)
  suggestion="${current:-$DEFAULT_KEY}"
  echo
  bold "Hotkey"
  echo "Hold the key to talk, release to turn it into notes."
  echo "Examples: SUPER + N, SUPER + ALT + N, F10"
  read -rp "Key [$suggestion]: " key
  key="${key:-$suggestion}"
fi
key=$(normalize_key "$key")

conflict=$(existing_binding "$key")
if [[ -n $conflict ]]; then
  warn "$key is already bound:"
  echo "    $conflict"
  if [[ -t 0 ]]; then
    read -rp "Unbind it and use $key for quick notes? [y/N] " answer
    [[ $answer =~ ^[Yy] ]] || { echo "Aborted. Re-run with a different --key."; exit 1; }
  fi
fi

bold "Binding $key (hold to dictate) in $BINDINGS"
mkdir -p "$(dirname "$BINDINGS")"
touch "$BINDINGS"
cp "$BINDINGS" "$BINDINGS.bak.$(date +%s)"
remove_bindings_block
{
  echo "$BEGIN_MARK"
  [[ -n $conflict ]] && echo "hl.unbind(\"$key\")  -- was: ${conflict#*→ }"
  echo "o.bind(\"$key\", \"Quick note (hold to dictate)\", \"$BIN start\")"
  echo "o.bind(\"$key\", \"Quick note (release to save)\", \"$BIN stop\", { release = true })"
  echo "$END_MARK"
} >>"$BINDINGS"
reload_hyprland

omarchy bar set "$PLUGIN_ID" hotkey "$key" >/dev/null 2>&1 || true

echo
bold "Installed."
echo "  • Hold $key, speak, release → Codex turns it into checklist items"
echo "  • Click the note icon (top right) to view / tick off / type notes"
echo "  • Right-click the icon to start dictating, middle-click to open the file"
echo "  • Notes: $(quick-notes path)"
