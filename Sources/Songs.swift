import Foundation

struct SongNote: Codable, Equatable {
    var start: Double            // seconds
    var dur: Double              // seconds
    var midi: UInt8
    var drum: Bool = false
}
enum SongSource: String, Codable, CaseIterable {
    case builtIn, recording, imported
    var title: String {
        switch self {
        case .builtIn:   return L("Classics", "Klassiker")
        case .recording: return L("My recordings", "Meine Aufnahmen")
        case .imported:  return L("Imported", "Importiert")
        }
    }
}
struct Song: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var composer: String
    var source: SongSource
    var notes: [SongNote]
    var length: Double { notes.map { $0.start + $0.dur }.max() ?? 0 }
}

/// Plain-text song format:
///   # title: Ode to Joy        # composer: Beethoven       # bpm: 120
///   E4 E4 F4 G4 | D4:1.5 C4:0.5 | C4+E4+G4:2 | R:1
/// NOTE[:beats] (default 1 beat), chords with +, R = rest, | is ignored. B and H both mean B.
enum SongText {
    static func midi(_ name: Substring) -> UInt8? {
        var s = Array(name)
        guard let f = s.first?.uppercased(),
              var pc = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11, "H": 11][f] else { return nil }
        s.removeFirst()
        if s.first == "#" { pc += 1; s.removeFirst() } else if s.first == "b" && s.count > 1 { pc -= 1; s.removeFirst() }
        guard let oct = Int(String(s)) else { return nil }
        let v = 12 * (oct + 1) + pc
        return (0...127).contains(v) ? UInt8(v) : nil
    }
    static func parse(_ text: String, source: SongSource = .builtIn, fallbackTitle: String? = nil) -> Song? {
        var title = fallbackTitle ?? L("Untitled", "Ohne Titel"), composer = "", bpm = 120.0, beat = 0.0
        var notes: [SongNote] = []
        for line in text.split(separator: "\n") {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("#") {
                let kv = l.dropFirst().split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if kv.count == 2 {
                    switch kv[0].lowercased() {
                    case "title": title = kv[1]
                    case "composer": composer = kv[1]
                    case "bpm": bpm = Double(kv[1]) ?? bpm
                    default: break
                    }
                }
                continue
            }
            for tok in l.split(whereSeparator: { $0 == " " || $0 == "|" || $0 == "\t" }) {
                let parts = tok.split(separator: ":")
                let len = parts.count > 1 ? (Double(parts[1]) ?? 1) : 1
                if parts[0].uppercased() != "R" {
                    for n in parts[0].split(separator: "+") {
                        if let m = midi(n) { notes.append(SongNote(start: beat * 60 / bpm, dur: len * 60 / bpm * 0.92, midi: m)) }
                    }
                }
                beat += len
            }
        }
        return notes.isEmpty ? nil : Song(title: title, composer: composer, source: source, notes: notes)
    }
}

