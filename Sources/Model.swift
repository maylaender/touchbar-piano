import AppKit
import Combine

// MARK: - Localization (follows the macOS language: German or English)
let isGerman = Locale.preferredLanguages.first?.hasPrefix("de") ?? false
func L(_ en: String, _ de: String) -> String { isGerman ? de : en }
func fmt(_ t: Double) -> String { String(format: "%d:%02d", Int(t) / 60, Int(t) % 60) }

// MARK: - Instruments
enum InstrumentGroup: Int, CaseIterable {
    case classic, keys, orchestra, synth, drums
    var title: String {
        switch self {
        case .classic:   return L("Classic", "Klassisch")
        case .keys:      return L("Keys & Bells", "Tasten & Glocken")
        case .orchestra: return L("Strings & Winds", "Streicher & Bläser")
        case .synth:     return L("Synth & Fun", "Synth & Spass")
        case .drums:     return L("Drums", "Schlagzeug")
        }
    }
}

struct Instrument: Identifiable, Equatable {
    let id: Int, en: String, de: String, emoji: String, program: UInt8, group: InstrumentGroup
    var name: String { L(en, de) }
    var isDrums: Bool { group == .drums }
}

private let instrumentTable: [(String, String, String, UInt8, InstrumentGroup)] = [
    ("Piano", "Piano", "🎹", 0, .classic), ("E-Piano", "E-Piano", "⚡️", 4, .classic),
    ("Organ", "Orgel", "⛪️", 16, .classic), ("Guitar", "Gitarre", "🎸", 24, .classic),
    ("Strings", "Streicher", "🎻", 48, .classic), ("Synth", "Synth", "🎛️", 80, .classic),
    ("Vibraphone", "Vibraphon", "🔔", 11, .classic), ("Harp", "Harfe", "🧚", 46, .classic),
    ("Harpsichord", "Cembalo", "🏰", 6, .keys), ("Celesta", "Celesta", "✨", 8, .keys),
    ("Glockenspiel", "Glockenspiel", "🛎️", 9, .keys), ("Music Box", "Spieluhr", "🎁", 10, .keys),
    ("Marimba", "Marimba", "🪵", 12, .keys), ("Xylophone", "Xylophon", "🦴", 13, .keys),
    ("Accordion", "Akkordeon", "🪗", 21, .keys),
    ("Violin", "Violine", "🎻", 40, .orchestra), ("Cello", "Cello", "🎼", 42, .orchestra),
    ("Pizzicato", "Pizzicato", "🤏", 45, .orchestra), ("Choir", "Chor", "👼", 52, .orchestra),
    ("Trumpet", "Trompete", "🎺", 56, .orchestra), ("Saxophone", "Saxophon", "🎷", 65, .orchestra),
    ("Flute", "Flöte", "🌬️", 73, .orchestra), ("Pan Flute", "Panflöte", "🎋", 75, .orchestra),
    ("Synth Pad", "Synth-Pad", "☁️", 89, .synth), ("Synth Bass", "Synth-Bass", "🔊", 38, .synth),
    ("Steel Drums", "Steel Drums", "🏝️", 114, .synth), ("Ocarina", "Okarina", "🥚", 79, .synth),
    ("Harmonica", "Mundharmonika", "🤠", 22, .synth), ("Contrabass", "Kontrabass", "🐘", 43, .synth),
    ("Drum Kit", "Schlagzeug", "🥁", 0, .drums), ("Electronic Kit", "Elektro-Kit", "🤖", 24, .drums),
    ("Brush Kit", "Besen-Kit", "🧹", 40, .drums),
]
let instruments: [Instrument] = instrumentTable.enumerated().map { i, t in
    Instrument(id: i, en: t.0, de: t.1, emoji: t.2, program: t.3, group: t.4)
}

