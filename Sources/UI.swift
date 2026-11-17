import SwiftUI
import AppKit

// MARK: - Small building blocks
struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .underWindowBackground
        v.blendingMode = .behindWindow
        v.state = .followsWindowActiveState
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

func gradient(_ c: [Color]) -> LinearGradient { LinearGradient(gradient: Gradient(colors: c), startPoint: .top, endPoint: .bottom) }
let blueKey = [Color(red: 0.38, green: 0.68, blue: 1), Color(red: 0.04, green: 0.45, blue: 0.95)]
let orangeKey = [Color(red: 1, green: 0.76, blue: 0.35), Color(red: 1, green: 0.55, blue: 0.1)]

struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 2.5)
            .frame(minWidth: 20)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(Color.primary.opacity(0.18), lineWidth: 0.5))
    }
}

struct Pill: View {
    let text: String, color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(color)
            .lineLimit(1)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}

struct Card<Content: View>: View {
    let title: String, symbol: String, color: Color, keys: [String]
    let content: Content
    init(_ title: String, symbol: String, color: Color, keys: [String] = [], @ViewBuilder content: () -> Content) {
        self.title = title; self.symbol = symbol; self.color = color; self.keys = keys; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(gradient([color.opacity(0.75), color])))
                Text(title).font(.system(size: 13, weight: .semibold, design: .rounded)).lineLimit(1).layoutPriority(1)
                Spacer(minLength: 4)
                ForEach(keys, id: \.self) { KeyCap(text: $0) }
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(NSColor.controlBackgroundColor).opacity(0.8)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.07), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.07), radius: 6, x: 0, y: 2)
    }
}

struct IconButton: View {
    let symbol: String
    var color: Color = .blue
    let action: () -> Void
    @State var hover = false
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(gradient([color.opacity(0.8), color])))
                .shadow(color: color.opacity(0.35), radius: hover ? 5 : 2, x: 0, y: 1)
                .scaleEffect(hover ? 1.08 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
    }
}

struct ActionButton: View {
    let title: String, symbol: String, color: Color, action: () -> Void
    init(_ title: String, symbol: String, color: Color, action: @escaping () -> Void) {
        self.title = title; self.symbol = symbol; self.color = color; self.action = action
    }
    @State var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 10, weight: .bold))
                Text(title).font(.system(size: 12, weight: .semibold, design: .rounded)).lineLimit(1)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(gradient([color.opacity(hover ? 0.85 : 0.75), color])))
            .shadow(color: color.opacity(0.3), radius: hover ? 4 : 1, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { h in withAnimation(.easeOut(duration: 0.1)) { hover = h } }
    }
}

// MARK: - Header
struct Header: View {
    @ObservedObject var s: AppState
    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 6) {
                Text("Touch Bar Piano").font(.system(size: 24, weight: .bold, design: .rounded))
                HStack(spacing: 6) {
                    Pill(text: "C\(s.octave) – C\(s.octave + 2)", color: .blue)
                    Pill(text: s.instrument.emoji + " " + s.instrument.name, color: .purple)
                    if s.pedal { Pill(text: L("Pedal", "Pedal"), color: .green) }
                    if s.metronome { Pill(text: "♩ \(Int(s.bpm))", color: .pink) }
                    if s.isRecording { Pill(text: "● REC " + fmt(s.recordTime), color: .red) }
                    if s.playing != nil { Pill(text: "▶︎ " + (s.selectedSong?.title ?? ""), color: .orange) }
                }
            }
            Spacer()
        }
    }
}

// MARK: - Keyboard panel (mirrors the Touch Bar) + falling notes
struct KeyboardPanel: View {
    @ObservedObject var s: AppState
    var body: some View {
        VStack(spacing: 6) {
            if s.sheetMode { SheetLane(s: s).frame(height: 150) }
            MiniKeyboard(s: s).frame(height: 86)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(gradient([Color(white: 0.13), Color(white: 0.05)])))
        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
    }
}