// MARK: - Built-in songs (public domain, simplified right-hand melodies)
let builtInSongs: [Song] = [
"""
# title: Eine kleine Nachtmusik
# composer: Mozart
# bpm: 260
G5:2 R D5 G5:2 R D5 | G5 D5 G5 B5 D6:2 R:2 | C6:2 R A5 C6:2 R A5 | C6 A5 F#5 A5 D5:2 R:2
G5:2 R D5 G5:2 R D5 | G5 D5 G5 B5 D6:2 R:2 | C6:2 R A5 C6:2 R A5 | C6 A5 F#5 A5 G5:4
""",
"""
# title: Rondo alla Turca
# composer: Mozart
# bpm: 480
B4 A4 G#4 A4 C5:4 | D5 C5 B4 C5 E5:4 | F5 E5 D#5 E5 B5 A5 G#5 A5 B5 A5 G#5 A5 C6:8
A5:2 C6:2 B5:2 A5:2 G#5:2 A5:2 E5:2 F5:2 | D5:2 C5:4 B4:4 A4:8
""",
"""
# title: Sonata facile K. 545
# composer: Mozart
# bpm: 110
C5:2 E5 G5 | B4:1.5 C5:0.25 D5:0.25 C5:2 | A5:2 G5 C6 | G5 F5:0.5 E5:0.5 F5 E5
A4:0.25 B4:0.25 C5:0.25 D5:0.25 E5:0.25 F5:0.25 G5:0.25 A5:0.25 G5:0.25 F5:0.25 E5:0.25 D5:0.25 C5:0.25 B4:0.25 A4:0.25 G4:0.25 | C5:2
""",
"""
# title: Ah vous dirai-je, Maman
# composer: Mozart
# bpm: 100
C4 C4 G4 G4 | A4 A4 G4:2 | F4 F4 E4 E4 | D4 D4 C4:2
G4 G4 F4 F4 | E4 E4 D4:2 | G4 G4 F4 F4 | E4 E4 D4:2
C4 C4 G4 G4 | A4 A4 G4:2 | F4 F4 E4 E4 | D4 D4 C4:2
""",
"""
# title: Für Elise
# composer: Beethoven
# bpm: 150
E5 D#5 | E5 D#5 E5 B4 D5 C5 | A4:2 R C4 E4 A4 | B4:2 R E4 G#4 B4 | C5:2 R E4 E5 D#5
E5 D#5 E5 B4 D5 C5 | A4:2 R C4 E4 A4 | B4:2 R E4 C5 B4 | A4:4
""",
"""
# title: Ode to Joy
# composer: Beethoven
# bpm: 120
E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | E4:1.5 D4:0.5 D4:2
E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | D4:1.5 C4:0.5 C4:2
D4 D4 E4 C4 | D4 E4:0.5 F4:0.5 E4 C4 | D4 E4:0.5 F4:0.5 E4 D4 | C4 D4 G3:2
E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | D4:1.5 C4:0.5 C4:2
""",
"""
# title: Minuet in G
# composer: Bach / Petzold
# bpm: 120
D5 G4:0.5 A4:0.5 B4:0.5 C5:0.5 | D5 G4 G4 | E5 C5:0.5 D5:0.5 E5:0.5 F#5:0.5 | G5 G4 G4
C5 D5:0.5 C5:0.5 B4:0.5 A4:0.5 | B4 C5:0.5 B4:0.5 A4:0.5 G4:0.5 | F#4 G4:0.5 A4:0.5 B4:0.5 G4:0.5 | A4:3
D5 G4:0.5 A4:0.5 B4:0.5 C5:0.5 | D5 G4 G4 | E5 C5:0.5 D5:0.5 E5:0.5 F#5:0.5 | G5 G4 G4
C5 D5:0.5 C5:0.5 B4:0.5 A4:0.5 | B4 C5:0.5 B4:0.5 A4:0.5 G4:0.5 | A4 B4:0.5 A4:0.5 G4:0.5 F#4:0.5 | G4:3
""",
"""
# title: Lullaby (Wiegenlied)
# composer: Brahms
# bpm: 100
E4:0.5 E4:0.5 | G4:2 E4:0.5 E4:0.5 | G4:2 E4:0.5 G4:0.5 | C5 B4:1.5 A4:0.5 | A4 G4 D4:0.5 E4:0.5
F4 D4 D4:0.5 E4:0.5 | F4:2 D4:0.5 F4:0.5 | B4:0.5 A4:0.5 G4 B4 | C5:2 C4:0.5 C4:0.5
C5:2 A4:0.5 F4:0.5 | G4:2 E4:0.5 C4:0.5 | F4 G4 A4 | G4:2 C4:0.5 C4:0.5
C5:2 A4:0.5 F4:0.5 | G4:2 E4:0.5 C4:0.5 | F4 E4 D4 | C4:3
""",
].compactMap { SongText.parse($0) }

// MARK: - Standard MIDI files (minimal reader/writer)
enum MIDIFile {
    /// Type-0 file, 480 ticks per quarter at 120 BPM (1 s = 960 ticks). Drums go to channel 10.
    static func write(_ song: Song, program: UInt8) -> Data {
        func ticks(_ s: Double) -> Int { Int((s * 960).rounded()) }
        var ev: [(t: Int, bytes: [UInt8])] = []
        for n in song.notes {
            let ch: UInt8 = n.drum ? 9 : 0
            ev.append((ticks(n.start), [0x90 | ch, n.midi, 100]))
            ev.append((ticks(n.start + n.dur), [0x80 | ch, n.midi, 0]))
        }
        ev.sort { $0.t != $1.t ? $0.t < $1.t : ($0.bytes[0] & 0xF0) < ($1.bytes[0] & 0xF0) } // note-offs first
        var trk: [UInt8] = vlq(0) + [0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20]          // tempo 500000 us
        trk += vlq(0) + [0xC0, program]
        var last = 0
        for e in ev { trk += vlq(e.t - last) + e.bytes; last = e.t }
        trk += vlq(0) + [0xFF, 0x2F, 0x00]
        var d: [UInt8] = Array("MThd".utf8) + be(6, 4) + [0, 0, 0, 1] + be(480, 2)
        d += Array("MTrk".utf8) + be(trk.count, 4) + trk
        return Data(d)
    }
    static func vlq(_ value: Int) -> [UInt8] {
        var v = max(0, value), out = [UInt8(v & 0x7F)]
        v >>= 7
        while v > 0 { out.insert(UInt8(v & 0x7F) | 0x80, at: 0); v >>= 7 }
        return out
    }
    static func be(_ v: Int, _ n: Int) -> [UInt8] { (0..<n).reversed().map { UInt8((v >> ($0 * 8)) & 0xFF) } }