// MARK: - Keyboard geometry (shared by Touch Bar and window)
enum KeyLayout {
    static let whiteCount = 15                       // 2 octaves + top C
    static let steps = [0, 2, 4, 5, 7, 9, 11]
    static let blackWidth: CGFloat = 0.6, blackHeight: CGFloat = 0.58
    static var names: [String] { isGerman ? ["C", "D", "E", "F", "G", "A", "H"] : ["C", "D", "E", "F", "G", "A", "B"] }
    static let drumPads: [(name: String, note: Int)] = [
        ("Kick", 36), ("Snare", 38), ("Rim", 37), ("Clap", 39), ("Hat", 42), ("Pedal", 44), ("Open", 46),
        ("Tom 1", 45), ("Tom 2", 47), ("Tom 3", 50), ("Crash", 49), ("Ride", 51), ("Tamb", 54), ("Bell", 56), ("Splash", 55)]

    static func white(_ i: Int, base: Int) -> Int { base + 12 * (i / 7) + steps[i % 7] }
    static func hasBlack(after i: Int) -> Bool { [0, 1, 3, 4, 5].contains(i % 7) && i < whiteCount - 1 }

    /// x in 0...1 across the keyboard, yTop in 0...1 from the top edge.
    static func note(x: CGFloat, yTop: CGFloat, base: Int) -> Int {
        let kw = 1 / CGFloat(whiteCount)
        let i = min(max(Int(x / kw), 0), whiteCount - 1)
        if yTop < blackHeight {
            for j in [i - 1, i] where j >= 0 && hasBlack(after: j) && abs(x - kw * CGFloat(j + 1)) < kw * blackWidth / 2 {
                return white(j, base: base) + 1
            }
        }
        return white(i, base: base)
    }
    /// Horizontal position (unit coordinates) of a note, nil if outside the visible 2 octaves.
    static func span(of midi: Int, base: Int) -> (x: CGFloat, w: CGFloat, black: Bool)? {
        let kw = 1 / CGFloat(whiteCount)
        for i in 0..<whiteCount {
            if white(i, base: base) == midi { return (kw * CGFloat(i), kw, false) }
            if hasBlack(after: i) && white(i, base: base) + 1 == midi { return (kw * CGFloat(i + 1) - kw * blackWidth / 2, kw * blackWidth, true) }
        }
        return nil
    }
    static func drumPad(x: CGFloat) -> Int { drumPads[min(max(Int(x * CGFloat(drumPads.count)), 0), drumPads.count - 1)].note }
}

// MARK: - App state
final class AppState: ObservableObject {
    let synth = Synth()
    let snapshotMode = ProcessInfo.processInfo.environment["PIANO_SNAPSHOT"] != nil
    private let defaults = UserDefaults.standard

    @Published var octave: Int { didSet { defaults.set(octave, forKey: "octave") } }
    @Published var instrumentID: Int { didSet { synth.setInstrument(instrument); synth.pedal(pedal); defaults.set(instrumentID, forKey: "instrument") } }
    @Published var pedal = false { didSet { guard oldValue != pedal else { return }; synth.pedal(pedal); if !pedal { releaseSustained() } } }
    @Published var metronome = false { didSet { restartMetronome() } }
    @Published var bpm: Double { didSet { defaults.set(bpm, forKey: "bpm"); if oldValue != bpm { restartMetronome() } } }
    @Published var beat = -1
    @Published var pressed: Set<Int> = []        // sounding notes (display)
    @Published var hints: Set<Int> = []          // notes to play next (practice)
    @Published var isRecording = false
    @Published var recordTime: Double = 0
    @Published var library: [Song] = []
    @Published var selectedSongID: UUID?
    @Published var sheetMode = false
    @Published var waitForMe = true
    @Published var speed: Double = 1 {
        didSet { if playing != nil && !paused { playStart = Date().addingTimeInterval(-Date().timeIntervalSince(playStart) * oldValue / speed) } }
    }
    @Published var followOctave: Bool { didSet { defaults.set(followOctave, forKey: "followOctave") } }
    @Published var bothHands: Bool { didSet { defaults.set(bothHands, forKey: "bothHands") } }
    // settings
    @Published var fullWidthBar: Bool { didSet { defaults.set(fullWidthBar, forKey: "fullWidthBar"); onTouchBarModeChange() } }
    @Published var appearance: Int { didSet { defaults.set(appearance, forKey: "appearance"); applyAppearance() } }
    @Published var startInstrument: Int { didSet { defaults.set(startInstrument, forKey: "startInstrument") } }
    var onTouchBarModeChange: () -> Void = {}
    func applyAppearance() {
        NSApp.appearance = appearance == 1 ? NSAppearance(named: .aqua) : appearance == 2 ? NSAppearance(named: .darkAqua) : nil
    }
    @Published var learnLeft: Bool { didSet { defaults.set(learnLeft, forKey: "learnLeft") } }
    @Published var countIn: Bool { didSet { defaults.set(countIn, forKey: "countIn") } }
    @Published var accVolume: Double { didSet { defaults.set(accVolume, forKey: "accVolume") } }
    @Published var accLit: Set<Int> = []         // sounding accompaniment notes (purple)
    @Published var playing: PlayMode?
    @Published var paused = false
    @Published var countdown: Int?               // count-in beat shown in the UI
    @Published var loopA: Double?
    @Published var loopB: Double?
    @Published var editingTracks = false
    @Published var sheetTime: Double = 0
    enum PlayMode { case demo, practice }

