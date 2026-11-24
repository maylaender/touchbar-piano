import Foundation

struct SongNote: Codable, Equatable {
    var start: Double            // seconds
    var dur: Double              // seconds
    var midi: UInt8
    var drum: Bool = false
    var acc: Bool? = nil         // true = accompaniment (left hand / inner voices)
    var part: Int? = nil         // index into Song.parts (MIDI track or channel)
    var muted: Bool? = nil       // part muted by the user
    var isMelody: Bool { acc != true && !drum && muted != true }
    var isAccompaniment: Bool { acc == true && muted != true }
}

/// What a MIDI track/channel is used for.
enum PartRole: String, Codable, CaseIterable, Hashable {
    case melody, accompaniment, muted
    var title: String {
        switch self {
        case .melody:        return L("Melody", "Melodie")
        case .accompaniment: return L("Accompaniment", "Begleitung")
        case .muted:         return L("Muted", "Stumm")
        }
    }
}
struct SongPart: Codable, Equatable {
    var name: String
    var program: Int?
    var drums: Bool
    var role: PartRole
    var instrumentName: String {
        if drums { return L("Drums", "Schlagzeug") }
        guard let p = program else { return "–" }
        let families = isGerman
            ? ["Klavier", "Glocken", "Orgel", "Gitarre", "Bass", "Streicher", "Ensemble", "Blech", "Holz", "Flöte", "Synth Lead", "Synth Pad", "Synth FX", "Ethno", "Perkussion", "Effekte"]
            : ["Piano", "Bells", "Organ", "Guitar", "Bass", "Strings", "Ensemble", "Brass", "Reed", "Pipe", "Synth Lead", "Synth Pad", "Synth FX", "Ethnic", "Percussive", "Effects"]
        return families[min(max(p, 0), 127) / 8]
    }
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
    var parts: [SongPart]? = nil   // nil = single part (recordings, text songs)
    var topVoice: Bool? = nil      // melody = top voice only (default true)
    var length: Double { notes.map { $0.start + $0.dur }.max() ?? 0 }
}