struct MiniKeyboard: View {
    @ObservedObject var s: AppState
    @State var mouseNote: Int?

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                if s.instrument.isDrums { pads(w: g.size.width, h: g.size.height) } else { keys(w: g.size.width, h: g.size.height) }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let n = noteAt(v.location, g.size)
                    if n != mouseNote {
                        if let o = mouseNote { s.noteOff(o) }
                        if let n = n { s.noteOn(n) }
                        mouseNote = n
                    }
                }
                .onEnded { _ in if let o = mouseNote { s.noteOff(o) }; mouseNote = nil })
        }
    }
    private func noteAt(_ p: CGPoint, _ size: CGSize) -> Int? {
        guard p.x >= 0, p.y >= 0, p.x < size.width, p.y < size.height else { return nil }
        let x = p.x / size.width
        return s.instrument.isDrums ? KeyLayout.drumPad(x: x) : KeyLayout.note(x: x, yTop: p.y / size.height, base: s.base)
    }
    private func fill(_ n: Int, white: Bool) -> LinearGradient {
        if s.pressed.contains(n) { return gradient(blueKey) }
        if s.hints.contains(n) { return gradient(orangeKey) }
        return white ? gradient([Color.white, Color(white: 0.86)]) : gradient([Color(white: 0.3), Color.black])
    }
    private func keys(w: CGFloat, h: CGFloat) -> some View {
        let kw = w / CGFloat(KeyLayout.whiteCount)
        return ZStack(alignment: .topLeading) {
            ForEach(0..<KeyLayout.whiteCount, id: \.self) { i in
                let n = KeyLayout.white(i, base: s.base)
                let lit = s.pressed.contains(n) || s.hints.contains(n)
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(fill(n, white: true))
                    Text(i % 7 == 0 ? "C\(n / 12 - 1)" : KeyLayout.names[i % 7])
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(lit ? .white : Color(white: 0.55))
                        .padding(.bottom, 6)
                }
                .frame(width: kw - 3, height: h)
                .offset(x: kw * CGFloat(i) + 1.5)
            }
            ForEach(0..<KeyLayout.whiteCount, id: \.self) { i in
                if KeyLayout.hasBlack(after: i) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(fill(KeyLayout.white(i, base: s.base) + 1, white: false))
                        .frame(width: kw * KeyLayout.blackWidth, height: h * KeyLayout.blackHeight)
                        .offset(x: kw * CGFloat(i + 1) - kw * KeyLayout.blackWidth / 2)
                        .shadow(color: Color.black.opacity(0.4), radius: 1, x: 0, y: 1)
                }
            }
        }
    }
    private func pads(w: CGFloat, h: CGFloat) -> some View {
        let pads = KeyLayout.drumPads, pw = w / CGFloat(pads.count)
        return ZStack(alignment: .topLeading) {
            ForEach(0..<pads.count, id: \.self) { i in
                let on = s.pressed.contains(pads[i].note)
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(on ? gradient(blueKey) : gradient([Color(white: 0.3), Color(white: 0.18)]))
                    Text(pads[i].name).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.white)
                }
                .frame(width: pw - 4, height: h)
                .offset(x: pw * CGFloat(i) + 2)
            }
        }
    }
}