    var instrument: Instrument { instruments[instrumentID] }
    var base: Int { 12 * (octave + 1) }          // lowest C (octave 4 -> MIDI 60)
    var selectedSong: Song? { library.first { $0.id == selectedSongID } }

    init() {
        octave = min(max(defaults.object(forKey: "octave") as? Int ?? 4, 1), 7)
        let id = defaults.object(forKey: "instrument") as? Int ?? 0
        instrumentID = instruments.indices.contains(id) ? id : 0
        bpm = defaults.object(forKey: "bpm") as? Double ?? 100
        followOctave = defaults.object(forKey: "followOctave") as? Bool ?? true
        bothHands = defaults.object(forKey: "bothHands") as? Bool ?? true
        learnLeft = defaults.object(forKey: "learnLeft") as? Bool ?? false
        fullWidthBar = defaults.object(forKey: "fullWidthBar") as? Bool ?? true
        appearance = defaults.object(forKey: "appearance") as? Int ?? 0
        startInstrument = defaults.object(forKey: "startInstrument") as? Int ?? -1
        countIn = defaults.object(forKey: "countIn") as? Bool ?? true
        accVolume = defaults.object(forKey: "accVolume") as? Double ?? 0.75
        if instruments.indices.contains(startInstrument) { instrumentID = startInstrument }
        if snapshotMode { octave = 4; instrumentID = 0; bpm = 100; followOctave = true; bothHands = true; learnLeft = false; countIn = true; accVolume = 0.75; fullWidthBar = true; appearance = 1 }
        synth.setInstrument(instrument)
        library = builtInSongs + loadUserSongs()
        selectedSongID = library.first?.id
    }

    // MARK: Notes (touch bar, mouse, playback)
    private var held: [Int: Int] = [:]
    func noteOn(_ n: Int, drum: Bool? = nil, user: Bool = true, acc: Bool = false) {
        guard (0...127).contains(n) else { return }
        let d = drum ?? instrument.isDrums
        synth.on(UInt8(n), drum: d, velocity: acc ? UInt8(min(127, 100 * accVolume * 1.27)) : 100)
        held[n, default: 0] += 1
        pressed.insert(n)
        if acc { accLit.insert(n) } else { accLit.remove(n) }
        if user { record(n, on: true, drum: d); checkLearn(n) }
    }
    func noteOff(_ n: Int, drum: Bool? = nil, user: Bool = true) {
        guard (0...127).contains(n) else { return }
        let d = drum ?? instrument.isDrums
        let c = (held[n] ?? 1) - 1
        held[n] = c > 0 ? c : nil
        if c <= 0 { synth.off(UInt8(n), drum: d); pressed.remove(n); accLit.remove(n) }
        if user { record(n, on: false, drum: d) }
    }
    private func allNotesOff() {
        for n in held.keys { synth.off(UInt8(n), drum: false); synth.off(UInt8(n), drum: true) }
        held = [:]; pressed = []; accLit = []
    }

