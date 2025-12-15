import AVFoundation
import Combine

/// Main audio engine for synthesizing and playing tree music
@MainActor
final class AudioEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var isRecording = false
    @Published var currentVoice: SpeciesVoice?
    @Published var error: AudioEngineError?

    private var audioEngine: AVAudioEngine?
    private var mixerNode: AVAudioMixerNode?
    private var reverbNode: AVAudioUnitReverb?
    private var oscillatorNodes: [OscillatorNode] = []
    private var recordingFile: AVAudioFile?
    private var recordingURL: URL?

    private let maxPolyphony = 12
    private var activeVoices: [UUID: OscillatorNode] = [:]

    private var modulatedVoice: ModulatedVoice?

    init() {
        setupAudioSession()
    }

    // MARK: - Public Methods

    func start() throws {
        guard audioEngine == nil else { return }

        try setupAudioEngine()
        try audioEngine?.start()
        isPlaying = true
    }

    func stop() {
        audioEngine?.stop()
        audioEngine = nil
        mixerNode = nil
        reverbNode = nil
        oscillatorNodes.removeAll()
        activeVoices.removeAll()
        isPlaying = false
    }

    func setVoice(_ voice: SpeciesVoice) {
        currentVoice = voice
    }

    func setAgeModulation(_ modulation: ModulatedVoice) {
        modulatedVoice = modulation
        updateReverbMix(modulation.effectiveReverbMix)
    }

    func playNotes(_ notes: [NoteEvent]) {
        guard isPlaying, let voice = modulatedVoice ?? currentVoice.map({
            ModulatedVoice(
                baseVoice: $0,
                tempo: 80,
                octaveOffset: 0,
                reverbMix: $0.reverbMix,
                filterCutoff: $0.filterCutoff,
                voiceCount: 1,
                noteDensityMultiplier: 1.0
            )
        }) else { return }

        for note in notes {
            playNote(note, voice: voice)
        }
    }

    func startRecording() -> URL? {
        guard isPlaying, let engine = audioEngine else { return nil }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "bark_recording_\(Date().timeIntervalSince1970).m4a"
        let fileURL = documentsPath.appendingPathComponent(fileName)

        do {
            let format = engine.mainMixerNode.outputFormat(forBus: 0)
            recordingFile = try AVAudioFile(
                forWriting: fileURL,
                settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: format.sampleRate,
                    AVNumberOfChannelsKey: format.channelCount
                ]
            )

            engine.mainMixerNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
                try? self?.recordingFile?.write(from: buffer)
            }

            recordingURL = fileURL
            isRecording = true
            return fileURL
        } catch {
            self.error = .recordingFailed
            return nil
        }
    }

    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        audioEngine?.mainMixerNode.removeTap(onBus: 0)
        recordingFile = nil
        isRecording = false

        return recordingURL
    }

    // MARK: - Private Methods

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            self.error = .sessionConfigurationFailed
        }
    }

    private func setupAudioEngine() throws {
        let engine = AVAudioEngine()
        let mixer = AVAudioMixerNode()
        let reverb = AVAudioUnitReverb()

        engine.attach(mixer)
        engine.attach(reverb)

        reverb.loadFactoryPreset(.cathedral)
        reverb.wetDryMix = 35

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!

        engine.connect(mixer, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)

        // Pre-create oscillator nodes for polyphony
        for _ in 0..<maxPolyphony {
            let oscillator = OscillatorNode()
            engine.attach(oscillator.node)
            engine.connect(oscillator.node, to: mixer, format: format)
            oscillatorNodes.append(oscillator)
        }

        audioEngine = engine
        mixerNode = mixer
        reverbNode = reverb
    }

    private func playNote(_ note: NoteEvent, voice: ModulatedVoice) {
        // Find an available oscillator
        guard let oscillator = findAvailableOscillator() else { return }

        // Configure and play
        oscillator.configure(
            frequency: midiToFrequency(note.pitch),
            amplitude: Double(note.velocity) / 127.0 * 0.3,
            waveform: waveformFromVoice(voice.baseVoice),
            envelope: voice.baseVoice.envelope
        )

        oscillator.noteOn()
        activeVoices[note.id] = oscillator

        // Schedule note off
        DispatchQueue.main.asyncAfter(deadline: .now() + note.duration) { [weak self] in
            oscillator.noteOff()
            self?.activeVoices.removeValue(forKey: note.id)
        }
    }

    private func findAvailableOscillator() -> OscillatorNode? {
        // First try to find an idle oscillator
        for oscillator in oscillatorNodes {
            if !oscillator.isPlaying {
                return oscillator
            }
        }

        // If all are busy, steal the oldest one
        return oscillatorNodes.first
    }

    private func midiToFrequency(_ midiNote: Int) -> Double {
        return 440.0 * pow(2.0, Double(midiNote - 69) / 12.0)
    }

    private func waveformFromVoice(_ voice: SpeciesVoice) -> Waveform {
        switch voice.instrumentType {
        case .synth(let oscillator, _):
            switch oscillator {
            case .sine: return .sine
            case .triangle: return .triangle
            case .square: return .square
            case .sawtooth: return .sawtooth
            case .pulse: return .square
            }
        case .sampler:
            return .sine
        }
    }

    private func updateReverbMix(_ mix: Double) {
        reverbNode?.wetDryMix = Float(mix * 100)
    }
}