struct SheetLane: View {
    @ObservedObject var s: AppState
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height, pps = h / 2.5
            ZStack(alignment: .topLeading) {
                ForEach(0..<3, id: \.self) { o in
                    Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1, height: h)
                        .offset(x: w / CGFloat(KeyLayout.whiteCount) * CGFloat(o * 7))
                }
                if let song = s.selectedSong {
                    ForEach(Array(visible(song, ahead: 2.7).enumerated()), id: \.offset) { _, n in
                        if let sp = KeyLayout.span(of: Int(n.midi), base: s.base) {
                            let len = max(6, CGFloat(n.dur) * pps)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(gradient(sp.black ? [Color(red: 1, green: 0.5, blue: 0.15), Color(red: 0.9, green: 0.32, blue: 0)] : orangeKey))
                                .frame(width: max(4, sp.w * w - 4), height: len)
                                .offset(x: sp.x * w + 2, y: h - CGFloat(n.start - s.sheetTime) * pps - len)
                                .opacity(n.start + n.dur < s.sheetTime ? 0.25 : 1)
                        }
                    }
                } else {
                    Text(L("Choose a song", "Wähle ein Lied")).foregroundColor(Color.white.opacity(0.5)).frame(width: w, height: h)
                }
                Rectangle().fill(gradient([Color.orange.opacity(0), Color.orange.opacity(0.7)])).frame(width: w, height: 4).offset(y: h - 4)
            }
            .clipped()
        }
    }
    private func visible(_ song: Song, ahead: Double) -> [SongNote] {
        song.notes.filter { !$0.drum && $0.start < s.sheetTime + ahead && $0.start + $0.dur > s.sheetTime - 0.6 }
    }
}