    // MARK: Recorder (pedal extends note lengths)
    private var recStart = Date()
    private var recNotes: [SongNote] = []
    private var recOpen: [Int: (start: Double, drum: Bool)] = [:]
    private var recSustained: Set<Int> = []
    private func recNow() -> Double { Date().timeIntervalSince(recStart) }

    func toggleRecording() { isRecording ? stopRecording() : startRecording() }
    func startRecording() {
        stopPlayback()
        recNotes = []; recOpen = [:]; recSustained = []
        recStart = Date(); recordTime = 0; isRecording = true
        startTimer()
    }
    private func record(_ n: Int, on: Bool, drum: Bool) {
        guard isRecording else { return }
        if on { closeNote(n); recSustained.remove(n); recOpen[n] = (recNow(), drum) }
        else if pedal && !drum { recSustained.insert(n) }
        else { closeNote(n) }
    }
    private func closeNote(_ n: Int) {
        guard let o = recOpen.removeValue(forKey: n) else { return }
        recNotes.append(SongNote(start: o.start, dur: max(0.05, recNow() - o.start), midi: UInt8(n), drum: o.drum))
    }
    private func releaseSustained() {
        guard isRecording else { return }
        recSustained.forEach(closeNote); recSustained = []
    }
    func stopRecording() {
        guard isRecording else { return }
        Array(recOpen.keys).forEach(closeNote)
        isRecording = false
        guard !recNotes.isEmpty else { return }
        let t0 = recNotes.map(\.start).min() ?? 0
        let notes = recNotes.map { n -> SongNote in var n = n; n.start -= t0; return n }.sorted { $0.start < $1.start }
        let count = library.filter { $0.source == .recording }.count + 1
        let song = Song(title: L("Recording", "Aufnahme") + " \(count)", composer: L("Me", "Ich"), source: .recording, notes: notes)
        library.append(song); selectedSongID = song.id
        saveUserSongs()
    }

    // MARK: Songs: playback, practice (sheet mode), pause, seek, loop, count-in
    typealias Event = (t: Double, n: Int, on: Bool, drum: Bool, acc: Bool)
    private var timer: Timer?
    private var playStart = Date()
    private var events: [Event] = []
    private var eventIndex = 0
    private var groups: [[SongNote]] = []
    private var groupIndex = 0
    private var groupHit: Set<Int> = []
    private var startFrom = 0.0          // song time where playback (after the count-in) begins
    private var pausedAt = 0.0
    private var countRun = 0

    func select(_ song: Song) {
        stopPlayback()
        selectedSongID = song.id; sheetTime = 0; loopA = nil; loopB = nil
        fitOctave(song)
    }
    /// Space: start, pause, resume.
    func togglePlay() {
        if playing != nil { paused ? resume() : pause() }
        else { sheetMode ? practice() : playDemo() }
    }

