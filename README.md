# Colores (v1.0.0)

A lightweight macOS menu bar color picker — a native Apple Silicon replacement for [Couleurs](https://couleursapp.com/), whose Intel-only binary macOS is dropping support for.

> Running an older version? Compare the number above to the one in **About Colores** (right-click the menu bar icon), then re-download `Colores.app` from this repo if you're behind.

**Menu bar:** click the eyedropper icon to open the picker.

**Popup:**
- Click the dashed **+** tile — the top preview before you've picked anything, or the first tile in the history strip afterward — to sample any pixel on screen with macOS's native loupe (`NSColorSampler`)
- Every pick copies to the clipboard automatically — a "✓ Copied" note flashes over the preview to confirm it
- Preview swatch + value; click either one (or ⌘C) to copy again in the current format
- Hex / RGB format toggle — copies automatically the instant you switch formats
- Recent-colors history: click a swatch to copy it again; hover a swatch and click the **×** in its corner to remove just that one, or **Clear** to wipe the whole strip (the strip stays hidden entirely until you've picked at least one color)

## How it works

Screen sampling uses `NSColorSampler`, Apple's own built-in eyedropper/loupe API (the same one behind Digital Color Meter and the system color panel) — available since macOS 10.15, which didn't exist yet when the original Couleurs shipped its own custom loupe. That's the whole reason this can be this small: no custom screen-capture or magnifier code needed.

The picker panel dismisses itself on an outside click, but that dismissal is deliberately paused for the duration of an active sample — otherwise the very click you use to confirm a color on screen would also count as "clicking away" and close the panel before the color registered.

## Requirements

- macOS 10.15 or later
- Xcode Command Line Tools (`xcode-select --install`)

## Download & run (no build required)

1. Download `Colores.app` from this repo
2. Move it to your `/Applications` folder
3. Right-click → **Open** → **Open** (required once to bypass Gatekeeper on unsigned apps)

## Build from source

```bash
git clone https://github.com/bereto-dev/colores.git
cd colores
make
open Colores.app
```

## First launch security

Because the app isn't signed or notarized (no Apple Developer account needed), macOS will block it the first time. Right-click → **Open** → **Open** to bypass Gatekeeper once.

## Settings

Right-click the menu bar icon → **Check for Updates…** / **About Colores** / **Quit Colores**. Inside the picker panel, the format toggle (Hex/RGB) is remembered between launches (`UserDefaults`), same as the recent-colors history.

## Icon

Using a placeholder icon for now — a proper one is coming later.

## Known limitation

The magnifier's zoom level when sampling is controlled entirely by macOS (`NSColorSampler` exposes no configuration at all — no magnification factor, no pixel size). It can't be made bigger without abandoning the native sampler and building a fully custom loupe from scratch, the way the original Couleurs did. Not planned unless that trade-off is worth it.

## Out of scope for v1

Deliberately left out of this rebuild, compared to the original Couleurs: a custom color-format template editor, `NSColor`/`UIColor`/`rgba()` copy formats, pasting (⌘V) to parse hex/rgb from the clipboard, a global system-wide keyboard shortcut, and Sparkle-style auto-updates (use **Check for Updates…** to jump to this repo instead). All straightforward to add later if needed.

## Origin

Built by Roberto Pacheco to replace the discontinued Couleurs app after macOS flagged it for losing Intel-app compatibility.

## Support

If you find Colores useful, you can buy me a coffee ☕

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-bereto-FFDD00?style=flat&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/bereto)

Built by [devteam.partners](https://devteam.partners/about-us) 🌐

---

Built with Swift + AppKit. No external dependencies.
