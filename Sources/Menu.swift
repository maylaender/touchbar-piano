import AppKit

let repoURL = URL(string: "https://github.com/maylaender/touchbar-piano")!

/// Menu bar, Dock menu and their actions. Plain-key shortcuts (Space, L, ←, …) are handled by the key monitor
/// in main.swift; the menu shows them and makes every action clickable.
final class MenuActions: NSObject, NSMenuItemValidation {
    weak var mainWindow: NSWindow?
    var showSettings: () -> Void = {}

    // MARK: Build
    func installMainMenu() {
        let main = NSMenu()
        main.addItem(submenu(appName, appMenu()))
        main.addItem(submenu(L("File", "Ablage"), fileMenu()))
        main.addItem(submenu(L("Edit", "Bearbeiten"), editMenu()))
        main.addItem(submenu(L("Playback", "Wiedergabe"), playbackMenu()))
        main.addItem(submenu(L("Piano", "Klavier"), pianoMenu()))
        main.addItem(submenu(L("Instrument", "Instrument"), instrumentMenu()))
        let window = windowMenu(), help = helpMenu()
        main.addItem(submenu(L("Window", "Fenster"), window))
        main.addItem(submenu(L("Help", "Hilfe"), help))
        NSApp.mainMenu = main
        NSApp.windowsMenu = window
        NSApp.helpMenu = help
    }
    var appName: String { "Touch Bar Piano" }

    private func submenu(_ title: String, _ menu: NSMenu) -> NSMenuItem {
        menu.title = title
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector?, _ key: String = "", _ mods: NSEvent.ModifierFlags = [.command],
                     tag: Int = 0, target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = key.isEmpty ? [] : mods
        item.tag = tag
        if let t = target { item.target = t } else if let a = action, responds(to: a) { item.target = self }
        menu.addItem(item)
        return item
    }
    private func arrow(_ k: Int) -> String { String(utf16CodeUnits: [UInt16(k)], count: 1) }

