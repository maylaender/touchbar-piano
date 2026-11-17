import AppKit
import Combine

// MARK: - Piano view (lives in the Touch Bar)
final class PianoView: NSView {
    private var active: [AnyHashable: Int] = [:]   // touch -> note
    private var sub: AnyCancellable?

    override init(frame: NSRect) {
        super.init(frame: frame)
        allowedTouchTypes = [.direct]
        wantsRestingTouches = false
        sub = state.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.needsDisplay = true } }
    }
    required init?(coder: NSCoder) { fatalError() }

    private func note(at p: NSPoint) -> Int? {
        guard bounds.contains(p), bounds.width > 0 else { return nil }
        let x = p.x / bounds.width
        return state.instrument.isDrums ? KeyLayout.drumPad(x: x) : KeyLayout.note(x: x, yTop: 1 - p.y / bounds.height, base: state.base)
    }

    // Multitouch; sliding changes the note
    private func handle(_ event: NSEvent, phase: NSTouch.Phase) {
        for t in event.touches(matching: phase, in: self) {
            let id = AnyHashable(t.identity as! NSObject)
            let old = active[id]
            let new = (phase == .ended || phase == .cancelled) ? nil : note(at: t.location(in: self))
            if old == new { continue }
            if let o = old { state.noteOff(o) }
            if let n = new { state.noteOn(n) }
            active[id] = new
        }
    }
    override func touchesBegan(with e: NSEvent)     { handle(e, phase: .began) }
    override func touchesMoved(with e: NSEvent)     { handle(e, phase: .moved) }
    override func touchesEnded(with e: NSEvent)     { handle(e, phase: .ended) }
    override func touchesCancelled(with e: NSEvent) { handle(e, phase: .cancelled) }

    override func draw(_ dirty: NSRect) {
        let lit = state.pressed, hints = state.hints
        let font = NSFont.systemFont(ofSize: 8, weight: .semibold)
        func label(_ s: String, in r: NSRect, white: Bool, y: CGFloat = 2) {
            let a: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: white ? NSColor.white : NSColor.gray]
            let size = s.size(withAttributes: a)
            s.draw(at: NSPoint(x: r.midX - size.width / 2, y: y), withAttributes: a)
        }
        func color(_ n: Int, white: Bool) -> NSColor {
            lit.contains(n) ? .systemBlue : hints.contains(n) ? .systemOrange : (white ? NSColor(white: 0.92, alpha: 1) : .black)
        }
        if state.instrument.isDrums {
            let pads = KeyLayout.drumPads, pw = bounds.width / CGFloat(pads.count)
            for (i, p) in pads.enumerated() {
                let r = NSRect(x: pw * CGFloat(i) + 1, y: 0, width: pw - 2, height: bounds.height)
                (lit.contains(p.note) ? NSColor.systemBlue : NSColor(white: 0.24, alpha: 1)).setFill()
                NSBezierPath(roundedRect: r, xRadius: 4, yRadius: 4).fill()
                label(p.name, in: r, white: true, y: (bounds.height - 10) / 2)
            }
            return
        }
        let kw = bounds.width / CGFloat(KeyLayout.whiteCount)
        for i in 0..<KeyLayout.whiteCount {
            let n = KeyLayout.white(i, base: state.base)
            let r = NSRect(x: kw * CGFloat(i) + 1, y: 0, width: kw - 2, height: bounds.height)
            color(n, white: true).setFill()
            NSBezierPath(roundedRect: r, xRadius: 3, yRadius: 3).fill()
            label(i % 7 == 0 ? "C\(n / 12 - 1)" : KeyLayout.names[i % 7], in: r, white: lit.contains(n) || hints.contains(n))
        }
        for i in 0..<KeyLayout.whiteCount where KeyLayout.hasBlack(after: i) {
            let n = KeyLayout.white(i, base: state.base) + 1
            let w = kw * KeyLayout.blackWidth, h = bounds.height * KeyLayout.blackHeight
            color(n, white: false).setFill()
            NSBezierPath(roundedRect: NSRect(x: kw * CGFloat(i + 1) - w / 2, y: bounds.height - h, width: w, height: h), xRadius: 2, yRadius: 2).fill()
        }
    }
}

// MARK: - Touch Bar factory
final class BarProvider: NSObject, NSTouchBarDelegate {
    static let pianoID = NSTouchBarItem.Identifier("piano")
    static let emptyID = NSTouchBarItem.Identifier("empty")

    func make() -> NSTouchBar {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [Self.pianoID]
        bar.principalItemIdentifier = Self.pianoID
        bar.escapeKeyReplacementItemIdentifier = Self.emptyID   // hide Esc
        return bar
    }
    func touchBar(_ bar: NSTouchBar, makeItemForIdentifier id: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        let item = NSCustomTouchBarItem(identifier: id)
        if id == Self.emptyID {
            let v = NSView()
            v.widthAnchor.constraint(equalToConstant: 0).isActive = true
            item.view = v
            return item
        }
        let piano = PianoView(frame: .zero)
        let w = piano.widthAnchor.constraint(equalToConstant: 1085)
        w.priority = .defaultHigh   // take all available width
        w.isActive = true
        item.view = piano
        return item
    }
}
let provider = BarProvider()

// MARK: - Private API (like Pock/MTMR): full-width, system-wide Touch Bar
enum SystemModal {
    static var bar: NSTouchBar?
    private static let cls: AnyClass = NSTouchBar.self

    private static func call(_ names: [String], _ body: (Method, Selector) -> Void) -> Bool {
        for n in names {
            let sel = NSSelectorFromString(n)
            if let m = class_getClassMethod(cls, sel) { body(m, sel); return true }
        }
        return false
    }
    /// Returns false if the private API is missing (then the window's normal Touch Bar is used).
    static func present() -> Bool {
        if let h = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_LAZY),
           let f = dlsym(h, "DFRSystemModalShowsCloseBoxWhenFrontMost") {
            typealias G = @convention(c) (Bool) -> Void
            unsafeBitCast(f, to: G.self)(false)   // hide the small close box
        }
        let b = provider.make()
        let ok = call(["presentSystemModalTouchBar:placement:systemTrayItemIdentifier:",
                       "presentSystemModalFunctionBar:placement:systemTrayItemIdentifier:"]) { m, sel in
            typealias F = @convention(c) (AnyClass, Selector, NSTouchBar, Int64, NSString?) -> Void
            unsafeBitCast(method_getImplementation(m), to: F.self)(cls, sel, b, 1, "local.touchbar-piano" as NSString) // 1 = hide Control Strip
        }
        if ok { bar = b }
        return ok
    }
    static func dismiss() {
        guard let b = bar else { return }
        _ = call(["dismissSystemModalTouchBar:", "dismissSystemModalFunctionBar:"]) { m, sel in
            typealias F = @convention(c) (AnyClass, Selector, NSTouchBar) -> Void
            unsafeBitCast(method_getImplementation(m), to: F.self)(cls, sel, b)
        }
    }
}
