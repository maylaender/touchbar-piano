#!/usr/bin/env python3
"""Builds the built-in songs in Songs/*.mid from verified public sources.

Every output file is a type-1 MIDI (480 ticks/quarter, fixed 120 BPM, so 960 ticks = 1 s):
  track 1 = melody (right hand, one note at a time – used for sheet/learn mode)
  track 2 = accompaniment (left hand, inner voices, ornaments)

Usage:  pip install mido && python3 tools/make_songs.py
Sources and licences: Songs/SOURCES.md
"""
import io, os, sys, urllib.request
import mido

OUT = os.path.join(os.path.dirname(__file__), "..", "Songs")
MUTOPIA = "https://www.mutopiaproject.org/ftp/"
ORNAMENT = 0.09          # melody notes shorter than this (s) are ornaments -> accompaniment

# file, Mutopia path, melody track, accompaniment tracks
PIECES = [
    ("nachtmusik", "MozartWA/KV525/eine-kleine-nachtmusik-mvt1/eine-kleine-nachtmusik-mvt1.mid", 1, [2, 3, 4]),
    ("rondo-alla-turca", "MozartWA/KV331/KV331_3_RondoAllaTurca/KV331_3_RondoAllaTurca.mid", 1, [2]),
    ("sonata-facile", "MozartWA/KV545/K545-1/K545-1.mid", 1, [2]),
    ("fur-elise", "BeethovenLv/WoO59/fur_Elise_WoO59/fur_Elise_WoO59.mid", 1, [2]),
    ("ode-to-joy", "BeethovenLv/ode/ode.mid", 1, [2]),
    ("minuet-in-g", "BachJS/BWVAnh114/anna-magdalena-04/anna-magdalena-04.mid", 1, [2]),
    ("wiegenlied", "BrahmsJ/O49/Wiegenlied/Wiegenlied-mids.zip", 1, [4, 5]),
]

def load(path):
    data = urllib.request.urlopen(MUTOPIA + path, timeout=60).read()
    if path.endswith(".zip"):
        import zipfile
        z = zipfile.ZipFile(io.BytesIO(data))
        data = z.read(next(n for n in z.namelist() if n.endswith("Wiegenlied.mid")))
    return mido.MidiFile(file=io.BytesIO(data))

def notes_in_seconds(mid, track):
    """[(start_s, dur_s, pitch)] for one track, using the file's tempo map."""
    tempos = sorted((tick, msg.tempo) for tr in mid.tracks for tick, msg in absolute(tr) if msg.type == "set_tempo") or [(0, 500000)]
    def sec(tick):
        s, last_tick, tempo = 0.0, 0, 500000
        for t, tp in tempos:
            if t > tick: break
            s += (t - last_tick) * tempo / 1e6 / mid.ticks_per_beat; last_tick, tempo = t, tp
        return s + (tick - last_tick) * tempo / 1e6 / mid.ticks_per_beat
    out, open_ = [], {}
    for tick, msg in absolute(mid.tracks[track]):
        if msg.type == "note_on" and msg.velocity > 0:
            open_.setdefault(msg.note, []).append(tick)
        elif msg.type in ("note_off", "note_on") and open_.get(msg.note):
            t0 = open_[msg.note].pop(0)
            out.append((sec(t0), sec(tick) - sec(t0), msg.note))
    return sorted(out)

def absolute(track):
    t = 0
    for msg in track:
        t += msg.time
        yield t, msg

def split_melody(notes):
    """Top voice = melody: highest note per onset, unless a higher melody note is still sounding
    (then an inner voice moved). Ornaments and all other notes = accompaniment."""
    by_onset = {}
    for n in notes: by_onset.setdefault(round(n[0], 4), []).append(n)
    mel, acc, cur = [], [], None
    for onset, group in sorted(by_onset.items()):
        top = max(group, key=lambda n: n[2])
        held = cur is not None and cur[0] + cur[1] > onset + 0.03 and cur[2] > top[2]
        for n in group:
            if n is top and not held and n[1] >= ORNAMENT:
                mel.append(n); cur = n
            else:
                acc.append(n)
    return mel, acc

def write(name, mel, acc):
    mid = mido.MidiFile(type=1, ticks_per_beat=480)
    for i, part in enumerate([mel, acc]):
        tr = mido.MidiTrack(); mid.tracks.append(tr)
        tr.append(mido.MetaMessage("track_name", name=["melody", "accompaniment"][i], time=0))
        if i == 0: tr.append(mido.MetaMessage("set_tempo", tempo=500000, time=0))
        ev = []
        for s, d, p in part:
            ev.append((round(s * 960), 1, p)); ev.append((round((s + d) * 960), 0, p))
        last = 0
        for t, on, p in sorted(ev):
            tr.append(mido.Message("note_on" if on else "note_off", note=p, velocity=90 if on else 0, time=t - last)); last = t
    mid.save(os.path.join(OUT, name + ".mid"))
    print(f"{name:18} melody {len(mel):4}  accompaniment {len(acc):4}  {max(s + d for s, d, _ in mel + acc) / 60:4.1f} min")

