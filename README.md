# Photo Walls

An [Omarchy](https://omarchy.org) shell plugin that turns your theme's wallpapers into a living gallery, and credits the people who took them.

- **A photo per workspace.** Every workspace keeps its own photograph. Switching workspaces swaps it instantly, so you land on that workspace's photo instead of watching it change.
- **Fresh every 15 minutes.** The photos are dealt out again, with a gentle cross-fade.
- **One click for another.** A small picture icon in the bar gives the current workspace a new photo. Hover it to see who took the one on screen.
- **Photographers credited.** A pill in the bottom-left corner of the desktop names the place and the photographer. Click it to open their profile.

It only acts while the active theme ships a `credits.json`. Other themes keep Omarchy's normal single wallpaper.

## Install

```bash
omarchy plugin add https://github.com/eludif/omarchy-photo-walls --enable
```

Update with `omarchy plugin update eludif.photo-walls`. Turn it off with `omarchy plugin disable eludif.photo-walls`.

Themes that support it include [Omarchy Nigeria](https://github.com/eludif/omarchy-nigeria-theme).

## Keyboard shortcut (optional)

To get a new photo from the keyboard, add a line to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + CTRL + SHIFT + N", "Next wallpaper", "omarchy-shell photo-walls next")
```

Other commands: `omarchy-shell photo-walls shuffle` re-deals every workspace now, and `omarchy-shell photo-walls credit` prints the current credit.

## For theme authors

Ship a `credits.json` at the root of your theme, keyed by the wallpaper's filename in `backgrounds/`:

```json
{
  "01-national-theatre-lagos-by-paul-uchechukwu.jpg": {
    "place": "National Theatre, Lagos",
    "photographer": "Paul Uchechukwu",
    "profile": "https://www.pexels.com/@paul-uchechukwu-246994638/"
  }
}
```

- Only photos listed in `credits.json` are dealt out.
- `place` and `photographer` are shown as plain text. `profile` must be an `https://` link.
- Extra fields are ignored, so the file can also hold your licence notes.

## Details

- Assignments are kept in `~/.local/state/eludif.photo-walls/workspaces.json`, so each workspace keeps its photo across restarts.
- Workspace switches use Omarchy's instant background swap. The 15-minute re-deal and the bar icon use the normal cross-fade.
- No network access. Links open in your browser only when you click the credit.

## Licence

MIT. See [LICENSE](LICENSE).