// MARK: - Oscillator Node

/// Simple oscillator wrapper for AVAudioSourceNode
final class OscillatorNode {
    var node: AVAudioSourceNode!
    var isPlaying = false

    private var frequency: Double = 440
    private var amplitude: Double = 0.3
    private var waveform: Waveform = .sine
    private var phase: Double = 0
    private var envelope: ADSREnvelope = .default

    private var envelopePhase: EnvelopePhase = .idle
    private var envelopeValue: Double = 0
    private var envelopeTime: Double = 0

    init() {
        node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let sampleRate = 44100.0

            for frame in 0..<Int(frameCount) {
                let sample = self.generateSample(sampleRate: sampleRate)

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = Float(sample)
                }
            }

            return noErr
        }
    }

    func configure(frequency: Double, amplitude: Double, waveform: Waveform, envelope: ADSREnvelope) {
        self.frequency = frequency
        self.amplitude = amplitude
        self.waveform = waveform
        self.envelope = envelope
    }

    func noteOn() {
        envelopePhase = .attack
        envelopeTime = 0
        isPlaying = true
    }

    func noteOff() {
        envelopePhase = .release
        envelopeTime = 0
    }

    private func generateSample(sampleRate: Double) -> Double {
        // Update envelope
        updateEnvelope(sampleRate: sampleRate)

        guard envelopeValue > 0.001 else {
            if envelopePhase == .release {
                isPlaying = false
                envelopePhase = .idle
            }
            return 0
        }

        // Generate waveform
        let sample: Double
        switch waveform {
        case .sine:
            sample = sin(phase * 2 * .pi)
        case .triangle:
            sample = 2 * abs(2 * (phase - floor(phase + 0.5))) - 1
        case .square:
            sample = phase < 0.5 ? 1 : -1
        case .sawtooth:
            sample = 2 * (phase - floor(phase + 0.5))
        }

        // Advance phase
        phase += frequency / sampleRate
        if phase >= 1.0 { phase -= 1.0 }

        return sample * amplitude * envelopeValue
    }

    private func updateEnvelope(sampleRate: Double) {
        let deltaTime = 1.0 / sampleRate
        envelopeTime += deltaTime

        switch envelopePhase {
        case .idle:
            envelopeValue = 0
        case .attack:
            if envelope.attack > 0 {
                envelopeValue = min(1.0, envelopeTime / envelope.attack)
            } else {
                envelopeValue = 1.0
            }
            if envelopeTime >= envelope.attack {
                envelopePhase = .decay
                envelopeTime = 0
            }
        case .decay:
            let decayProgress = min(1.0, envelopeTime / envelope.decay)
            envelopeValue = 1.0 - (1.0 - envelope.sustain) * decayProgress
            if envelopeTime >= envelope.decay {
                envelopePhase = .sustain
            }
        case .sustain:
            envelopeValue = envelope.sustain
        case .release:
            if envelope.release > 0 {
                let releaseProgress = min(1.0, envelopeTime / envelope.release)
                envelopeValue = envelope.sustain * (1.0 - releaseProgress)
            } else {
                envelopeValue = 0
            }
            if envelopeTime >= envelope.release {
                envelopePhase = .idle
                isPlaying = false
            }
        }
    }
}

enum Waveform {
    case sine, triangle, square, sawtooth
}

enum EnvelopePhase {
    case idle, attack, decay, sustain, release
}

// MARK: - Audio Engine Error

enum AudioEngineError: LocalizedError {
    case sessionConfigurationFailed
    case engineStartFailed
    case recordingFailed

    var errorDescription: String? {
        switch self {
        case .sessionConfigurationFailed:
            return "Failed to configure audio session."
        case .engineStartFailed:
            return "Failed to start audio engine."
        case .recordingFailed:
            return "Failed to start recording."
        }
    }
}

// MARK: - Protocol

protocol AudioEngineProtocol {
    var isPlaying: Bool { get }
    var isRecording: Bool { get }

    func start() throws
    func stop()
    func setVoice(_ voice: SpeciesVoice)
    func setAgeModulation(_ modulation: ModulatedVoice)
    func playNotes(_ notes: [NoteEvent])
    func startRecording() -> URL?
    func stopRecording() -> URL?
}

extension AudioEngine: AudioEngineProtocol {}
