# AGENTS.md (local — do not commit)

Private notes for Cursor agents on this machine. **Never add this file to git, never push it.** Copy it by hand to other laptops if you want the same context. It is ignored via `.git/info/exclude` (local only, not the shared `.gitignore`).

Public docs for users live in `README.md` (English). Talk to Roberto in Spanish.

Repo: https://github.com/bereto-dev/colores
Downloads (the `.app`, not this repo): https://bereto.gumroad.com/l/colores
Sibling README/changelog template: `../asana-status/README.md`

---

## What this is

Colores is a tiny Swift + AppKit menu-bar color picker. It replaces [Couleurs](https://couleursapp.com/), which was Intel-only. No Xcode project, no SPM, no third-party deps. `make` compiles `Sources/*.swift` with `swiftc` and `lipo` into a universal `Colores.app`.

Current version: **1.2.0** (build `3`) in `Resources/Info.plist`.

## Layout

```
Sources/                 # all Swift — this is the app
  main.swift             # NSApplication + AppDelegate + run loop
  AppDelegate.swift      # accessory policy, Dock reopen → show panel
  StatusBarController.swift  # menu bar icon, left/right click, updates/about/quit
  PickerPanel.swift      # the floating panel + FormatToggle + swatches
  ColorFormatter.swift   # Hex / RGB only
  ColorHistory.swift     # UserDefaults: format + last 5 hex colors
  PasteboardWriter.swift # copy string to clipboard
  AboutWindow.swift      # version, origin, Gumroad / coffee / site
Resources/
  Info.plist             # source of truth for bundle metadata
  AppIcon.icns
Makefile                 # universal x86_64 + arm64, min macOS 11.0
README.md                # public docs + changelog
colores_cover.jpg        # README hero (not screenshot.png — that file is gone)
Colores.app/             # local build only — gitignored, never commit
```

`make` copies `Resources/Info.plist` and `AppIcon.icns` into the bundle. Edit `Resources/Info.plist`, not the copy inside `Colores.app`.

## How the app runs

1. `LSUIElement` = true → no Dock tile while running; eyedropper lives in the menu bar.
2. Left-click icon toggles the panel. Right-click: Check for Updates / About / Quit.
3. `PickerPanel` is a borderless non-activating `NSPanel` at `.floating`, joins all Spaces. It does **not** dismiss on outside click. First show anchors under the icon; after that it stays where the user dragged it (unless that point is off every screen).
4. Sampling is `NSColorSampler` (system loupe). Zoom is not configurable — do not try to expose a zoom API; it does not exist. Custom loupe is out of scope unless Roberto asks.
5. Every pick and every Hex/RGB switch copies to the clipboard. `⌘C` copies too.
6. Dock: if the user dragged `Colores.app` to the Dock themselves, `applicationShouldHandleReopen` must show the panel (cold launch and later clicks).
7. **Check for Updates** (menu and About) opens Gumroad, not GitHub.

## Hex / RGB toggle (`FormatToggle` in `PickerPanel.swift`)

Do **not** use `NSSegmentedControl`. On Intel it draws Aqua’s white selected pill + dark unselected labels, unreadable on this dark panel.

Custom control, already tuned:

- Active fill: `#515153`
- Inactive fill: `#2A2A2C`
- Active text: white, semibold
- Inactive text: white @ 0.55

Both states must stay visually distinct. Do not paint active and inactive the same color.

## Build

```bash
killall Colores   # replacing the binary while it runs is messy
make              # universal: x86_64 + arm64, deployment 11.0
open Colores.app
```

- Min OS is **11** (SF Symbols), not 10.15, even though `NSColorSampler` existed in Catalina.
- `LSMinimumSystemVersion` is an **OS** floor, not a CPU. An arm64-only binary will not open on Intel no matter what the plist says. Always ship universal (`lipo`).
- Intel MacBook Pro Mid 2015 (and similar) is a real target. Default `swiftc` on Apple Silicon produces arm64-only — that was v1.1.0 and it failed on Intel.
- `make` on a Mid 2015 Intel box can take a while; that is expected.

After source changes that should reach users: rebuild, then Roberto uploads the `.app` to Gumroad. GitHub is source only.

## Version bumps

When shipping a user-visible release, keep these in sync:

1. `Resources/Info.plist` — `CFBundleShortVersionString` + increment `CFBundleVersion`
2. README title: `# Colores (vX.Y.Z)`
3. README **Changelog** (see below)
4. Rebuild so the About window matches

Do not bump the version unless Roberto asks or you are clearly shipping.

## README conventions (public, English)

Match **AsanaStatus**, not a one-line “What’s new” under the version callout.

- Hero image: `colores_cover.jpg`. `screenshot.png` was removed; do not add it back.
- Version check quote: compare README number to **About Colores**, then re-download from Gumroad (not “from this repo”).
- Download section: Gumroad link, then move to `/Applications`, Gatekeeper right-click Open.
- Changelog, newest first, before Origin:

  ```
  ### X.Y.Z — Short user-facing title
  Paragraph (or bullets if the release had several things).
  ```

  Voice: plain English, what the user notices, not commit dumps. See `../asana-status/README.md`.

## Git

- **Always `git fetch` (and fast-forward if behind) before editing.** Roberto commits from other machines (e.g. cover image).
- Never commit `Colores.app/`. It is gitignored on purpose.
- Never commit `AGENTS.md`. It is in `.git/info/exclude` on this laptop; add the same line on other clones.
- `.gitignore` **is** tracked. It must stay in the repo so `Colores.app/` is not uploaded by accident. Do not treat “upload gitignore” as a pending task — it is already on `main`. Do not add `AGENTS.md` to the shared `.gitignore` unless Roberto asks (that would be a repo commit).
- Do not commit or push unless Roberto asks. When you do: no `--no-verify`, no force-push, no amend of published commits.
- Commit messages: short imperative subject, optional body with why (see `git log`).

## Already learned — do not re-do

| Mistake | What to do instead |
|---|---|
| Ship arm64-only `.app`; Intel Macs cannot open it | `Makefile` already builds universal via `lipo` |
| Treat “macOS 10.15+” as Intel support | OS version ≠ architecture |
| `NSSegmentedControl` on the dark panel | Keep `FormatToggle` |
| Active and inactive toggle the same `#515153` | Active `#515153`, inactive `#2A2A2C` |
| Commit `Colores.app` for “download from this repo” | Gumroad only |
| Changelog as a “What’s new in x.y.z” blurb at the top | `## Changelog` section like AsanaStatus |
| README still pointing at `screenshot.png` | `colores_cover.jpg` |
| Check for Updates → GitHub | Gumroad |
| Edit without fetch | Fetch first |
| Put this file on GitHub | Local only |

## Out of scope unless asked

Custom loupe / magnifier zoom, extra copy formats (`NSColor`, `UIColor`, `rgba()`, templates), paste-to-parse, global hotkey, Sparkle, a real (non-placeholder) app icon, signing/notarization.
