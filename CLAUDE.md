# CLAUDE.md – Touch Bar Piano

macOS app that turns the MacBook Pro Touch Bar into a piano (Swift, AppKit + SwiftUI, no Xcode project).
Public repo: github.com/maylaender/touchbar-piano · current release: see `VERSION`.

## Current status (update this section when it changes)
- Stable: **v3.4** on `main` – menu bar, settings window (Touch Bar mode, appearance, start instrument), About,
  drag & drop / Open with, Dock menu, window autosave, dark mode.
- Not yet confirmed on real hardware: the Touch Bar visible-area fix (rightmost key), audio and touch behaviour.
- Owner's wish: no menu-bar status icon – quitting the app must remove the piano from the Touch Bar.

## Working with the owner
- Answer in **German** (Swiss: no "ß", keyboard has no direct `[ ]`). Code, commits and README in English.
- The owner values **short answers, low effort, efficiency**. Short plan first for bigger features, then build.
- Owner tests on a **MacBook Pro 13" 2019 (Intel, Touch Bar)**. You usually cannot: say clearly what was and was not verified.
- Ask the owner whether a change ships as **beta** (pre-release for testing, e.g. hardware-only fixes) or directly as
  a stable release. Explain plans and results without jargon.

## 🔒 Privacy – most important rule
The repo is public. **No personal data, credentials or keys – ever, in any commit.**
- Commit identity must stay anonymous:
  `git config user.name "touchbar-piano" && git config user.email "touchbar-piano@users.noreply.github.com"`
- Enable the shared hook once per clone: `git config core.hooksPath .githooks`
- Create the local-only file `.git/info/private-patterns` (one regex per line) with the owner's first name,
  last name and email domain – ask the owner or take them from the session context. **Never commit this file
  or write these values anywhere in the repo.**
- Run `.githooks/scan-history.sh` before every push and report the result to the owner.
- Images: only plain PNG/GIF data – strip metadata (e.g. `iCCP`, text chunks) before committing.
- If the hook fires on a harmless word, rename the code (e.g. a variable) instead of weakening the hook.

## Build, test, release
- No Mac in the cloud session → **GitHub Actions (`.github/workflows/build.yml`) is the build machine.**
  Push a branch listed under `on.push.branches`, then poll `gh api repos/maylaender/touchbar-piano/actions/runs`.
- CI steps: `build.sh` (universal x86_64 + arm64, macOS 11+, icon via `iconutil`) →
  `PIANO_SELFTEST=1` (songs parse, MIDI round-trip) → `PIANO_SNAPSHOT=dir` (renders real screenshots,
  artifact `snapshot`) → artifact `Piano.app` → release.
- **Release = change `VERSION` and push.** The session cannot create releases or push tags itself;
  the workflow creates tag + release when `VERSION` has no release yet. Versions containing `beta` become
  pre-releases. Release text comes from `release-notes.md`.
- Work happens on a branch per version (e.g. `v3.1`, `v3.2-beta`); stable work is merged into `main` (fast-forward).
  **A new branch must be added to `on.push.branches` in the workflow**, otherwise CI does not build it.

## Code map (`Sources/`)
| File | Content |
|---|---|
| `main.swift` | App start, window, keyboard shortcuts (local event monitor), Touch Bar mode switch, open files, CI snapshot sequence |
| `Menu.swift` | `MenuActions`: menu bar (all functions + shortcuts, checkmarks via `validateMenuItem`), Dock menu, About panel; `describe()` prints the menus to the CI log |
| `Settings.swift` | Settings window (SwiftUI in an `NSWindow`) |
| `Model.swift` | `AppState` (ObservableObject): octave, instrument, pedal, metronome, recorder, playback, learn mode, `followOctave`, `bothHands`, library (user songs in `~/Library/Application Support/Touch Bar Piano/songs.json`); localisation `L(en, de)`; 32 instruments; `KeyLayout` geometry |
| `Audio.swift` | `AVAudioEngine` + 3 samplers (keys, drums, metronome) from macOS `gs_instruments.dls` |
| `TouchBar.swift` | `PianoView` (multitouch), `BarProvider`, `SystemModal` = private API for full-width system-wide bar, Esc hidden |
| `UI.swift` | SwiftUI window: header, live keyboard + falling notes + `Transport`, cards (incl. `PracticeCard`), `TracksSheet`, shortcut bar |
| `Songs.swift` | `Song`/`SongNote`/`SongPart` (roles melody/accompaniment/muted), `Parts.auto`/`Parts.apply` (track split + top voice), text song format, built-in song table, MIDI reader/writer, `selfTest()` |

Global singletons: `state` (AppState), `provider` (BarProvider).

## Tools (`tools/`)
| Tool | Purpose |
|---|---|
| `make_songs.py` | Builds `Songs/*.mid` (bundled into the app by `build.sh`) from verified sources in `Songs/SOURCES.md`: track 1 = melody (top voice, ornaments removed), track 2 = accompaniment. K. 265 is a manual transcription inside the script. Needs `pip install mido`. |
| `readme_assets.py` | Builds all `docs/` images (screenshots, `demo.gif`, `hero.png`) from the CI `snapshot` artifact; strips metadata. Needs Pillow, plus node + Playwright for `hero.png` (MacBook illustration in `tools/hero.html`). |

**Songs:** never write notes from memory – take them from a public-domain edition (Mutopia, IMSLP) and record
source + licence in `Songs/SOURCES.md` (`sonata-facile.mid` is CC BY-SA 3.0, all others public domain).
IMSLP shows a bot check to automated downloads – do not bypass it; ask the owner for a direct file link instead.
`icon.png` is a static asset (no generator).

## Conventions
- Keep it simple: plain `swiftc`, no packages, no Xcode project.
- Every shortcut must also be clickable in the UI and listed in the window's shortcut bar + README.
- UI strings always via `L("English", "Deutsch")`; German note names use H instead of B.
- Shortcuts: ←→ octave · ↑↓ tempo · 1–8 instrument · M metronome · Shift pedal · R record · Space play/pause ·
  S sheet mode · `,` `.` ±5 s · L A–B loop. Shortcuts are ignored while a sheet (e.g. Tracks) is open.
- Swift 5 language mode, deployment target macOS 11 – avoid APIs newer than Big Sur
  (e.g. no `Grid`, no `.onChange` with two parameters, no `NavigationSplitView`).
- SwiftUI is not captured by `cacheDisplay` → CI window screenshots use `screencapture -l<windowNumber>`;
  the CI screen is 1024×768, so snapshot mode renders the layout scaled (`snapshotScale`).
- README images in `docs/` come from `tools/readme_assets.py` (see Tools). Always label illustrations as such.
- `AppState` is created before `NSApplication` – code reachable from its init/`didSet` must not touch `NSApp`
  unguarded (a `@Published` property with `didSet` *does* fire when set in `init` after all properties are set).
- If the CI snapshot run produces no images, the workflow re-runs it under `lldb` and prints the backtrace.
- New menu items: add them in `Menu.swift` and, if they toggle something, a checkmark case in `validateMenuItem`.
- The keyboard on the Touch Bar may be narrower than requested in full-width mode – lay out and hit-test keys in
  `PianoView.area` (visible rect), never in `bounds`.

## Known limits / ideas
- Not verifiable in CI: touch input, audio, pedal, drum sounds (no Touch Bar, no audio device).
- Ideas not built yet: velocity, classic staff notation, notarised builds.
