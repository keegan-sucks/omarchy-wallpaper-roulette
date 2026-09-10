#!/bin/bash
# omarchy-wallpaper-roulette: pick a random wallpaper and apply its theme.
#
# Usage: rotate.sh [--dir DIR] [--apply-theme 0|1] [--notify 0|1] [--dry-run]
#
# The chosen wallpaper's theme is inferred from the name of the directory that
# contains it: a wallpaper at "<DIR>/tokyo-night/foo.jpg" belongs to the
# "tokyo-night" theme. When --apply-theme is on and that name matches an
# installed Omarchy theme, the theme is switched (without disturbing the
# background) and then the exact wallpaper is set. Wallpapers whose parent
# directory is not an installed theme still rotate; they just keep the current
# theme.
#
# With no --dir (or an empty/one that doesn't exist), it rotates through the
# default Omarchy wallpapers: the stock backgrounds shipped with every installed
# theme, plus any user backgrounds under ~/.config/omarchy/backgrounds/<slug>/.

set -uo pipefail

DIR=""
APPLY_THEME=1
NOTIFY=0
DRY_RUN=0

while (($#)); do
  case "$1" in
    --dir) DIR="${2:-}"; shift 2 ;;
    --apply-theme) APPLY_THEME="${2:-1}"; shift 2 ;;
    --notify) NOTIFY="${2:-0}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "rotate.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Expand a leading ~ the shell didn't (values come from JSON settings).
[[ $DIR == "~"* ]] && DIR="${HOME}${DIR:1}"

OMARCHY_THEMES_PATH="${OMARCHY_PATH:-/usr/share/omarchy}/themes"
USER_THEMES_PATH="$HOME/.config/omarchy/themes"
USER_BG_PATH="$HOME/.config/omarchy/backgrounds"
CURRENT_THEME_NAME_FILE="$HOME/.local/state/omarchy/current/theme.name"

IMAGE_GLOB=(-iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp')

# Set of installed theme slugs (directory names under the theme paths).
declare -A INSTALLED_THEMES=()
while IFS= read -r slug; do
  [[ -n $slug ]] && INSTALLED_THEMES["$slug"]=1
done < <({ ls -1 "$OMARCHY_THEMES_PATH" 2>/dev/null; ls -1 "$USER_THEMES_PATH" 2>/dev/null; } | sort -u)

is_installed_theme() { [[ -n ${INSTALLED_THEMES[$1]+x} ]]; }

# Build a list of "theme<TAB>path" candidates.
CANDIDATES=()

add_dir_images() {
  # $1 = directory, $2 = theme slug to tag its images with ("" = none)
  local d="$1" theme="$2" f
  [[ -d $d ]] || return 0
  while IFS= read -r -d '' f; do
    CANDIDATES+=("$theme"$'\t'"$f")
  done < <(find -L "$d" -maxdepth 1 -type f \( "${IMAGE_GLOB[@]}" \) -print0 2>/dev/null)
}

if [[ -n $DIR && -d $DIR ]]; then
  # Custom directory. Prefer the <DIR>/<theme-slug>/<image> layout; every
  # immediate subdirectory contributes its images tagged with its own name.
  shopt -s nullglob
  for sub in "$DIR"/*/; do
    slug="$(basename "$sub")"
    add_dir_images "$sub" "$slug"
  done
  shopt -u nullglob
  # Also accept images sitting directly in DIR (flat layout, no theme change).
  add_dir_images "$DIR" ""
else
  # Default: the stock Omarchy wallpapers for every installed theme, plus any
  # user backgrounds the user has added for those themes.
  for slug in "${!INSTALLED_THEMES[@]}"; do
    add_dir_images "$OMARCHY_THEMES_PATH/$slug/backgrounds" "$slug"
    add_dir_images "$USER_THEMES_PATH/$slug/backgrounds" "$slug"
    add_dir_images "$USER_BG_PATH/$slug" "$slug"
  done
fi

TOTAL=${#CANDIDATES[@]}
if ((TOTAL == 0)); then
  echo "rotate.sh: no wallpapers found${DIR:+ in $DIR}" >&2
  [[ $NOTIFY == 1 ]] && omarchy-notification-send -g "󰋫" "Wallpaper Roulette" "No wallpapers found${DIR:+ in $DIR}" -t 3000 2>/dev/null
  exit 1
fi

# Avoid repeating the current wallpaper when there is more than one option.
CURRENT_BG="$(readlink -f "$HOME/.local/state/omarchy/current/background" 2>/dev/null || true)"
PICK=""
for _ in 1 2 3 4 5; do
  PICK="${CANDIDATES[RANDOM % TOTAL]}"
  CAND_PATH="${PICK#*$'\t'}"
  [[ "$(readlink -f "$CAND_PATH" 2>/dev/null)" != "$CURRENT_BG" || $TOTAL -eq 1 ]] && break
done

THEME="${PICK%%$'\t'*}"
IMAGE="${PICK#*$'\t'}"
CURRENT_THEME="$(cat "$CURRENT_THEME_NAME_FILE" 2>/dev/null || true)"

if [[ $DRY_RUN == 1 ]]; then
  echo "candidates=$TOTAL"
  echo "theme=$THEME"
  echo "image=$IMAGE"
  echo "current_theme=$CURRENT_THEME"
  if [[ $APPLY_THEME == 1 && -n $THEME ]] && is_installed_theme "$THEME" && [[ $THEME != "$CURRENT_THEME" ]]; then
    echo "action=set-theme+bg"
  else
    echo "action=set-bg-only"
  fi
  exit 0
fi

# Switch theme only when it actually differs, and set the exact wallpaper.
if [[ $APPLY_THEME == 1 && -n $THEME ]] && is_installed_theme "$THEME" && [[ $THEME != "$CURRENT_THEME" ]]; then
  OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy-theme-set "$THEME"
fi
omarchy-theme-bg-set "$IMAGE"

if [[ $NOTIFY == 1 ]]; then
  name="$(basename "$IMAGE")"
  omarchy-notification-send -g "󰋫" "Wallpaper Roulette" "${THEME:+$THEME · }${name}" -t 3000 2>/dev/null
fi