# ---------------------------------------------------------------------------------------------
# Mozart K. 265 – Theme and Variation 1, transcribed from Mozarts Werke, Serie XXI No. 6
# (Breitkopf & Härtel 1878, public domain; IMSLP #24784). Units: 16th notes, 2/4 time.
# "+" = chord, "R" = rest. Ties are written as one longer note. Grace notes omitted.
K265_TEMPO = 104   # quarter notes per minute
THEME_RH = {
    "A": "C5:4 C5:4 | G5:4 G5:4 | A5:4 A5:4 | G5:4 G5:4 | F5:4 F5:4 | E5:4 E5:4 | D5:4 D5:3 E5:1 | C5:8",
    "B": "G5:4 G5:4 | F5:4 F5:4 | E5:4 E5:4 | D5:4 D5:4 | G5:4 G5:4 | F5:4 F5:4 | E5:4 E5:3 F5:1 | E5:4 D5:4",
}
THEME_LH = {
    "A": "C3:4 C4:4 | E4:4 C4:4 | F4:4 C4:4 | E4:4 C4:4 | D4:4 B3:4 | C4:4 A3:4 | F3:4 G3:4 | C3:8",
    "B": "E4:4 G3:4 | D4:4 G3:4 | C4:4 G3:4 | B3:4 G3:4 | E4:4 G3:4 | D4:4 G3:4 | C4:4 C4:3 D4:1 | C4+G3:4 B3:4",
}
VAR1_RH = {
    "A1": "D5 C5 B4 C5 B4 C5 B4 C5 | A5 G5 F#5 G5 F#5 G5 F#5 G5 | G#5 A5 C6 B5 D6 C6 B5 A5 | A5 G5 E6 D6 C6 B5 A5 G5:2"
          " F5 D6 C6 B5 A5 G5 F5:2 E5 C6 B5 A5 G5 F5 E5 | D5:2 A5:2 G5:2 B4:2",
    "end1": "C5:4 R:4", "end2": "C5:4 R:4",
    "B": "A5 G5 F#5 G5 F#5 G5 A5 G5 | G5 F5 E5 F5 E5 F5 G5 F5 | F5 E5 D#5 E5 D#5 E5 F5 E5 | E5 D5 C#5 D5 C#5 D5 E5 D5"
         " | A5 G5 F#5 G5 E6 C6 A5 G5 | G5 F5 E5 F5 D6 B5 G5 F5 | F5 E5 D#5 E5 C6 G5 F5 E5 | G5:3 E5:1 D5:4",
}
VAR1_LH = {
    "A1": "C3:4 C4:4 | E4:4 C4:4 | F4:4 C4:4 | E4:4 R:3 C#4:1 | D4:4 R:3 B3:1 | C4:4 R:3 A3:1 | F3:4 G3:4",
    "end1": "C4:2 G3:2 E3:2 G3:2", "end2": "C4:4 C3:4",
    "B": "E4:4 G3:4 | D4:4 G3:4 | C4:4 G3:4 | F4:4 G3:4 | E4+G3:8 | D4+G3:8 | C4+G3:4 R:3 C4:1 | E4:3 C4:1 B3:4",
}
VAR1_LH_HALF = {"B_bass": "R:8 | R:8 | R:8 | R:8 | R:8 | R:8 | R:8 | G3:8"}   # sustained G under bar 16

PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

def parse(text, t0, unit):
    notes, t = [], t0
    for tok in text.replace("|", " ").split():
        name, _, d = tok.partition(":")
        dur = (int(d) if d else 1) * unit
        if name != "R":
            for n in name.split("+"):
                notes.append((t, dur * 0.95, 12 * (int(n[-1]) + 1) + PC[n[0]] + (1 if "#" in n else 0)))
        t += dur
    return notes, t

def k265():
    unit = 60 / K265_TEMPO / 4
    mel, acc, t = [], [], 0.0
    def sec(rh, lh, extra=None):
        nonlocal t
        m, t1 = parse(rh, t, unit); a, t2 = parse(lh, t, unit)
        if extra: acc.extend(parse(extra, t, unit)[0])
        assert abs(t1 - t2) < 1e-6, (rh[:20], t1, t2)
        mel.extend(m); acc.extend(a); t = t1
    for part in ["A", "A", "B", "A", "B", "A"]:                       # theme with repeats
        sec(THEME_RH[part], THEME_LH[part])
    t += 2 * 4 * unit                                                # short breath between theme and variation
    for end in ["end1", "end2"]:                                     # Var. 1 first half with 1st/2nd ending
        sec(VAR1_RH["A1"], VAR1_LH["A1"]); sec(VAR1_RH[end], VAR1_LH[end])
    for _ in range(2):                                               # second half (bars 9-24) twice
        sec(VAR1_RH["B"], VAR1_LH["B"], VAR1_LH_HALF["B_bass"])
        sec(VAR1_RH["A1"], VAR1_LH["A1"]); sec(VAR1_RH["end2"], VAR1_LH["end2"])
    # chords in the melody track: keep top note in melody
    return split_melody(mel)[0], acc + split_melody(mel)[1]

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, path, mel_track, acc_tracks in PIECES:
        mid = load(path)
        mel, acc = split_melody(notes_in_seconds(mid, mel_track))
        for tr in acc_tracks: acc += notes_in_seconds(mid, tr)
        write(name, mel, acc)
    write("ah-vous-dirai-je", *k265())
