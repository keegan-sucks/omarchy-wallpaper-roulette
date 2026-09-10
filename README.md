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
| **Auto-rotate** | `on` | Rotate on the timer. Right-click the bar icon to toggle. |
| **Match theme to wallpaper** | `on` | Switch the Omarchy theme to the wallpaper's folder name. |
| **Notify on change** | `off` | Desktop notification on each rotation. |
| **Bar glyph** | `󰋫` | Nerd Font glyph shown in the bar. |

## Controls

- **Left-click** the bar icon: shuffle to a new wallpaper now.
- **Right-click**: pause / resume auto-rotation.
- From a script or keybinding:
  ```bash
  omarchy-shell -q io.github.keegan-sucks.wallpaper-roulette next     # shuffle now
  omarchy-shell -q io.github.keegan-sucks.wallpaper-roulette toggle   # pause/resume
  ```

## Rotate from the command line

The plugin is a thin wrapper around `scripts/rotate.sh`, which works on its own:

```bash
scripts/rotate.sh --dir ~/.config/omarchy/backgrounds --apply-theme 1
scripts/rotate.sh --dry-run          # show what it would pick, change nothing
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