    /// Reads note on/off from all tracks (first tempo only). Returns nil if no notes.
    static func read(_ data: Data, title: String) -> Song? {
        let b = [UInt8](data)
        var p = 0
        func byte() -> Int { defer { p += 1 }; return p < b.count ? Int(b[p]) : 0 }
        func num(_ n: Int) -> Int { (0..<n).reduce(0) { r, _ in (r << 8) | byte() } }
        func vl() -> Int { var v = 0; for _ in 0..<4 { let c = byte(); v = (v << 7) | (c & 0x7F); if c & 0x80 == 0 { break } }; return v }
        func tag() -> String { let s = String(bytes: b[min(p, b.count)..<min(p + 4, b.count)], encoding: .ascii) ?? ""; p += 4; return s }

        guard b.count > 14, tag() == "MThd" else { return nil }
        let hlen = num(4); _ = num(2); let ntrks = num(2); let div = num(2)
        p = 8 + hlen
        guard div > 0, div & 0x8000 == 0 else { return nil }
        var tempo = 500_000.0, tempoSet = false
        var raw: [(tick: Int, ch: Int, note: Int, on: Bool)] = []
        for _ in 0..<ntrks where p + 8 <= b.count {
            let id = tag(), len = num(4), end = min(p + len, b.count)
            guard id == "MTrk" else { p = end; continue }
            var tick = 0, status = 0
            while p < end {
                tick += vl()
                guard p < end else { break }
                var s = Int(b[p])
                if s & 0x80 != 0 { p += 1; if s < 0xF0 { status = s } } else { s = status }
                if s == 0xFF {
                    let type = byte(), l = vl()
                    if type == 0x51, l == 3, !tempoSet, p + 3 <= end { tempo = Double(num(3)); tempoSet = true; p -= 3 }
                    p += l
                } else if s == 0xF0 || s == 0xF7 {
                    p += vl()
                } else {
                    let kind = s & 0xF0
                    if kind == 0xC0 || kind == 0xD0 { p += 1; continue }
                    let n = byte(), v = byte()
                    if kind == 0x90 || kind == 0x80 { raw.append((tick, s & 0x0F, n, kind == 0x90 && v > 0)) }
                }
            }
            p = end
        }
        let secPerTick = tempo / 1_000_000 / Double(div)
        var open: [Int: [Double]] = [:]
        var notes: [SongNote] = []
        for e in raw.sorted(by: { ($0.tick, $0.on ? 1 : 0) < ($1.tick, $1.on ? 1 : 0) }) {
            let key = e.ch * 128 + e.note, t = Double(e.tick) * secPerTick
            if e.on { open[key, default: []].append(t) }
            else if var starts = open[key], !starts.isEmpty {
                let s = starts.removeFirst(); open[key] = starts
                notes.append(SongNote(start: s, dur: max(0.05, t - s), midi: UInt8(e.note), drum: e.ch == 9))
            }
        }
        notes.sort { $0.start < $1.start }
        return notes.isEmpty ? nil : Song(title: title, composer: "MIDI", source: .imported, notes: notes)
    }
}

/// CI self test: songs parse, MIDI round-trips.
func selfTest() -> Bool {
    var ok = builtInSongs.count == 8
    print("songs:", builtInSongs.map { "\($0.title) (\($0.notes.count))" }.joined(separator: ", "))
    for s in builtInSongs {
        guard let back = MIDIFile.read(MIDIFile.write(s, program: 0), title: s.title) else { print("FAIL read", s.title); ok = false; continue }
        let same = back.notes.count == s.notes.count && zip(back.notes, s.notes).allSatisfy { $0.midi == $1.midi && abs($0.start - $1.start) < 0.01 }
        if !same { print("FAIL roundtrip", s.title, back.notes.count, s.notes.count); ok = false }
    }
    if SongText.midi("C4") != 60 || SongText.midi("A4") != 69 || SongText.midi("Bb3") != 58 || SongText.midi("H4") != 71 { print("FAIL note names"); ok = false }
    print(ok ? "SELFTEST OK" : "SELFTEST FAILED")
    return ok
}
