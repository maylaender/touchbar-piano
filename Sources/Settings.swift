import SwiftUI
import AppKit

/// Settings window (⌘,). All values are stored in UserDefaults by AppState.
struct SettingsView: View {
    @ObservedObject var s: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            section(L("Touch Bar", "Touch Bar"), "rectangle.split.3x1") {
                Picker("", selection: $s.fullWidthBar) {
                    Text(L("Full width – Esc hidden, works in every app", "Volle Breite – ohne Esc, in jeder App")).tag(true)
                    Text(L("Standard – with Esc, only while the window is active", "Standard – mit Esc, nur bei aktivem Fenster")).tag(false)
                }
                .pickerStyle(RadioGroupPickerStyle()).labelsHidden()
                note(L("Full width uses an undocumented macOS feature. Switch to Standard if the Touch Bar misbehaves.",
                       "Volle Breite nutzt eine undokumentierte macOS-Funktion. Bei Problemen mit der Touch Bar auf Standard wechseln."))
            }
            section(L("Appearance", "Erscheinungsbild"), "circle.lefthalf.fill") {
                Picker("", selection: $s.appearance) {
                    Text(L("System", "System")).tag(0)
                    Text(L("Light", "Hell")).tag(1)
                    Text(L("Dark", "Dunkel")).tag(2)
                }
                .pickerStyle(SegmentedPickerStyle()).labelsHidden().frame(width: 260)
            }
            section(L("Start", "Start"), "power") {
                Picker(L("Instrument at launch", "Instrument beim Start"), selection: $s.startInstrument) {
                    Text(L("Last used", "Zuletzt verwendet")).tag(-1)
                    ForEach(instruments) { Text($0.emoji + "  " + $0.name).tag($0.id) }
                }
                .frame(width: 360)
            }
            section(L("Practice", "Üben"), "graduationcap") {
                Toggle(L("Count-in (1 bar)", "Einzähler (1 Takt)"), isOn: $s.countIn)
                Toggle(L("Follow octave", "Oktave mitwandern"), isOn: $s.followOctave)
                Toggle(L("Both hands", "Beide Hände"), isOn: $s.bothHands)
                HStack {
                    Text(L("Accompaniment volume", "Lautstärke Begleitung"))
                    Slider(value: $s.accVolume, in: 0.1...1).frame(width: 180)
                    Text("\(Int((s.accVolume * 100).rounded())) %").frame(width: 40, alignment: .trailing)
                }
            }
        }
        .font(.system(size: 12.5))
        .padding(24)
        .frame(width: 520, alignment: .leading)
    }
    private func section<C: View>(_ title: String, _ symbol: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.system(size: 13, weight: .semibold, design: .rounded))
            VStack(alignment: .leading, spacing: 6) { content() }.padding(.leading, 22)
        }
    }
    private func note(_ t: String) -> some View {
        Text(t).font(.system(size: 11)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

final class SettingsWindow {
    static var window: NSWindow?
    static func show() {
        if window == nil {
            let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = L("Settings", "Einstellungen")
            w.contentView = NSHostingView(rootView: SettingsView(s: state))
            w.setContentSize(w.contentView!.fittingSize)
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
