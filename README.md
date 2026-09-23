# Wallpaper Roulette

An [Omarchy](https://omarchy.org) bar plugin that rotates through your wallpapers
on a timer and **switches the theme to match each wallpaper** as it changes.

Point it at a folder of wallpapers organized by theme and every rotation picks a
random image, applies its theme, and sets that exact wallpaper. Leave the folder
blank and it rotates through the built-in Omarchy wallpapers of every installed
theme instead.

![preview](preview.png)

## How the theme matching works

A wallpaper's theme is inferred from **the name of the folder that contains it**:

```
~/.config/omarchy/backgrounds/
├── tokyo-night/
│   ├── spacePiano.png
│   └── skullIsland.png
├── everforest/
│   └── foggyWoods.png
└── catppuccin/
    └── catGirl.png
```

A wallpaper under `tokyo-night/` switches to the `tokyo-night` theme; one under
`everforest/` switches to `everforest`, and so on. Folder names that aren't an
installed theme still rotate — they just keep whatever theme is current. This is
the same layout Omarchy already uses for user backgrounds, so wallpapers placed
here also show up in the normal background switcher.

## Install

```bash
omarchy plugin add https://github.com/keegan-sucks/omarchy-wallpaper-roulette --enable
```

Then place the icon in the bar (Omarchy menu → Bar → add widget) if it isn't
already, and open its settings to choose your wallpaper folder.

## Settings

| Setting | Default | Meaning |
|---|---|---|
| **Wallpaper directory** | *(empty)* | Folder laid out as `<dir>/<theme-slug>/image`. Empty = the built-in Omarchy wallpapers. |
| **Rotate every (minutes)** | `30` | How often to switch wallpaper. |
| **Auto-rotate** | `on` | Rotate on the timer. Off = change only on click or from the picker. |
| **Match theme to wallpaper** | `on` | Switch the Omarchy theme to the wallpaper's folder name. |
| **Notify on change** | `off` | Desktop notification on each rotation. |
| **Bar glyph** | `󰋫` | Nerd Font glyph shown in the bar. |

## Controls

- **Left-click** the bar icon: shuffle to a new wallpaper now.
- **Right-click**: open the wallpaper picker.
- From a script or keybinding:
  ```bash
  omarchy-shell -q io.github.keegan-sucks.wallpaper-roulette next     # shuffle now
  omarchy-shell -q io.github.keegan-sucks.wallpaper-roulette pick     # open the picker
  omarchy-shell -q io.github.keegan-sucks.wallpaper-roulette toggle   # pause/resume auto-rotate
  ```

## The wallpaper picker

Right-clicking the icon opens the stock Omarchy image carousel (the one behind
`omarchy-theme-bg-switcher` and the theme switcher), filled with **every
wallpaper the roulette can land on** across all of your theme folders, grouped
by theme. The current wallpaper is pre-selected.

- **←/→** or **Tab** move through the carousel, **Enter** or a click on the
  large preview applies, **Esc** dismisses.
- Each wallpaper is labelled `<Theme> <Name>`; just start typing to filter, so
  typing `tokyo` shows only the Tokyo Night wallpapers.
- Picking a wallpaper applies its theme (when *Match theme to wallpaper* is on)
  exactly as an automatic rotation would, and resets the rotation timer.

The picker is fed through symlinks named `<theme>--<file>` under
`~/.cache/omarchy/wallpaper-roulette/picker/`, which is what lets it show the
theme in the label and keep two themes' identically named wallpapers apart.
That folder and the thumbnails are refreshed in the background when the bar
loads, so the picker opens instantly.

## Rotate from the command line

The plugin is a thin wrapper around `scripts/rotate.sh` and `scripts/pick.sh`,
which work on their own:

```bash
scripts/rotate.sh --dir ~/.config/omarchy/backgrounds --apply-theme 1
scripts/rotate.sh --dry-run          # show what it would pick, change nothing
scripts/rotate.sh --list             # print every candidate as "theme<TAB>path"
scripts/rotate.sh --set ~/Pictures/wall.png --theme nord   # apply one wallpaper
scripts/pick.sh --dir ~/.config/omarchy/backgrounds        # open the picker
```

## Dependencies

Omarchy (uses `omarchy-theme-set` and `omarchy-theme-bg-set`, which ship with
it). No other external dependencies.

## Remove

```bash
omarchy plugin remove io.github.keegan-sucks.wallpaper-roulette
```

## License

MIT — see [LICENSE](LICENSE).
