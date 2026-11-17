# Touch Bar Piano

Turns the MacBook Pro Touch Bar into a 2-octave piano (C4–C6, multitouch).

**Install:** download `Piano.app` from the latest [Actions](../../actions) run, unzip, then:

```sh
xattr -dr com.apple.quarantine Piano.app
open Piano.app
```

Tip: System Settings → Keyboard → Touch Bar → "App Controls", Control Strip off — gives the piano the full width.

**Build locally:** `./build.sh` (needs Xcode Command Line Tools).
