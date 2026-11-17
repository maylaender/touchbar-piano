import AppKit
import SwiftUI

let state = AppState()

/// Fallback Touch Bar (if the private system-wide API is unavailable).
final class PianoWindow: NSWindow {
    override func makeTouchBar() -> NSTouchBar? { SystemModal.bar == nil ? provider.make() : nil }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: PianoWindow!
    var monitor: Any?

    func applicationDidFinishLaunching(_ n: Notification) {
        window = PianoWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 820),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
        window.title = "Touch Bar Piano"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentView = NSHostingView(rootView: ContentView(s: state))
        window.center()
        window.makeKeyAndOrderFront(nil)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] e in
            self?.handle(e) == true ? nil : e
        }
        if !state.snapshotMode { _ = SystemModal.present() }
        NSApp.activate(ignoringOtherApps: true)
        if let dir = ProcessInfo.processInfo.environment["PIANO_SNAPSHOT"] { Snapshot.run(window: window, dir: dir) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ n: Notification) { state.stopRecording(); SystemModal.dismiss() }

    /// Keyboard shortcuts (same as v2, plus R, Space, S).
    func handle(_ e: NSEvent) -> Bool {
        if e.type == .flagsChanged {
            let down = e.modifierFlags.contains(.shift)
            if down != state.pedal { state.pedal = down }
            return false
        }
        if e.modifierFlags.contains(.command) { return false }
        let first = !e.isARepeat
        switch e.keyCode {
        case 123: state.octave = max(1, state.octave - 1)        // ←
        case 124: state.octave = min(7, state.octave + 1)        // →
        case 125: state.bpm = max(40, state.bpm - 5)             // ↓
        case 126: state.bpm = min(240, state.bpm + 5)            // ↑
        case 49:  if first { state.togglePlay() }                // Space
        default:
            let c = e.charactersIgnoringModifiers?.lowercased() ?? ""
            if let d = Int(c), (1...8).contains(d) { state.instrumentID = d - 1 }
            else if c == "m" { if first { state.metronome.toggle() } }
            else if c == "r" { if first { state.toggleRecording() } }
            else if c == "s" { if first { state.sheetMode.toggle() } }
            else { return false }
        }
        return true
    }
}

/// CI only: renders the real views to PNG for the README, then quits.
enum Snapshot {
    static func save(_ v: NSView, _ path: String) {
        let s = v.bounds.size
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(s.width * 2), pixelsHigh: Int(s.height * 2),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = s
        v.cacheDisplay(in: v.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
    /// SwiftUI is not captured by cacheDisplay -> real window screenshot.
    static func capture(_ window: NSWindow, _ path: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x", "-o", "-l\(window.windowNumber)", path]
        try? p.run()
        p.waitUntilExit()
    }
    static func run(window: NSWindow, dir: String) {
        print("screen:", NSScreen.main?.frame.size ?? .zero, "scale:", NSScreen.main?.backingScaleFactor ?? 0)
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let piano = PianoView(frame: NSRect(x: 0, y: 0, width: 1085, height: 30))
        func song(_ t: String) -> Song { state.library.first { $0.title.contains(t) } ?? state.library[0] }
        let drums = instruments.first { $0.isDrums }!.id

        var steps: [(String, () -> Void)] = [
            ("main", { state.pedal = true; state.pressed = [60, 64, 67] }),
            ("sheet", {
                state.pedal = false; state.pressed = []
                state.select(song("Elise")); state.waitForMe = true; state.practice()
                for _ in 0..<5 { for n in state.hints { state.noteOn(n); state.noteOff(n) } }
            }),
            ("drums", { state.stopPlayback(); state.sheetMode = false; state.instrumentID = drums; state.pressed = [36, 42] }),
            ("record", { state.instrumentID = 0; state.pressed = [62, 65, 69]; state.metronome = true; state.startRecording() }),
        ]
        // animation frames: Ode to Joy in sheet mode
        steps.append(("prep", { state.stopRecording(); state.metronome = false; state.pressed = []; state.select(song("Ode")); state.sheetMode = true }))
        for i in 0..<36 { steps.append((String(format: "f%02d", i), { state.preview(song("Ode"), at: Double(i) * 0.33) })) }

        func next() {
            guard !steps.isEmpty else { NSApp.terminate(nil); return }
            let (name, action) = steps.removeFirst()
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + (name.hasPrefix("f") ? 0.2 : 0.9)) {
                piano.needsDisplay = true
                if name != "prep" {
                    save(piano, "\(dir)/touchbar_\(name).png")
                    capture(window, "\(dir)/window_\(name).png")
                }
                next()
            }
        }
        next()
    }
}

if ProcessInfo.processInfo.environment["PIANO_SELFTEST"] != nil { exit(selfTest() ? 0 : 1) }

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.isAutomaticCustomizeTouchBarMenuItemEnabled = false
app.run()
