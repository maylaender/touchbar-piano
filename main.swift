import AppKit
import AVFoundation

// MARK: - Sound
let dls = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
let instruments: [(name: String, program: UInt8)] = [
    ("Piano", 0), ("E-Piano", 4), ("Orgel", 16), ("Gitarre", 24),
    ("Streicher", 48), ("Synth", 80), ("Vibraphon", 11), ("Harfe", 46)]

final class Synth {
    private let engine = AVAudioEngine()
    private let keys = AVAudioUnitSampler()
    private let drums = AVAudioUnitSampler()

    init() {
        for s in [keys, drums] { engine.attach(s); engine.connect(s, to: engine.mainMixerNode, format: nil) }
        setProgram(0)
        try? drums.loadSoundBankInstrument(at: dls, program: 0, bankMSB: 0x78, bankLSB: 0) // 0x78 = percussion bank
        try? engine.start()
    }
    func setProgram(_ p: UInt8) { try? keys.loadSoundBankInstrument(at: dls, program: p, bankMSB: 0x79, bankLSB: 0) } // 0x79 = melodic
    func on(_ n: UInt8)  { keys.startNote(n, withVelocity: 100, onChannel: 0) }
    func off(_ n: UInt8) { keys.stopNote(n, onChannel: 0) }
    func pedal(_ down: Bool) { keys.sendController(64, withValue: down ? 127 : 0, onChannel: 0) } // CC64 = sustain
    func click(_ accent: Bool) { drums.startNote(accent ? 76 : 77, withVelocity: accent ? 127 : 90, onChannel: 0) } // wood blocks
}

// MARK: - State (octave, instrument, pedal, metronome)
final class State {
    let synth = Synth()
    var onChange: [() -> Void] = []
    var octave = 4 { didSet { changed() } }
    var instrument = 0 { didSet { synth.setProgram(instruments[instrument].program); synth.pedal(pedal); changed() } }
    var pedal = false { didSet { synth.pedal(pedal); changed() } }
    var metronome = false { didSet { restartMetronome(); changed() } }
    var bpm = 100 { didSet { restartMetronome(); changed() } }
    var base: Int { 12 * (octave + 1) }          // MIDI note of lowest C (octave 4 -> 60)

    private var timer: Timer?
    private var beat = 0
    private func changed() { onChange.forEach { $0() } }
    private func restartMetronome() {
        timer?.invalidate(); timer = nil; beat = 0
        guard metronome else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 60 / Double(bpm), repeats: true) { [weak self] _ in
            guard let s = self else { return }
            s.synth.click(s.beat % 4 == 0); s.beat += 1
        }
        timer?.fire()
    }
}
let state = State()

// MARK: - Piano view (lives in the Touch Bar)
final class PianoView: NSView {
    let whiteCount = 15                       // 2 octaves + top C
    let whiteSteps = [0, 2, 4, 5, 7, 9, 11]
    let names = ["C", "D", "E", "F", "G", "A", "H"]
    var active: [AnyHashable: UInt8] = [:]    // touch -> note

    override init(frame: NSRect) {
        super.init(frame: frame)
        allowedTouchTypes = [.direct]
        wantsRestingTouches = false
    }
    required init?(coder: NSCoder) { fatalError() }

    var keyW: CGFloat { bounds.width / CGFloat(whiteCount) }
    func whiteNote(_ i: Int) -> Int { state.base + 12 * (i / 7) + whiteSteps[i % 7] }
    func hasBlack(after i: Int) -> Bool { [0, 1, 3, 4, 5].contains(i % 7) && i < whiteCount - 1 }
    func blackRect(after i: Int) -> NSRect {
        let w = keyW * 0.6
        return NSRect(x: keyW * CGFloat(i + 1) - w / 2, y: bounds.height * 0.45, width: w, height: bounds.height * 0.55)
    }

    func note(at p: NSPoint) -> UInt8? {
        guard bounds.contains(p) else { return nil }
        let i = min(Int(p.x / keyW), whiteCount - 1)
        for j in [i - 1, i] where j >= 0 && hasBlack(after: j) && blackRect(after: j).contains(p) {
            return UInt8(whiteNote(j) + 1)
        }
        return UInt8(whiteNote(i))
    }

    // MARK: Touch handling (multitouch, sliding changes the note)
    func handle(_ event: NSEvent, phase: NSTouch.Phase) {
        for t in event.touches(matching: phase, in: self) {
            let id = AnyHashable(t.identity as! NSObject)
            let old = active[id]
            let new: UInt8? = (phase == .ended || phase == .cancelled) ? nil : note(at: t.location(in: self))
            if old == new { continue }
            if let o = old { state.synth.off(o) }
            if let n = new { state.synth.on(n) }
            active[id] = new
        }
        needsDisplay = true
    }
    override func touchesBegan(with e: NSEvent)     { handle(e, phase: .began) }
    override func touchesMoved(with e: NSEvent)     { handle(e, phase: .moved) }
    override func touchesEnded(with e: NSEvent)     { handle(e, phase: .ended) }
    override func touchesCancelled(with e: NSEvent) { handle(e, phase: .cancelled) }