    /// Notes the user is learning (right hand = melody, or left hand = accompaniment).
    private func isTarget(_ n: SongNote) -> Bool { learnLeft ? (n.isAccompaniment && !n.drum) : n.isMelody }
    private func makeEvents(_ s: Song, where keep: (SongNote) -> Bool) -> [Event] {
        s.notes.filter { $0.muted != true && keep($0) }
            .flatMap { n -> [Event] in [(n.start, Int(n.midi), true, n.drum, n.acc == true), (n.start + n.dur, Int(n.midi), false, n.drum, n.acc == true)] }
            .sorted { $0.t != $1.t ? $0.t < $1.t : (!$0.on && $1.on) }
    }
    /// Where to start: loop start, the position set with the progress bar, or the beginning.
    private func startPosition(_ s: Song) -> Double {
        if let a = loopA, loopB != nil { return a }
        return sheetTime > 0.05 && sheetTime < s.length - 0.5 ? sheetTime : 0
    }
    func playDemo() {
        guard let s = selectedSong else { return }
        let from = startPosition(s)
        stopPlayback(); if isRecording { stopRecording() }
        events = makeEvents(s) { self.bothHands || !$0.isAccompaniment }
        begin(.demo, at: from)
    }
    func practice() {
        guard let s = selectedSong else { return }
        let from = startPosition(s)
        stopPlayback(); if isRecording { stopRecording() }
        sheetMode = true
        groups = grouped(s)
        // the other hand plays along (only when not waiting)
        events = !waitForMe && bothHands ? makeEvents(s) { !self.isTarget($0) } : []
        begin(.practice, at: from)
    }
    private func begin(_ mode: PlayMode, at from: Double) {
        playing = mode; paused = false
        startFrom = from; sheetTime = from
        eventIndex = events.firstIndex { $0.t >= from } ?? events.count
        groupIndex = groups.firstIndex { $0[0].start >= from - 0.01 } ?? groups.count; groupHit = []
        if mode == .practice && waitForMe { followGroup() } else { follow(at: from) }
        let lead = countIn && !(mode == .practice && waitForMe) ? 4 * 60 / bpm : 0
        playStart = Date().addingTimeInterval(lead - from / speed)
        if lead > 0 { runCountIn() }
        updateHints(); startTimer()
    }
    private func runCountIn() {
        countRun += 1
        let run = countRun, step = 60 / bpm
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + step * Double(i)) { [weak self] in
                guard let s = self, s.countRun == run, s.playing != nil else { return }
                s.countdown = 4 - i
                s.synth.tick(i == 0)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + step * 4) { [weak self] in
            if self?.countRun == run { self?.countdown = nil }
        }
    }
    func pause() {
        guard playing != nil, !paused else { return }
        pausedAt = currentTime()
        paused = true; countRun += 1; countdown = nil
        silencePlayback()
    }
    func resume() {
        guard playing != nil, paused else { return }
        paused = false
        playStart = Date().addingTimeInterval(-pausedAt / speed)
    }
    func stopPlayback() {
        let hadSound = playing != nil && !events.isEmpty
        playing = nil; paused = false; hints = []; events = []
        countRun += 1; countdown = nil
        if hadSound { silencePlayback() }
    }
    private func silencePlayback() { allNotesOff() }
    private func currentTime() -> Double {
        paused ? pausedAt : max(startFrom, Date().timeIntervalSince(playStart) * speed)
    }

    /// Jump to a position (seconds). Without playback it sets where the next play starts.
    func seek(to target: Double) {
        guard let s = selectedSong else { return }
        let t = min(max(0, target), s.length)
        sheetTime = t
        guard let mode = playing else { follow(at: t); return }
        countRun += 1; countdown = nil
        silencePlayback()
        startFrom = 0
        eventIndex = events.firstIndex { $0.t >= t } ?? events.count
        if paused { pausedAt = t } else { playStart = Date().addingTimeInterval(-t / speed) }
        if mode == .practice && waitForMe {
            groupIndex = groups.firstIndex { $0[0].start >= t - 0.01 } ?? groups.count; groupHit = []
            followGroup()
        } else { follow(at: t) }
        updateHints()
    }
    func skip(_ seconds: Double) { seek(to: sheetTime + seconds) }

    /// L: set loop start, then loop end, then clear.
    func toggleLoop() {
        if loopA == nil { loopA = sheetTime }
        else if loopB == nil { if let a = loopA, sheetTime > a + 0.3 { loopB = sheetTime } else { loopA = sheetTime } }
        else { loopA = nil; loopB = nil }
    }

    // MARK: Octave (fit at start, optionally follow the notes being learned)
    /// Octave whose two-octave window shows lo...hi (keeps the low end if the span is wider).
    private func octaveFitting(_ lo: Int, _ hi: Int) -> Int {
        var o = lo / 12 - 1
        if hi > 12 * (o + 1) + 24 { o = min(Int((Double(hi - 24) / 12).rounded(.up)) - 1, o + 1) }
        return min(max(o, 1), 7)
    }
    private func inView(_ n: Int) -> Bool { n >= base && n <= base + 24 }
    func fitOctave(_ s: Song) {
        let first = s.notes.filter(isTarget).prefix(24).map { Int($0.midi) }
        guard let lo = first.min(), let hi = first.max() else { return }
        octave = octaveFitting(lo, hi)
    }
    /// Shift the octave when the upcoming notes leave the visible range.
    private func follow(at t: Double) {
        guard followOctave, let s = selectedSong else { return }
        let soon = s.notes.filter { isTarget($0) && $0.start >= t - 0.05 && $0.start <= t + 1.2 }.map { Int($0.midi) }
        guard let lo = soon.min(), let hi = soon.max(), !soon.allSatisfy(inView) else { return }
        let o = octaveFitting(lo, hi)
        if o != octave { octave = o }
    }
    private func followGroup() {
        guard groupIndex < groups.count else { return }
        let need = groups[groupIndex].map { Int($0.midi) }
        if followOctave, !need.allSatisfy(inView), let lo = need.min(), let hi = need.max() { octave = octaveFitting(lo, hi) }
    }
    private func grouped(_ s: Song) -> [[SongNote]] {
        var out: [[SongNote]] = []
        for n in s.notes.filter(isTarget).sorted(by: { $0.start < $1.start }) where followOctave || inView(Int(n.midi)) {
            if let first = out.last?.first, abs(first.start - n.start) < 0.03 { out[out.count - 1].append(n) } else { out.append([n]) }
        }
        return out
    }
    private func checkLearn(_ n: Int) {
        guard playing == .practice, waitForMe, !paused, groupIndex < groups.count else { return }
        let need = Set(groups[groupIndex].map { Int($0.midi) })
        guard need.contains(n) else { return }
        groupHit.insert(n)
        if groupHit.isSuperset(of: need) {
            groupIndex += 1; groupHit = []
            if let a = loopA, let b = loopB, groupIndex < groups.count, groups[groupIndex][0].start >= b {
                groupIndex = groups.firstIndex { $0[0].start >= a - 0.01 } ?? groupIndex
            }
            followGroup()
            if groupIndex >= groups.count { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.stopPlayback() } }
        }
        updateHints()
    }
    private func updateHints() {
        guard playing == .practice else { hints = []; return }
        if waitForMe {
            hints = groupIndex < groups.count ? Set(groups[groupIndex].map { Int($0.midi) }).subtracting(groupHit) : []
        } else {
            let t = sheetTime
            hints = Set(groups.joined().filter { $0.start <= t + 0.08 && $0.start + $0.dur > t }.map { Int($0.midi) })
        }
    }
    /// Snapshot helper: show a song frozen at time t (no sound).
    func preview(_ s: Song, at t: Double) {
        selectedSongID = s.id; sheetTime = t
        follow(at: t)
        let now = s.notes.filter { $0.muted != true && (bothHands || $0.isMelody) && $0.start <= t && $0.start + $0.dur > t }
        pressed = Set(now.map { Int($0.midi) })
        accLit = Set(now.filter(\.isAccompaniment).map { Int($0.midi) })
    }

    // MARK: Song tracks (melody / accompaniment / muted)
    private func updateSong(_ change: (inout Song) -> Void) {
        guard let i = library.firstIndex(where: { $0.id == selectedSongID }) else { return }
        stopPlayback()
        change(&library[i])
        library[i] = Parts.apply(library[i])
        if library[i].source != .builtIn { saveUserSongs() }
        fitOctave(library[i])
    }
    func setRole(_ role: PartRole, part: Int) { updateSong { s in if s.parts?.indices.contains(part) == true { s.parts![part].role = role } } }
    func setTopVoice(_ on: Bool) { updateSong { $0.topVoice = on } }
    func autoRoles() { updateSong { $0 = Parts.auto($0) } }

    private func startTimer() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    private func tick() {
        if isRecording { recordTime = recNow() }
        guard let mode = playing else {
            if !isRecording { timer?.invalidate(); timer = nil }
            return
        }
        if paused { return }
        let raw = Date().timeIntervalSince(playStart) * speed
        if raw < startFrom { sheetTime = startFrom; return }          // count-in
        let t = raw
        if let a = loopA, let b = loopB, t >= b, !(mode == .practice && waitForMe) { seek(to: a); return }
        if mode == .practice && waitForMe {
            let target = groupIndex < groups.count ? groups[groupIndex][0].start : sheetTime
            sheetTime += (target - sheetTime) * 0.18
            return
        }
        while eventIndex < events.count && events[eventIndex].t <= t {
            let e = events[eventIndex]
            if e.on { noteOn(e.n, drum: e.drum, user: false, acc: e.acc) } else { noteOff(e.n, drum: e.drum, user: false) }
            eventIndex += 1
        }
        sheetTime = t
        follow(at: t)
        updateHints()
        let end = selectedSong?.length ?? 0
        if mode == .demo ? eventIndex >= events.count : t > end + 1 { stopPlayback(); sheetTime = 0 }
    }

    // MARK: Metronome
    private var metroTimer: Timer?
    private var beatCount = 0
    private func restartMetronome() {
        metroTimer?.invalidate(); metroTimer = nil; beatCount = 0; beat = -1
        guard metronome else { return }
        let t = Timer(timeInterval: 60 / bpm, repeats: true) { [weak self] _ in
            guard let s = self else { return }
            s.beat = s.beatCount % 4
            s.synth.tick(s.beat == 0)
            s.beatCount += 1
        }
        RunLoop.main.add(t, forMode: .common)
        metroTimer = t
        t.fire()
    }

    // MARK: Library (recordings + imports are saved, built-ins are not)
    private var userSongsURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Touch Bar Piano", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("songs.json")
    }
    private func loadUserSongs() -> [Song] {
        guard !snapshotMode, let d = try? Data(contentsOf: userSongsURL) else { return [] }
        return (try? JSONDecoder().decode([Song].self, from: d)) ?? []
    }
    func saveUserSongs() {
        guard !snapshotMode, let d = try? JSONEncoder().encode(library.filter { $0.source != .builtIn }) else { return }
        try? d.write(to: userSongsURL)
    }
    func delete(_ s: Song) {
        if selectedSongID == s.id { stopPlayback() }
        library.removeAll { $0.id == s.id }
        if selectedSongID == s.id { selectedSongID = library.first?.id }
        saveUserSongs()
    }
    func importSongs() {
        let p = NSOpenPanel()
        p.allowedFileTypes = ["mid", "midi", "txt"]
        p.allowsMultipleSelection = true
        guard p.runModal() == .OK else { return }
        importFiles(p.urls)
    }
    /// Import MIDI or text songs (open panel, drag & drop, Finder "Open with", Dock icon).
    func importFiles(_ urls: [URL]) {
        for url in urls where ["mid", "midi", "txt"].contains(url.pathExtension.lowercased()) {
            guard let d = try? Data(contentsOf: url) else { continue }
            let name = url.deletingPathExtension().lastPathComponent
            let song = url.pathExtension.lowercased() == "txt"
                ? String(data: d, encoding: .utf8).flatMap { SongText.parse($0, source: .imported, fallbackTitle: name) }
                : MIDIFile.read(d, title: name)
            if let s = song { library.append(s); select(s) } else { NSSound.beep() }
        }
        saveUserSongs()
        if (selectedSong?.parts?.count ?? 0) > 1 { editingTracks = true }   // let the user check the track split
    }
    func exportMIDI() {
        guard let s = selectedSong else { return }
        let p = NSSavePanel()
        p.allowedFileTypes = ["mid"]
        p.nameFieldStringValue = s.title + ".mid"
        guard p.runModal() == .OK, let url = p.url else { return }
        try? MIDIFile.write(s, program: instrument.isDrums ? 0 : instrument.program).write(to: url)
    }
}
