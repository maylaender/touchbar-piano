# Changelog

## v3.4
- **Menu bar** with every function and its shortcut (App, File, Edit, Playback, Piano, Instrument, Window, Help) – ⌘Q, ⌘W, ⌘H, ⌘M, ⌘O, ⇧⌘E, ⌘T, ⌘., ⌘, now work
- **Settings window** (⌘,): Touch Bar mode (full width / standard with Esc), appearance (system/light/dark), instrument at launch, practice defaults
- **About window** with version, credits and link
- **Drag & drop** and **Open with**: MIDI and text songs onto the window, the Dock icon or from Finder
- **Dock menu**: play/pause, stop, record, sheet mode, metronome
- Window size and position are remembered; dark mode checked

## v3.3
- **Tracks dialog** for MIDI files: melody / accompaniment / muted per track (or per channel for single-track files), automatic suggestion, "top voice only" option
- **Transport**: pause/resume (Space), ±5 s (`,` `.`), progress bar to jump anywhere, **A–B loop** (`L`)
- **Practice**: learn the left hand, count-in (1 bar), accompaniment volume, hands in different colours
- Touch Bar keyboard uses exactly the visible width – rightmost key no longer cut off in full-width mode (from v3.2-beta)

## v3.2-beta
- Touch Bar keyboard uses exactly the visible width – rightmost key no longer cut off in full-width mode

## v3.1
- All 8 built-in songs are now complete pieces with both hands, taken from verified public-domain editions
  (Mutopia Project, Breitkopf & Härtel 1878) instead of being written from memory – fixes wrong notes in
  Eine kleine Nachtmusik, Rondo alla Turca, Sonata facile, Lullaby and Ah vous dirai-je, Maman
- New toggles: **Follow octave** (Touch Bar moves with the melody) and **Both hands** (melody + accompaniment)
- Play-along practice plays the left hand with you; accompaniment shown as grey falling notes
- MIDI import/export keeps melody and accompaniment apart (two tracks)

## v3
- Full-width, system-wide Touch Bar (private API, from v2.1-beta) with Esc hidden
- New SwiftUI window in macOS style: live keyboard, cards, switches, sliders – every shortcut also clickable
- 32 instruments in 5 groups (Classic, Keys & Bells, Strings & Winds, Synth & Fun, Drums)
- Drum mode: 15 labelled pads on the Touch Bar, 3 drum kits
- Recorder: record with pedal, play back with lit keys, saved between launches
- 8 built-in classics (Mozart, Beethoven, Bach, Brahms)
- Sheet mode with falling notes, learn mode (waits for the right key), speed control
- MIDI import/export, plain-text song format
- UI language follows macOS (German/English)
- Requires macOS 11 or later

## v2.1-beta
- Experimental full-width Touch Bar via private API, Esc hidden

## v2
- App icon, Shift = sustain pedal, octave switch, 8 instruments, note names, metronome

## v1
- Two-octave multitouch piano on the Touch Bar