    private func appMenu() -> NSMenu {
        let m = NSMenu()
        add(m, L("About Touch Bar Piano", "Über Touch Bar Piano"), #selector(about))
        m.addItem(.separator())
        add(m, L("Settings …", "Einstellungen …"), #selector(settings), ",")
        m.addItem(.separator())
        let services = NSMenu()
        add(m, L("Services", "Dienste"), nil).submenu = services
        NSApp.servicesMenu = services
        m.addItem(.separator())
        add(m, L("Hide Touch Bar Piano", "Touch Bar Piano ausblenden"), #selector(NSApplication.hide(_:)), "h", target: NSApp)
        add(m, L("Hide Others", "Andere ausblenden"), #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option], target: NSApp)
        add(m, L("Show All", "Alle einblenden"), #selector(NSApplication.unhideAllApplications(_:)), target: NSApp)
        m.addItem(.separator())
        add(m, L("Quit Touch Bar Piano", "Touch Bar Piano beenden"), #selector(NSApplication.terminate(_:)), "q", target: NSApp)
        return m
    }
    private func fileMenu() -> NSMenu {
        let m = NSMenu()
        add(m, L("Import Song …", "Lied importieren …"), #selector(importSong), "o")
        add(m, L("Export MIDI …", "MIDI exportieren …"), #selector(exportMIDI), "e", [.command, .shift])
        add(m, L("Tracks …", "Spuren …"), #selector(tracks), "t")
        m.addItem(.separator())
        add(m, L("Close Window", "Fenster schliessen"), #selector(NSWindow.performClose(_:)), "w")
        return m
    }
    private func editMenu() -> NSMenu {
        let m = NSMenu()
        add(m, L("Undo", "Widerrufen"), Selector(("undo:")), "z")
        add(m, L("Redo", "Wiederholen"), Selector(("redo:")), "z", [.command, .shift])
        m.addItem(.separator())
        add(m, L("Cut", "Ausschneiden"), #selector(NSText.cut(_:)), "x")
        add(m, L("Copy", "Kopieren"), #selector(NSText.copy(_:)), "c")
        add(m, L("Paste", "Einsetzen"), #selector(NSText.paste(_:)), "v")
        add(m, L("Select All", "Alles auswählen"), #selector(NSText.selectAll(_:)), "a")
        return m
    }
    private func playbackMenu() -> NSMenu {
        let m = NSMenu()
        add(m, L("Play / Pause", "Abspielen / Pause"), #selector(playPause), " ", [])
        add(m, L("Stop", "Stopp"), #selector(stop), ".")
        add(m, L("Back 5 s", "5 s zurück"), #selector(back), ",", [])
        add(m, L("Forward 5 s", "5 s vor"), #selector(forward), ".", [])
        add(m, L("A–B Loop", "A–B-Schleife"), #selector(loop), "l", [])
        m.addItem(.separator())
        add(m, L("Record", "Aufnahme"), #selector(record), "r", [])
        m.addItem(.separator())
        add(m, L("Sheet Mode", "Noten-Modus"), #selector(sheetMode), "s", [])
        add(m, L("Learn Mode (wait for me)", "Lernmodus (auf mich warten)"), #selector(learnMode))
        add(m, L("Learn the Left Hand", "Linke Hand üben"), #selector(leftHand))
        add(m, L("Both Hands", "Beide Hände"), #selector(bothHands))
        add(m, L("Follow Octave", "Oktave mitwandern"), #selector(followOctave))
        add(m, L("Count-in", "Einzähler"), #selector(countIn))
        return m
    }
    private func pianoMenu() -> NSMenu {
        let m = NSMenu()
        add(m, L("Octave Up", "Oktave höher"), #selector(octaveUp), arrow(NSRightArrowFunctionKey), [])
        add(m, L("Octave Down", "Oktave tiefer"), #selector(octaveDown), arrow(NSLeftArrowFunctionKey), [])
        m.addItem(.separator())
        add(m, L("Sustain Pedal (or hold ⇧)", "Pedal (oder ⇧ halten)"), #selector(pedal))
        m.addItem(.separator())
        add(m, L("Metronome", "Metronom"), #selector(metronome), "m", [])
        add(m, L("Tempo Up", "Tempo höher"), #selector(tempoUp), arrow(NSUpArrowFunctionKey), [])
        add(m, L("Tempo Down", "Tempo tiefer"), #selector(tempoDown), arrow(NSDownArrowFunctionKey), [])
        return m
    }
    private func instrumentMenu() -> NSMenu {
        let m = NSMenu()
        for group in InstrumentGroup.allCases {
            let list = instruments.filter { $0.group == group }
            if group == .classic {
                for inst in list { add(m, inst.emoji + "  " + inst.name, #selector(selectInstrument(_:)), "\(inst.id + 1)", [], tag: inst.id) }
                m.addItem(.separator())
            } else {
                let sub = NSMenu()
                for inst in list { add(sub, inst.emoji + "  " + inst.name, #selector(selectInstrument(_:)), tag: inst.id) }
                add(m, group.title, nil).submenu = sub
            }
        }
        return m
    }
    private func windowMenu() -> NSMenu {
        let m = NSMenu()
        add(m, L("Minimize", "Im Dock ablegen"), #selector(NSWindow.performMiniaturize(_:)), "m")
        add(m, L("Zoom", "Zoomen"), #selector(NSWindow.performZoom(_:)))
        add(m, L("Enter Full Screen", "Vollbildmodus"), #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control])
        m.addItem(.separator())
        add(m, L("Bring All to Front", "Alle nach vorne bringen"), #selector(NSApplication.arrangeInFront(_:)), target: NSApp)
        return m
    }
    private func helpMenu() -> NSMenu {
        let m = NSMenu()
        add(m, L("Touch Bar Piano Help", "Touch Bar Piano – Anleitung"), #selector(help))
        add(m, L("Keyboard Shortcuts", "Tastenkürzel"), #selector(shortcuts))
        add(m, L("Song Sources & Licences", "Liederquellen & Lizenzen"), #selector(sources))
        m.addItem(.separator())
        add(m, L("Report a Problem …", "Problem melden …"), #selector(report))
        return m
    }

    /// Right-click on the Dock icon.
    func dockMenu() -> NSMenu {
        let m = NSMenu()
        add(m, state.playing != nil && !state.paused ? L("Pause", "Pause") : L("Play", "Abspielen"), #selector(playPause))
        add(m, L("Stop", "Stopp"), #selector(stop))
        add(m, state.isRecording ? L("Stop Recording", "Aufnahme beenden") : L("Record", "Aufnahme"), #selector(record))
        m.addItem(.separator())
        add(m, L("Sheet Mode", "Noten-Modus"), #selector(sheetMode))
        add(m, L("Metronome", "Metronom"), #selector(metronome))
        return m
    }

    // MARK: Validation (checkmarks, enabled state)
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        // plain-key shortcuts only act on the main window (not while Tracks/Settings are in front)
        if item.keyEquivalentModifierMask.isEmpty && !item.keyEquivalent.isEmpty && NSApp.keyWindow !== mainWindow
            && NSApp.currentEvent?.type == .keyDown { return false }
        func check(_ on: Bool) { item.state = on ? .on : .off }
        switch item.action {
        case #selector(playPause)?: item.title = state.playing != nil && !state.paused ? L("Pause", "Pause") : L("Play", "Abspielen")
        case #selector(stop)?: return state.playing != nil
        case #selector(loop)?: check(state.loopA != nil)
        case #selector(record)?: check(state.isRecording)
        case #selector(sheetMode)?: check(state.sheetMode)
        case #selector(learnMode)?: check(state.waitForMe)
        case #selector(leftHand)?: check(state.learnLeft)
        case #selector(bothHands)?: check(state.bothHands)
        case #selector(followOctave)?: check(state.followOctave)
        case #selector(countIn)?: check(state.countIn)
        case #selector(pedal)?: check(state.pedal)
        case #selector(metronome)?: check(state.metronome)
        case #selector(selectInstrument(_:))?: check(state.instrumentID == item.tag)
        case #selector(exportMIDI)?: return state.selectedSong != nil
        case #selector(tracks)?: return (state.selectedSong?.parts?.count ?? 0) > 1
        default: break
        }
        return true
    }

    // MARK: Actions
    @objc func about() { showAbout() }
    @objc func settings() { showSettings() }
    @objc func importSong() { state.importSongs() }
    @objc func exportMIDI() { state.exportMIDI() }
    @objc func tracks() { state.editingTracks = true }
    @objc func playPause() { state.togglePlay() }
    @objc func stop() { state.stopPlayback() }
    @objc func back() { state.skip(-5) }
    @objc func forward() { state.skip(5) }
    @objc func loop() { state.toggleLoop() }
    @objc func record() { state.toggleRecording() }
    @objc func sheetMode() { state.sheetMode.toggle() }
    @objc func learnMode() { state.waitForMe.toggle() }
    @objc func leftHand() { state.learnLeft.toggle() }
    @objc func bothHands() { state.bothHands.toggle() }
    @objc func followOctave() { state.followOctave.toggle() }
    @objc func countIn() { state.countIn.toggle() }
    @objc func octaveUp() { state.octave = min(7, state.octave + 1) }
    @objc func octaveDown() { state.octave = max(1, state.octave - 1) }
    @objc func pedal() { state.pedal.toggle() }
    @objc func metronome() { state.metronome.toggle() }
    @objc func tempoUp() { state.bpm = min(240, state.bpm + 5) }
    @objc func tempoDown() { state.bpm = max(40, state.bpm - 5) }
    @objc func selectInstrument(_ sender: NSMenuItem) { state.instrumentID = sender.tag }
    @objc func help() { NSWorkspace.shared.open(repoURL.appendingPathComponent("blob/main/README.md")) }
    @objc func shortcuts() { NSWorkspace.shared.open(URL(string: repoURL.absoluteString + "#%EF%B8%8F-keyboard-shortcuts")!) }
    @objc func sources() { NSWorkspace.shared.open(repoURL.appendingPathComponent("blob/main/Songs/SOURCES.md")) }
    @objc func report() { NSWorkspace.shared.open(repoURL.appendingPathComponent("issues/new")) }

    /// Standard About panel with credits.
    func showAbout() {
        let text = L("""
            Turns the MacBook Pro Touch Bar into a piano.
            Open source – MIT licence © touchbar-piano contributors.

            Built-in songs from the Mutopia Project and IMSLP (public domain; Sonata facile CC BY-SA 3.0).
            Sounds: the General MIDI sound bank built into macOS.
            """, """
            Verwandelt die Touch Bar des MacBook Pro in ein Klavier.
            Open Source – MIT-Lizenz © touchbar-piano contributors.

            Eingebaute Lieder vom Mutopia Project und von IMSLP (gemeinfrei; Sonata facile CC BY-SA 3.0).
            Klänge: die in macOS eingebaute General-MIDI-Soundbank.
            """)
        let credits = NSMutableAttributedString(string: text + "\n\n", attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor])
        credits.append(NSAttributedString(string: "github.com/maylaender/touchbar-piano", attributes: [.font: NSFont.systemFont(ofSize: 11), .link: repoURL]))
        let center = NSMutableParagraphStyle(); center.alignment = .center
        credits.addAttribute(.paragraphStyle, value: center, range: NSRange(location: 0, length: credits.length))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate(ignoringOtherApps: true)
    }

    /// For the CI log: all menus with their shortcuts.
    func describe() -> String {
        func keyText(_ i: NSMenuItem) -> String {
            guard !i.keyEquivalent.isEmpty else { return "" }
            var s = ""
            if i.keyEquivalentModifierMask.contains(.control) { s += "⌃" }
            if i.keyEquivalentModifierMask.contains(.option) { s += "⌥" }
            if i.keyEquivalentModifierMask.contains(.shift) { s += "⇧" }
            if i.keyEquivalentModifierMask.contains(.command) { s += "⌘" }
            let k = i.keyEquivalent
            let named = [" ": "Space", arrow(NSLeftArrowFunctionKey): "←", arrow(NSRightArrowFunctionKey): "→",
                         arrow(NSUpArrowFunctionKey): "↑", arrow(NSDownArrowFunctionKey): "↓"]
            return "  [" + s + (named[k] ?? k.uppercased()) + "]"
        }
        return (NSApp.mainMenu?.items ?? []).map { top in
            "▸ \(top.title): " + (top.submenu?.items ?? []).filter { !$0.isSeparatorItem }.map { $0.title + keyText($0) }.joined(separator: " · ")
        }.joined(separator: "\n")
    }
}
let menuActions = MenuActions()
