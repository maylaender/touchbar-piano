import AVFoundation

let soundBank = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
let melodicBank: UInt8 = 0x79, percussionBank: UInt8 = 0x78

/// Three samplers from the built-in General MIDI sound bank: melodic, drums, metronome.
final class Synth {
    private let engine = AVAudioEngine()
    private let keys = AVAudioUnitSampler()
    private let drums = AVAudioUnitSampler()
    private let click = AVAudioUnitSampler()

    init() {
        for s in [keys, drums, click] {
            engine.attach(s)
            engine.connect(s, to: engine.mainMixerNode, format: nil)
        }
        load(keys, program: 0, bank: melodicBank)
        load(drums, program: 0, bank: percussionBank)
        load(click, program: 0, bank: percussionBank)
        try? engine.start()
    }
    private func load(_ s: AVAudioUnitSampler, program: UInt8, bank: UInt8) {
        try? s.loadSoundBankInstrument(at: soundBank, program: program, bankMSB: bank, bankLSB: 0)
    }
    func setInstrument(_ i: Instrument) {
        if i.isDrums { load(drums, program: i.program, bank: percussionBank) }
        else { load(keys, program: i.program, bank: melodicBank) }
    }
    func on(_ n: UInt8, drum: Bool) { (drum ? drums : keys).startNote(n, withVelocity: 100, onChannel: 0) }
    func off(_ n: UInt8, drum: Bool) { (drum ? drums : keys).stopNote(n, onChannel: 0) }
    func pedal(_ down: Bool) { keys.sendController(64, withValue: down ? 127 : 0, onChannel: 0) } // CC64 = sustain
    func tick(_ accent: Bool) { click.startNote(accent ? 76 : 77, withVelocity: accent ? 127 : 90, onChannel: 0) } // wood blocks
}
