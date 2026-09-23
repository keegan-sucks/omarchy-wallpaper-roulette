#!/bin/bash
# omarchy-wallpaper-roulette: choose a wallpaper in the stock Omarchy picker.
#
# Usage: pick.sh [--dir DIR] [--apply-theme 0|1] [--notify 0|1]
#        pick.sh --prepare [--dir DIR]
#
# Opens omarchy-menu-images (the same carousel behind the Omarchy background
# and theme switchers) over every wallpaper the roulette can rotate to, then
# applies the chosen one through rotate.sh --set so it gets the same theme
# matching, timer stamping and notification as an automatic rotation.
#
# The picker takes directories, dedups images by file name, and labels each
# one by its file name only. Wallpapers here come from many theme folders, so
# the stock omarchy.png of every theme would collapse into one entry and no
# label would say which theme a wallpaper belongs to. To get around that, the
# candidates are staged as symlinks named "<theme>--<file>" in one cache
# directory and the picker is pointed at that. Labels then read
# "Tokyo Night SpacePiano", typing a theme name filters to it, and the
# carousel is grouped by theme. The staging directory is rebuilt only when the
# candidate set changes, so the picker's thumbnail and row caches stay warm.
#
#   --prepare   Only (re)build the staging directory and generate any missing
#               thumbnails, without opening the picker. The bar widget runs
#               this in the background at startup so the first right-click
#               opens instantly.

set -uo pipefail

HERE="$(dirname "$(readlink -f "$0")")"
ROTATE="$HERE/rotate.sh"

DIR=""
APPLY_THEME=1
NOTIFY=0
PREPARE=0

while (($#)); do
  case "$1" in
    --dir) DIR="${2:-}"; shift 2 ;;
    --apply-theme) APPLY_THEME="${2:-1}"; shift 2 ;;
    --notify) NOTIFY="${2:-0}"; shift 2 ;;
    --prepare) PREPARE=1; shift ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "pick.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ $DIR == "~"* ]] && DIR="${HOME}${DIR:1}"

STAGE="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/wallpaper-roulette/picker"
MANIFEST="$STAGE.tsv" # link<TAB>theme<TAB>image, one row per staged wallpaper
CURRENT_BG="$(readlink -f "$HOME/.local/state/omarchy/current/background" 2>/dev/null || true)"

# Ask rotate.sh for the candidates (theme<TAB>path) and lay out the staging
# manifest: link name = "<theme>--<file>", or just "<file>" for images sitting
# flat in DIR without a theme folder.
desired=""
while IFS=$'\t' read -r theme image; do
  [[ -n $image ]] || continue
  name="${image##*/}"
  link="$STAGE/${theme:+$theme--}$name"
  desired+="$link"$'\t'"$theme"$'\t'"$image"$'\n'
done < <(bash "$ROTATE" --list ${DIR:+--dir "$DIR"} | sort -t $'\t' -k1,1 -k2,2)

if [[ -z $desired ]]; then
  echo "pick.sh: no wallpapers found${DIR:+ in $DIR}" >&2
  [[ $PREPARE == 0 ]] && omarchy-notification-send -g "󰋫" "Wallpaper Roulette" "No wallpapers found${DIR:+ in $DIR}" -t 3000 2>/dev/null
  exit 1
fi

# Rebuild the staging directory only when the candidate set changed or a link
# went missing. Its mtime keys the picker's row cache, so leaving it untouched
# keeps reopening cheap. Serialize with a lock: the widget's --prepare and a
# right-click, or copies on several monitors, may run at the same moment.
mkdir -p "$(dirname "$STAGE")" 2>/dev/null
if exec {lockfd}>"$STAGE.lock" 2>/dev/null; then
  flock -w 30 "$lockfd" 2>/dev/null || true
fi

stale=0
if [[ ! -d $STAGE ]] || ! cmp -s "$MANIFEST" <(printf '%s' "$desired"); then
  stale=1
else
  while IFS=$'\t' read -r link _ _; do
    [[ -n $link ]] || continue
    [[ -L $link ]] || { stale=1; break; }
  done <<<"$desired"
fi

if ((stale)); then
  tmp="$(mktemp -d "$STAGE.XXXXXX")" || exit 1
  chmod 755 "$tmp"
  while IFS=$'\t' read -r link _ image; do
    [[ -n $link ]] || continue
    ln -s "$image" "$tmp/${link##*/}"
  done <<<"$desired"
  rm -rf "$STAGE"
  mv "$tmp" "$STAGE"
  printf '%s' "$desired" >"$MANIFEST"
fi

exec {lockfd}>&-

# Pre-select the wallpaper that is on screen now, if it is among the staged
# ones. The picker matches --selected against its own list by path, so hand
# it the staged link rather than the real file.
selected=""
if [[ -n $CURRENT_BG ]]; then
  while IFS=$'\t' read -r link _ image; do
    [[ -n $link ]] || continue
    if [[ "$(readlink -f "$image" 2>/dev/null)" == "$CURRENT_BG" ]]; then
      selected="$link"
      break
    fi
  done <<<"$desired"
fi

if ((PREPARE)); then
  exec omarchy-menu-images --cache-only "$STAGE"
fi

choice="$(omarchy-menu-images ${selected:+--selected "$selected"} --show-labels --filterable "$STAGE")"
[[ -n $choice ]] || exit 0 # dismissed

theme=""
image=""
while IFS=$'\t' read -r link t i; do
  if [[ $link == "$choice" ]]; then
    theme="$t"
    image="$i"
    break
  fi
done <<<"$desired"

if [[ -z $image ]]; then
  # Not one of ours (the staging dir changed underneath us). Apply the file
  # itself and let rotate.sh infer the theme from its location.
  image="$(readlink -f "$choice" 2>/dev/null || printf '%s' "$choice")"
fi

exec bash "$ROTATE" --set "$image" ${theme:+--theme "$theme"} --apply-theme "$APPLY_THEME" --notify "$NOTIFY"