/// Splitting a song into melody / accompaniment / muted parts.
enum Parts {
    /// Suggest roles: a part named "melody", else the highest-sounding part with enough notes.
    static func auto(_ s: Song) -> Song {
        guard var parts = s.parts, !parts.isEmpty else { return s }
        var song = s
        if parts.count == 1 {
            parts[0].role = parts[0].drums ? .accompaniment : .melody
        } else {
            var counts = [Int](repeating: 0, count: parts.count), sums = [Int](repeating: 0, count: parts.count)
            for n in s.notes { if let p = n.part, p < parts.count { counts[p] += 1; sums[p] += Int(n.midi) } }
            let named = parts.firstIndex { $0.name.lowercased() == "melody" }
            let minCount = max(8, (counts.max() ?? 0) / 5)
            let best = named ?? parts.indices
                .filter { !parts[$0].drums && counts[$0] >= minCount }
                .max { Double(sums[$0]) / Double(counts[$0]) < Double(sums[$1]) / Double(counts[$1]) }
            for i in parts.indices { parts[i].role = i == best ? .melody : .accompaniment }
        }
        song.parts = parts
        return apply(song)
    }
    /// Sets acc/muted flags from the roles; optionally keeps only the top voice of the melody.
    static func apply(_ s: Song) -> Song {
        guard let parts = s.parts else { return s }
        var song = s
        for i in song.notes.indices {
            let role = song.notes[i].part.flatMap { parts.indices.contains($0) ? parts[$0].role : nil } ?? .melody
            song.notes[i].muted = role == .muted ? true : nil
            song.notes[i].acc = role == .accompaniment ? true : nil
        }
        guard song.topVoice ?? true else { return song }
        // top voice: highest note per onset, unless a higher melody note still sounds; ornaments (< 90 ms) excluded
        let idx = song.notes.indices.filter { song.notes[$0].isMelody }.sorted { song.notes[$0].start < song.notes[$1].start }
        var cur: SongNote?, i = 0
        while i < idx.count {
            var j = i
            while j < idx.count && song.notes[idx[j]].start - song.notes[idx[i]].start < 0.0005 { j += 1 }
            let group = idx[i..<j]
            let top = group.max { song.notes[$0].midi < song.notes[$1].midi }!
            let t = song.notes[top]
            let held = cur.map { $0.start + $0.dur > t.start + 0.03 && $0.midi > t.midi } ?? false
            for k in group {
                if k == top && !held && t.dur >= 0.09 { cur = t } else { song.notes[k].acc = true }
            }
            i = j
        }
        return song
    }
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
        let mel = song.notes.filter { $0.acc != true && $0.muted != true }, acc = song.notes.filter(\.isAccompaniment)
        func name(_ s: String) -> [UInt8] { vlq(0) + [0xFF, 0x03, UInt8(s.utf8.count)] + Array(s.utf8) }
        let tracks = [track(mel, header: name("melody") + vlq(0) + [0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20] + vlq(0) + [0xC0, program])]
            + (acc.isEmpty ? [] : [track(acc, header: name("accompaniment") + vlq(0) + [0xC0, program])])
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
        var trackNames: [Int: String] = [:], programs: [Int: Int] = [:]
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
                    if type == 0x03, trackNames[trk] == nil, p + l <= end {
                        trackNames[trk] = String(bytes: b[p..<p + l], encoding: .isoLatin1)?.trimmingCharacters(in: .whitespaces)
                    }
                    p += l
                } else if s == 0xF0 || s == 0xF7 {
                    p += vl()
                } else {
                    let kind = s & 0xF0
                    if kind == 0xC0 { let prog = byte(); if programs[s & 0x0F] == nil { programs[s & 0x0F] = prog }; continue }
                    if kind == 0xD0 { p += 1; continue }
                    let n = byte(), v = byte()
                    if kind == 0x90 || kind == 0x80 { raw.append((tick, s & 0x0F, n, kind == 0x90 && v > 0, trk)) }
                }
            }
            p = end
        }
        let secPerTick = tempo / 1_000_000 / Double(div)
        let noteTracks = Array(Set(raw.map(\.trk))).sorted()
        let byTrack = noteTracks.count > 1                                  // else split a single track by channel
        let keys = byTrack ? noteTracks : Array(Set(raw.map(\.ch))).sorted()
        let parts: [SongPart] = keys.enumerated().map { i, k in
            let ch = byTrack ? (raw.first { $0.trk == k }?.ch ?? 0) : k
            let named = byTrack ? (trackNames[k] ?? "") : ""
            return SongPart(name: named.isEmpty ? (byTrack ? L("Track", "Spur") + " \(i + 1)" : L("Channel", "Kanal") + " \(ch + 1)") : named,
                            program: ch == 9 ? nil : programs[ch], drums: ch == 9, role: .accompaniment)
        }
        var open: [Int: [(t: Double, part: Int)]] = [:]
        var notes: [SongNote] = []
        for e in raw.sorted(by: { ($0.tick, $0.on ? 1 : 0) < ($1.tick, $1.on ? 1 : 0) }) {
            let key = e.ch * 128 + e.note, t = Double(e.tick) * secPerTick
            if e.on { open[key, default: []].append((t, keys.firstIndex(of: byTrack ? e.trk : e.ch) ?? 0)) }
            else if var starts = open[key], !starts.isEmpty {
                let s = starts.removeFirst(); open[key] = starts
                notes.append(SongNote(start: s.t, dur: max(0.05, t - s.t), midi: UInt8(e.note), drum: e.ch == 9, part: s.part))
            }
        }
        notes.sort { $0.start < $1.start }
        return notes.isEmpty ? nil : Parts.auto(Song(title: title, composer: "MIDI", source: .imported, notes: notes, parts: parts))
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
    // type-0 file, channel 1 = high melody, channel 2 = low bass, plus a program change
    var trk: [UInt8] = MIDIFile.vlq(0) + [0xC1, 32]
    for (i, n) in [72, 74, 76, 77, 79, 81, 83, 84, 86, 88].enumerated() {
        trk += MIDIFile.vlq(i == 0 ? 0 : 0) + [0x90, UInt8(n), 90] + MIDIFile.vlq(0) + [0x91, UInt8(n - 36), 90]
        trk += MIDIFile.vlq(480) + [0x80, UInt8(n), 0] + MIDIFile.vlq(0) + [0x81, UInt8(n - 36), 0]
    }
    trk += MIDIFile.vlq(0) + [0xFF, 0x2F, 0x00]
    let type0 = Data(Array("MThd".utf8) + MIDIFile.be(6, 4) + [0, 0, 0, 1] + MIDIFile.be(480, 2) + Array("MTrk".utf8) + MIDIFile.be(trk.count, 4) + trk)
    if let t0 = MIDIFile.read(type0, title: "t0"), let parts = t0.parts, parts.count == 2,
       parts[0].role == .melody, parts[1].role == .accompaniment, parts[1].program == 32,
       t0.notes.filter(\.isMelody).count == 10 {
        print("channel split OK:", parts.map { "\($0.name) \($0.role.rawValue) \($0.instrumentName)" })
    } else { print("FAIL channel split"); ok = false }
    if SongText.midi("C4") != 60 || SongText.midi("A4") != 69 || SongText.midi("Bb3") != 58 || SongText.midi("H4") != 71 { print("FAIL note names"); ok = false }
    print(ok ? "SELFTEST OK" : "SELFTEST FAILED")
    return ok
}
