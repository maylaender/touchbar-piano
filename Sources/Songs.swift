import Foundation

struct SongNote: Codable, Equatable {
    var start: Double            // seconds
    var dur: Double              // seconds
    var midi: UInt8
    var drum: Bool = false
    var acc: Bool? = nil         // true = accompaniment (left hand / inner voices)
    var isMelody: Bool { acc != true && !drum }
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

// MARK: - Built-in songs (complete pieces from verified public-domain sources, see Songs/SOURCES.md)
let builtInTable: [(file: String, title: String, composer: String)] = [
    ("nachtmusik", "Eine kleine Nachtmusik (1st mvt.)", "Mozart"),
    ("rondo-alla-turca", "Rondo alla Turca", "Mozart"),
    ("sonata-facile", "Sonata facile K. 545 (1st mvt.)", "Mozart"),
    ("ah-vous-dirai-je", "Ah vous dirai-je, Maman (Theme & Var. 1)", "Mozart"),
    ("fur-elise", "Für Elise", "Beethoven"),
    ("ode-to-joy", "Ode to Joy", "Beethoven"),
    ("minuet-in-g", "Minuet in G", "Bach / Petzold"),
    ("wiegenlied", "Lullaby (Wiegenlied)", "Brahms"),
]
let builtInSongs: [Song] = builtInTable.compactMap { t in
    guard let url = Bundle.main.url(forResource: t.file, withExtension: "mid", subdirectory: "Songs"),
          let data = try? Data(contentsOf: url),
          var song = MIDIFile.read(data, title: t.title) else { return nil }
    song.composer = t.composer
    song.source = .builtIn
    return song
}

// MARK: - Standard MIDI files (minimal reader/writer)
enum MIDIFile {
    /// Type-1 file: track 1 = melody, track 2 = accompaniment. 480 ticks/quarter at 120 BPM (1 s = 960 ticks).
    static func write(_ song: Song, program: UInt8) -> Data {
        func ticks(_ s: Double) -> Int { Int((s * 960).rounded()) }
        func track(_ notes: [SongNote], header: [UInt8]) -> [UInt8] {
            var ev: [(t: Int, bytes: [UInt8])] = []
            for n in notes {
                let ch: UInt8 = n.drum ? 9 : 0
                ev.append((ticks(n.start), [0x90 | ch, n.midi, 100]))
                ev.append((ticks(n.start + n.dur), [0x80 | ch, n.midi, 0]))
            }
            ev.sort { $0.t != $1.t ? $0.t < $1.t : ($0.bytes[0] & 0xF0) < ($1.bytes[0] & 0xF0) } // note-offs first
            var trk = header, last = 0
            for e in ev { trk += vlq(e.t - last) + e.bytes; last = e.t }
            trk += vlq(0) + [0xFF, 0x2F, 0x00]
            return Array("MTrk".utf8) + be(trk.count, 4) + trk
        }
        let mel = song.notes.filter { $0.acc != true }, acc = song.notes.filter { $0.acc == true }
        let tracks = [track(mel, header: vlq(0) + [0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20] + vlq(0) + [0xC0, program])]
            + (acc.isEmpty ? [] : [track(acc, header: vlq(0) + [0xC0, program])])
        let d: [UInt8] = Array("MThd".utf8) + be(6, 4) + [0, 1] + be(tracks.count, 2) + be(480, 2) + tracks.joined()
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
        var raw: [(tick: Int, ch: Int, note: Int, on: Bool, trk: Int)] = []
        for trk in 0..<ntrks where p + 8 <= b.count {
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
                    if kind == 0x90 || kind == 0x80 { raw.append((tick, s & 0x0F, n, kind == 0x90 && v > 0, trk)) }
                }
            }
            p = end
        }
        let secPerTick = tempo / 1_000_000 / Double(div)
        let noteTracks = Array(Set(raw.map(\.trk))).sorted()
        let melodyTrack = noteTracks.count > 1 ? noteTracks.first : nil
        var open: [Int: [(t: Double, trk: Int)]] = [:]
        var notes: [SongNote] = []
        for e in raw.sorted(by: { ($0.tick, $0.on ? 1 : 0) < ($1.tick, $1.on ? 1 : 0) }) {
            let key = e.ch * 128 + e.note, t = Double(e.tick) * secPerTick
            if e.on { open[key, default: []].append((t, e.trk)) }
            else if var starts = open[key], !starts.isEmpty {
                let s = starts.removeFirst(); open[key] = starts
                let acc: Bool? = melodyTrack != nil && s.trk != melodyTrack ? true : nil
                notes.append(SongNote(start: s.t, dur: max(0.05, t - s.t), midi: UInt8(e.note), drum: e.ch == 9, acc: acc))
            }
        }
        notes.sort { $0.start < $1.start }
        return notes.isEmpty ? nil : Song(title: title, composer: "MIDI", source: .imported, notes: notes)
    }
}

/// CI self test: built-in songs load, MIDI round-trips (incl. melody/accompaniment split).
func selfTest() -> Bool {
    var ok = builtInSongs.count == builtInTable.count
    for s in builtInSongs {
        let mel = s.notes.filter(\.isMelody).count, acc = s.notes.count - mel
        print(String(format: "song: %@ – %d melody, %d accompaniment, %@", s.title, mel, acc, fmt(s.length)))
        if mel < 40 || acc < 40 { print("FAIL too few notes", s.title); ok = false }
        guard let back = MIDIFile.read(MIDIFile.write(s, program: 0), title: s.title) else { print("FAIL read", s.title); ok = false; continue }
        let order: (SongNote, SongNote) -> Bool = { ($0.midi, $0.start) < ($1.midi, $1.start) }
        let a = s.notes.sorted(by: order), b = back.notes.sorted(by: order)
        let same = a.count == b.count && zip(a, b).allSatisfy { $0.midi == $1.midi && abs($0.start - $1.start) < 0.002 && $0.isMelody == $1.isMelody }
        if !same { print("FAIL roundtrip", s.title, a.count, b.count); ok = false }
    }
    if SongText.midi("C4") != 60 || SongText.midi("A4") != 69 || SongText.midi("Bb3") != 58 || SongText.midi("H4") != 71 { print("FAIL note names"); ok = false }
    print(ok ? "SELFTEST OK" : "SELFTEST FAILED")
    return ok
}
