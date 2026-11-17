import AppKit
import AVFoundation

// MARK: - Sound
final class Synth {
    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()

    init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        let dls = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
        try? sampler.loadSoundBankInstrument(at: dls, program: 0, // 0 = Acoustic Grand Piano
                                             bankMSB: 0x79, bankLSB: 0) // 0x79 = melodic bank
        try? engine.start()
    }
    func on(_ n: UInt8)  { sampler.startNote(n, withVelocity: 100, onChannel: 0) }
    func off(_ n: UInt8) { sampler.stopNote(n, onChannel: 0) }
}

// MARK: - Piano view (lives in the Touch Bar)
final class PianoView: NSView {
    let synth = Synth()
    let base: Int = 60            // C4
    let whiteCount = 15           // C4 ... C6
    let whiteSteps = [0, 2, 4, 5, 7, 9, 11]
    var active: [AnyHashable: UInt8] = [:]   // touch -> note

    override init(frame: NSRect) {
        super.init(frame: frame)
        allowedTouchTypes = [.direct]
        wantsRestingTouches = false
    }
    required init?(coder: NSCoder) { fatalError() }

    var keyW: CGFloat { bounds.width / CGFloat(whiteCount) }
    func whiteNote(_ i: Int) -> Int { base + 12 * (i / 7) + whiteSteps[i % 7] }
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
            if let o = old { synth.off(o) }
            if let n = new { synth.on(n) }
            active[id] = new
        }
        needsDisplay = true
    }
    override func touchesBegan(with e: NSEvent)    { handle(e, phase: .began) }
    override func touchesMoved(with e: NSEvent)    { handle(e, phase: .moved) }
    override func touchesEnded(with e: NSEvent)    { handle(e, phase: .ended) }
    override func touchesCancelled(with e: NSEvent) { handle(e, phase: .cancelled) }

    // MARK: Drawing
    override func draw(_ dirty: NSRect) {
        let pressed = Set(active.values)
        for i in 0..<whiteCount {
            let r = NSRect(x: keyW * CGFloat(i) + 1, y: 0, width: keyW - 2, height: bounds.height)
            (pressed.contains(UInt8(whiteNote(i))) ? NSColor.systemBlue : NSColor(white: 0.92, alpha: 1)).setFill()
            NSBezierPath(roundedRect: r, xRadius: 3, yRadius: 3).fill()
        }
        for i in 0..<whiteCount where hasBlack(after: i) {
            (pressed.contains(UInt8(whiteNote(i) + 1)) ? NSColor.systemBlue : NSColor.black).setFill()
            NSBezierPath(roundedRect: blackRect(after: i), xRadius: 2, yRadius: 2).fill()
        }
    }
}

// MARK: - Window content that provides the Touch Bar
final class HostView: NSView, NSTouchBarDelegate {
    static let pianoID = NSTouchBarItem.Identifier("piano")
    override var acceptsFirstResponder: Bool { true }

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
        item.view = piano
        return item
    }
}

// MARK: - App
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    func applicationDidFinishLaunching(_ n: Notification) {
        let host = HostView(frame: NSRect(x: 0, y: 0, width: 360, height: 80))
        let label = NSTextField(labelWithString: "🎹 Touch Bar Piano – keep this window focused.")
        label.frame = NSRect(x: 20, y: 30, width: 330, height: 20)
        host.addSubview(label)
        window = NSWindow(contentRect: host.frame, styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.title = "Touch Bar Piano"
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(host)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.isAutomaticCustomizeTouchBarMenuItemEnabled = false
app.run()