    // MARK: Drawing
    override func draw(_ dirty: NSRect) {
        let pressed = Set(active.values)
        let font = NSFont.systemFont(ofSize: 8, weight: .semibold)
        for i in 0..<whiteCount {
            let n = whiteNote(i), on = pressed.contains(UInt8(n))
            let r = NSRect(x: keyW * CGFloat(i) + 1, y: 0, width: keyW - 2, height: bounds.height)
            (on ? NSColor.systemBlue : NSColor(white: 0.92, alpha: 1)).setFill()
            NSBezierPath(roundedRect: r, xRadius: 3, yRadius: 3).fill()
            let label = i % 7 == 0 ? "C\(n / 12 - 1)" : names[i % 7]
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: on ? NSColor.white : NSColor.gray]
            let size = label.size(withAttributes: attrs)
            label.draw(at: NSPoint(x: r.midX - size.width / 2, y: 2), withAttributes: attrs)
        }
        for i in 0..<whiteCount where hasBlack(after: i) {
            (pressed.contains(UInt8(whiteNote(i) + 1)) ? NSColor.systemBlue : NSColor.black).setFill()
            NSBezierPath(roundedRect: blackRect(after: i), xRadius: 2, yRadius: 2).fill()
        }
    }
}

// MARK: - Window content: status, help, keyboard shortcuts, Touch Bar provider
final class HostView: NSView, NSTouchBarDelegate {
    static let pianoID = NSTouchBarItem.Identifier("piano")
    let status = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        let title = NSTextField(labelWithString: "🎹 Touch Bar Piano")
        title.font = .systemFont(ofSize: 20, weight: .bold)
        title.frame = NSRect(x: 20, y: frame.height - 46, width: 380, height: 28)
        status.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        status.frame = NSRect(x: 20, y: 128, width: 380, height: 80)
        let help = NSTextField(labelWithString: """
            ← →     Oktave wechseln
            ↑ ↓     Tempo Metronom
            1 – 8   Instrument
            M       Metronom an/aus
            Shift   Pedal (halten)
            """)
        help.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        help.textColor = .secondaryLabelColor
        help.frame = NSRect(x: 20, y: 16, width: 380, height: 92)
        [title, status, help].forEach(addSubview)
        state.onChange.append { [weak self] in self?.update() }
        update()
    }
    required init?(coder: NSCoder) { fatalError() }

    func update() {
        let o = state.octave
        status.stringValue = """
            Oktave      C\(o) – C\(o + 2)
            Instrument  \(state.instrument + 1) · \(instruments[state.instrument].name)
            Pedal       \(state.pedal ? "● gedrückt" : "○ los")
            Metronom    \(state.metronome ? "an" : "aus") · \(state.bpm) BPM
            """
    }

    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with e: NSEvent) {
        switch e.keyCode {
        case 123: state.octave = max(1, state.octave - 1)   // ←
        case 124: state.octave = min(7, state.octave + 1)   // →
        case 125: state.bpm = max(40, state.bpm - 5)        // ↓
        case 126: state.bpm = min(240, state.bpm + 5)       // ↑
        default:
            let c = e.charactersIgnoringModifiers?.lowercased() ?? ""
            if let d = Int(c), (1...instruments.count).contains(d) { state.instrument = d - 1 }
            else if c == "m" && !e.isARepeat { state.metronome.toggle() }
            else { super.keyDown(with: e) }
        }
    }
    override func flagsChanged(with e: NSEvent) {
        let down = e.modifierFlags.contains(.shift)
        if down != state.pedal { state.pedal = down }
    }

    override func makeTouchBar() -> NSTouchBar? {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [Self.pianoID]
        bar.principalItemIdentifier = Self.pianoID
        return bar
    }
    func touchBar(_ bar: NSTouchBar, makeItemForIdentifier id: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        let item = NSCustomTouchBarItem(identifier: id)
        let piano = PianoView(frame: .zero)
        let w = piano.widthAnchor.constraint(equalToConstant: 1085)
        w.priority = .defaultHigh   // shrink to available width
        w.isActive = true
        state.onChange.append { [weak piano] in piano?.needsDisplay = true }
        item.view = piano
        return item
    }
}

// MARK: - App
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    func applicationDidFinishLaunching(_ n: Notification) {
        let host = HostView(frame: NSRect(x: 0, y: 0, width: 420, height: 260))
        window = NSWindow(contentRect: host.frame, styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.title = "Touch Bar Piano"
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(host)
        NSApp.activate(ignoringOtherApps: true)
        if let dir = ProcessInfo.processInfo.environment["PIANO_SNAPSHOT"] { snapshot(to: dir) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }

    // CI only: renders the real views to PNG (C major chord, pedal down), then quits.
    func snapshot(to dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        func save(_ v: NSView, _ name: String) {
            let s = v.bounds.size
            guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(s.width * 2), pixelsHigh: Int(s.height * 2),
                                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
            rep.size = s
            v.cacheDisplay(in: v.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: dir + "/" + name))
        }
        state.pedal = true
        let piano = PianoView(frame: NSRect(x: 0, y: 0, width: 1004, height: 30))
        piano.active = [1: 60, 2: 64, 3: 67]
        save(piano, "touchbar.png")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let frame = self.window.contentView?.superview { save(frame, "window.png") }
            NSApp.terminate(nil)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.isAutomaticCustomizeTouchBarMenuItemEnabled = false
app.run()
