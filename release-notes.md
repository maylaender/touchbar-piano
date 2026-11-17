⚠️ **Beta / experimentell** – für die stabile Version siehe v2.

**Neu in v2.1-beta:**
- Touch Bar über **private macOS-API** (wie Pock/MTMR): Klavier auf voller Breite, Control Strip ausgeblendet
- **Esc-Knopf ausgeblendet** (Versuch – ob der Platz frei wird, hängt von macOS ab)
- Klavier bleibt sichtbar, auch wenn eine andere App im Vordergrund ist (Tastenkürzel wie Shift-Pedal nur bei aktivem Fenster)
- Fenster schliessen oder ⌘Q gibt die Touch Bar wieder frei

Falls die private API fehlt, verhält sich die App wie v2.

**Installation:** `Piano.app.zip` herunterladen, entpacken, dann:

```sh
xattr -dr com.apple.quarantine Piano.app
open Piano.app
```