// MARK: - Cards
struct OctaveCard: View {
    @ObservedObject var s: AppState
    var body: some View {
        Card(L("Octave", "Oktave"), symbol: "arrow.left.and.right", color: .blue, keys: ["←", "→"]) {
            HStack {
                IconButton(symbol: "minus", color: .blue) { if s.octave > 1 { s.octave -= 1 } }
                Spacer()
                VStack(spacing: 0) {
                    Text("C\(s.octave)").font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("C\(s.octave) – C\(s.octave + 2)").font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
                IconButton(symbol: "plus", color: .blue) { if s.octave < 7 { s.octave += 1 } }
            }
        }
    }
}

struct PedalCard: View {
    @ObservedObject var s: AppState
    var body: some View {
        Card(L("Pedal", "Pedal"), symbol: "shift.fill", color: .green, keys: ["⇧"]) {
            HStack(spacing: 10) {
                Toggle("", isOn: $s.pedal).toggleStyle(SwitchToggleStyle()).labelsHidden()
                VStack(alignment: .leading, spacing: 1) {
                    Text(s.pedal ? L("Sustain on", "Gehalten") : L("Off", "Aus"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(s.pedal ? .green : .primary)
                    Text(L("or hold Shift", "oder Shift halten")).font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
        }
    }
}

struct MetronomeCard: View {
    @ObservedObject var s: AppState
    var body: some View {
        Card(L("Metronome", "Metronom"), symbol: "metronome", color: .pink, keys: ["M", "↑↓"]) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Toggle("", isOn: $s.metronome).toggleStyle(SwitchToggleStyle()).labelsHidden()
                    Text("\(Int(s.bpm)) BPM").font(.system(size: 15, weight: .bold, design: .rounded)).fixedSize()
                    Spacer(minLength: 4)
                    HStack(spacing: 5) {
                        ForEach(0..<4, id: \.self) { i in
                            Circle()
                                .fill(s.metronome && s.beat == i ? Color.pink : Color.primary.opacity(0.12))
                                .frame(width: 8, height: 8)
                                .scaleEffect(s.metronome && s.beat == i ? 1.35 : 1)
                        }
                    }
                }
                Slider(value: $s.bpm, in: 40...240, step: 5)
            }
        }
    }
}

struct InstrumentCard: View {
    @ObservedObject var s: AppState
    @State var group: InstrumentGroup = .classic
    var body: some View {
        Card(L("Instrument", "Instrument"), symbol: "music.note", color: .purple, keys: ["1 – 8"]) {
            VStack(alignment: .leading, spacing: 10) {
                Picker("", selection: $group) {
                    ForEach(InstrumentGroup.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(SegmentedPickerStyle())
                .labelsHidden()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(instruments.filter { $0.group == group }) { inst in
                        Tile(inst: inst, selected: s.instrumentID == inst.id,
                             shortcut: inst.group == .classic ? "\(inst.id + 1)" : nil) { s.instrumentID = inst.id }
                    }
                }
            }
        }
        .onAppear { group = s.instrument.group }
        .onChange(of: s.instrumentID) { _ in group = s.instrument.group }
    }
}

struct Tile: View {
    let inst: Instrument, selected: Bool, shortcut: String?, action: () -> Void
    @State var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(inst.emoji).font(.system(size: 18))
                Text(inst.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(selected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                if let k = shortcut {
                    Text(k).font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(selected ? Color.white.opacity(0.8) : .secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(Group {
                if selected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(gradient([Color.purple.opacity(0.75), Color.purple]))
                        .shadow(color: Color.purple.opacity(0.35), radius: 4, x: 0, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(hover ? 0.09 : 0.045))
                }
            })
            .scaleEffect(hover ? 1.03 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
    }
}

struct RecordButton: View {
    let on: Bool, action: () -> Void
    @State var pulse = false
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(Color.red.opacity(on ? 0.6 : 0), lineWidth: 3)
                    .frame(width: 50, height: 50)
                    .scaleEffect(pulse ? 1.35 : 1).opacity(pulse ? 0 : 1)
                Circle().fill(gradient([Color(red: 1, green: 0.45, blue: 0.42), Color.red]))
                    .frame(width: 48, height: 48)
                    .shadow(color: Color.red.opacity(0.4), radius: 4, x: 0, y: 2)
                if on { RoundedRectangle(cornerRadius: 3).fill(Color.white).frame(width: 15, height: 15) }
                else { Circle().fill(Color.white).frame(width: 16, height: 16) }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear { withAnimation(Animation.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { pulse = true } }
    }
}

struct RecorderCard: View {
    @ObservedObject var s: AppState
    var body: some View {
        Card(L("Recorder", "Aufnahme"), symbol: "record.circle", color: .red, keys: ["R"]) {
            HStack(spacing: 14) {
                RecordButton(on: s.isRecording) { s.toggleRecording() }
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.isRecording ? L("Recording …", "Aufnahme läuft …") : L("Ready to record", "Bereit"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(fmt(s.isRecording ? s.recordTime : 0))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(s.isRecording ? .red : .secondary)
                }
                Spacer()
            }
            Text(L("Recordings appear under Songs → My recordings. Play them back with ▶︎ and watch the keys.",
                   "Aufnahmen erscheinen unter Lieder → Meine Aufnahmen. Mit ▶︎ abspielen und die Tasten mitverfolgen."))
                .font(.system(size: 11)).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SongRow: View {
    @ObservedObject var s: AppState
    let song: Song
    @State var hover = false
    var body: some View {
        let selected = s.selectedSongID == song.id
        return HStack(spacing: 8) {
            Text(song.source == .builtIn ? "🎼" : song.source == .recording ? "🎙️" : "📄")
            VStack(alignment: .leading, spacing: 0) {
                Text(song.title).font(.system(size: 12, weight: .semibold, design: .rounded)).lineLimit(1)
                Text(song.composer).font(.system(size: 10.5)).opacity(0.7)
            }
            Spacer()
            if hover && song.source != .builtIn {
                Button(action: { s.delete(song) }) { Image(systemName: "trash") }.buttonStyle(PlainButtonStyle())
            }
            Text(fmt(song.length)).font(.system(size: 10.5)).opacity(0.7)
        }
        .foregroundColor(selected ? .white : .primary)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(selected ? Color.orange : Color.primary.opacity(hover ? 0.06 : 0)))
        .contentShape(Rectangle())
        .onTapGesture { s.select(song) }
        .onHover { hover = $0 }
    }
}

struct SongsCard: View {
    @ObservedObject var s: AppState
    var body: some View {
        Card(L("Songs & Sheet", "Lieder & Noten"), symbol: "music.note.list", color: .orange, keys: ["Space", "S"]) {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(SongSource.allCases, id: \.self) { src in
                            let items = s.library.filter { $0.source == src }
                            if !items.isEmpty {
                                Text(src.title.uppercased())
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 6).padding(.leading, 8)
                                ForEach(items) { SongRow(s: s, song: $0) }
                            }
                        }
                    }
                }
                .frame(height: 150)
                HStack(spacing: 6) {
                    ActionButton(L("Play", "Abspielen"), symbol: "play.fill", color: .orange) { s.playDemo() }
                    ActionButton(L("Practice", "Üben"), symbol: "graduationcap.fill", color: .blue) { s.practice() }
                    ActionButton(L("Stop", "Stopp"), symbol: "stop.fill", color: .gray) { s.stopPlayback() }
                }
                Toggle(L("Sheet mode – falling notes", "Noten-Modus – fallende Noten"), isOn: $s.sheetMode)
                Toggle(L("Wait for me (learn mode)", "Auf mich warten (Lernmodus)"), isOn: $s.waitForMe)
                HStack(spacing: 8) {
                    Text(L("Speed", "Tempo")).foregroundColor(.secondary)
                    Slider(value: $s.speed, in: 0.5...1.5, step: 0.05)
                    Text("\(Int((s.speed * 100).rounded())) %").frame(width: 42, alignment: .trailing)
                }
                .font(.system(size: 12))
                HStack(spacing: 6) {
                    ActionButton(L("Import…", "Importieren …"), symbol: "square.and.arrow.down", color: Color(NSColor.systemTeal)) { s.importSongs() }
                    ActionButton(L("Export MIDI", "MIDI exportieren"), symbol: "square.and.arrow.up", color: Color(NSColor.systemIndigo)) { s.exportMIDI() }
                }
            }
        }
    }
}

struct ShortcutBar: View {
    let items: [(String, String)] = [
        ("← →", L("Octave", "Oktave")), ("↑ ↓", L("Tempo", "Tempo")), ("1 – 8", L("Instrument", "Instrument")),
        ("M", L("Metronome", "Metronom")), ("⇧ Shift", L("Pedal (hold)", "Pedal (halten)")), ("R", L("Record", "Aufnahme")),
        ("Space", L("Play / Stop", "Abspielen / Stopp")), ("S", L("Sheet mode", "Noten-Modus")),
    ]
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 4), alignment: .leading, spacing: 8) {
            ForEach(0..<items.count, id: \.self) { i in
                HStack(spacing: 6) {
                    KeyCap(text: items[i].0)
                    Text(items[i].1).font(.system(size: 11.5)).foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
    }
}

// MARK: - Window content (3 columns, fits a 13" MacBook)
struct ContentView: View {
    @ObservedObject var s: AppState
    var layout: some View {
        VStack(spacing: 14) {
            Header(s: s)
            KeyboardPanel(s: s)
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 14) {
                    OctaveCard(s: s)
                    PedalCard(s: s)
                    MetronomeCard(s: s)
                }
                .frame(width: 300)
                VStack(spacing: 14) {
                    InstrumentCard(s: s)
                    RecorderCard(s: s)
                }
                SongsCard(s: s).frame(width: 340)
            }
            .fixedSize(horizontal: false, vertical: true)
            ShortcutBar()
        }
        .padding(20)
    }
    var body: some View {
        if s.snapshotMode {   // CI screen is only 1024x768: render at design size, scaled down
            layout.frame(width: 1240, height: 860, alignment: .top)
                .scaleEffect(snapshotScale)
                .frame(width: 1240 * snapshotScale, height: 860 * snapshotScale)
                .background(Color(NSColor.windowBackgroundColor))
        } else {
            ZStack {
                VisualEffect().edgesIgnoringSafeArea(.all)
                ScrollView { layout }
            }
            .frame(minWidth: 1100, minHeight: 560)
        }
    }
}
let snapshotScale: CGFloat = 0.82
