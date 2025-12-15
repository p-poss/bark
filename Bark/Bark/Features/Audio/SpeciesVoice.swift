import Foundation

/// Configuration for a species-specific instrument voice
struct SpeciesVoice: Equatable {
    let species: Species
    let scale: MusicalScale
    let baseOctave: Int
    let instrumentType: InstrumentType
    let attackTime: Double
    let decayTime: Double
    let sustainLevel: Double
    let releaseTime: Double
    let filterCutoff: Double
    let filterResonance: Double
    let reverbMix: Double
    let character: String

    // MARK: - ADSR Envelope

    var envelope: ADSREnvelope {
        ADSREnvelope(
            attack: attackTime,
            decay: decayTime,
            sustain: sustainLevel,
            release: releaseTime
        )
    }
}

/// Types of instruments that can be used for synthesis
enum InstrumentType: Equatable {
    case sampler(bank: String)
    case synth(oscillator: OscillatorType, harmonics: [Double])

    var displayName: String {
        switch self {
        case .sampler(let bank):
            return "Sampler: \(bank)"
        case .synth(let oscillator, _):
            return "Synth: \(oscillator.rawValue)"
        }
    }
}

/// Oscillator waveform types
enum OscillatorType: String, CaseIterable {
    case sine = "Sine"
    case triangle = "Triangle"
    case square = "Square"
    case sawtooth = "Sawtooth"
    case pulse = "Pulse"
}

/// ADSR envelope parameters
struct ADSREnvelope: Equatable {
    let attack: Double   // Time to reach peak (seconds)
    let decay: Double    // Time to reach sustain level (seconds)
    let sustain: Double  // Sustain level (0.0-1.0)
    let release: Double  // Time to fade out after note off (seconds)

    static let `default` = ADSREnvelope(
        attack: 0.05,
        decay: 0.2,
        sustain: 0.7,
        release: 0.3
    )
}

// MARK: - Predefined Species Voices

extension SpeciesVoice {
    /// English Oak - Ancient, grounded, resonant
    static let oak = SpeciesVoice(
        species: .oak,
        scale: .dorian,
        baseOctave: 3,
        instrumentType: .synth(oscillator: .sawtooth, harmonics: [1.0, 0.5, 0.25, 0.125]),
        attackTime: 0.1,
        decayTime: 0.3,
        sustainLevel: 0.7,
        releaseTime: 0.5,
        filterCutoff: 2000,
        filterResonance: 0.3,
        reverbMix: 0.4,
        character: "Ancient, grounded, resonant"
    )

    /// Silver Birch - Light, airy, dancing
    static let birch = SpeciesVoice(
        species: .silverBirch,
        scale: .majorPentatonic,
        baseOctave: 5,
        instrumentType: .synth(oscillator: .triangle, harmonics: [1.0, 0.3]),
        attackTime: 0.02,
        decayTime: 0.2,
        sustainLevel: 0.5,
        releaseTime: 0.3,
        filterCutoff: 8000,
        filterResonance: 0.1,
        reverbMix: 0.3,
        character: "Light, airy, dancing"
    )

    /// English Yew - Ancient, dark, sacred
    static let yew = SpeciesVoice(
        species: .yew,
        scale: .locrian,
        baseOctave: 2,
        instrumentType: .synth(oscillator: .sine, harmonics: [1.0, 0.5, 0.25]),
        attackTime: 0.5,
        decayTime: 1.0,
        sustainLevel: 0.8,
        releaseTime: 2.0,
        filterCutoff: 800,
        filterResonance: 0.5,
        reverbMix: 0.7,
        character: "Ancient, dark, sacred"
    )

    /// European Beech - Smooth, elegant, classical
    static let beech = SpeciesVoice(
        species: .beech,
        scale: .major,
        baseOctave: 4,
        instrumentType: .synth(oscillator: .sine, harmonics: [1.0, 0.4, 0.2]),
        attackTime: 0.08,
        decayTime: 0.25,
        sustainLevel: 0.6,
        releaseTime: 0.4,
        filterCutoff: 4000,
        filterResonance: 0.2,
        reverbMix: 0.35,
        character: "Smooth, elegant, classical"
    )

    /// Common Ash - Strong, flexible, rhythmic
    static let ash = SpeciesVoice(
        species: .ash,
        scale: .mixolydian,
        baseOctave: 3,
        instrumentType: .synth(oscillator: .triangle, harmonics: [1.0, 0.6, 0.3]),
        attackTime: 0.04,
        decayTime: 0.15,
        sustainLevel: 0.65,
        releaseTime: 0.25,
        filterCutoff: 3500,
        filterResonance: 0.25,
        reverbMix: 0.3,
        character: "Strong, flexible, rhythmic"
    )

    /// Scots Pine - Noble, resinous, highland
    static let scotsPine = SpeciesVoice(
        species: .scotsPine,
        scale: .minor,
        baseOctave: 3,
        instrumentType: .synth(oscillator: .sawtooth, harmonics: [1.0, 0.7, 0.4, 0.2]),
        attackTime: 0.12,
        decayTime: 0.35,
        sustainLevel: 0.6,
        releaseTime: 0.6,
        filterCutoff: 2500,
        filterResonance: 0.35,
        reverbMix: 0.5,
        character: "Noble, resinous, highland"
    )

    /// Weeping Willow - Flowing, melancholic, graceful
    static let willow = SpeciesVoice(
        species: .willow,
        scale: .minorPentatonic,
        baseOctave: 4,
        instrumentType: .synth(oscillator: .sine, harmonics: [1.0, 0.3, 0.15]),
        attackTime: 0.15,
        decayTime: 0.4,
        sustainLevel: 0.55,
        releaseTime: 0.8,
        filterCutoff: 3000,
        filterResonance: 0.15,
        reverbMix: 0.55,
        character: "Flowing, melancholic, graceful"
    )

    /// Sweet Chestnut - Warm, rustic, spiraling
    static let sweetChestnut = SpeciesVoice(
        species: .sweetChestnut,
        scale: .lydian,
        baseOctave: 3,
        instrumentType: .synth(oscillator: .sawtooth, harmonics: [1.0, 0.5, 0.3, 0.15]),
        attackTime: 0.08,
        decayTime: 0.28,
        sustainLevel: 0.68,
        releaseTime: 0.45,
        filterCutoff: 2800,
        filterResonance: 0.28,
        reverbMix: 0.42,
        character: "Warm, rustic, spiraling"
    )

    /// Horse Chestnut - Bold, broad, majestic
    static let horseChestnut = SpeciesVoice(
        species: .horseChestnut,
        scale: .major,
        baseOctave: 3,
        instrumentType: .synth(oscillator: .square, harmonics: [1.0, 0.4, 0.2]),
        attackTime: 0.06,
        decayTime: 0.22,
        sustainLevel: 0.72,
        releaseTime: 0.35,
        filterCutoff: 3200,
        filterResonance: 0.22,
        reverbMix: 0.38,
        character: "Bold, broad, majestic"
    )

    /// Wild Cherry - Delicate, fleeting, spring
    static let wildCherry = SpeciesVoice(
        species: .wildCherry,
        scale: .majorPentatonic,
        baseOctave: 5,
        instrumentType: .synth(oscillator: .triangle, harmonics: [1.0, 0.25]),
        attackTime: 0.03,
        decayTime: 0.18,
        sustainLevel: 0.45,
        releaseTime: 0.28,
        filterCutoff: 6000,
        filterResonance: 0.12,
        reverbMix: 0.32,
        character: "Delicate, fleeting, spring"
    )

    /// Rowan - Mystical, protective, Celtic
    static let rowan = SpeciesVoice(
        species: .rowan,
        scale: .phrygian,
        baseOctave: 4,
        instrumentType: .synth(oscillator: .sine, harmonics: [1.0, 0.45, 0.2]),
        attackTime: 0.07,
        decayTime: 0.24,
        sustainLevel: 0.58,
        releaseTime: 0.4,
        filterCutoff: 3800,
        filterResonance: 0.3,
        reverbMix: 0.45,
        character: "Mystical, protective, Celtic"
    )

    /// Douglas Fir - Towering, Pacific, majestic
    static let douglasFir = SpeciesVoice(
        species: .douglasFir,
        scale: .dorian,
        baseOctave: 2,
        instrumentType: .synth(oscillator: .sawtooth, harmonics: [1.0, 0.6, 0.35, 0.2, 0.1]),
        attackTime: 0.15,
        decayTime: 0.4,
        sustainLevel: 0.75,
        releaseTime: 0.7,
        filterCutoff: 1800,
        filterResonance: 0.4,
        reverbMix: 0.6,
        character: "Towering, Pacific, majestic"
    )

    /// Norway Spruce - Christmas, evergreen, northern
    static let norwaySpruce = SpeciesVoice(
        species: .norwaySpruce,
        scale: .major,
        baseOctave: 4,
        instrumentType: .synth(oscillator: .triangle, harmonics: [1.0, 0.35, 0.15]),
        attackTime: 0.05,
        decayTime: 0.2,
        sustainLevel: 0.6,
        releaseTime: 0.35,
        filterCutoff: 4500,
        filterResonance: 0.18,
        reverbMix: 0.4,
        character: "Festive, evergreen, northern"
    )

    /// Default voice for unknown species
    static let unknown = SpeciesVoice(
        species: .unknownBroadleaf,
        scale: .majorPentatonic,
        baseOctave: 4,
        instrumentType: .synth(oscillator: .sine, harmonics: [1.0, 0.3]),
        attackTime: 0.05,
        decayTime: 0.2,
        sustainLevel: 0.6,
        releaseTime: 0.3,
        filterCutoff: 4000,
        filterResonance: 0.2,
        reverbMix: 0.35,
        character: "Neutral, exploratory"
    )

    /// Returns the appropriate voice for a given species
    static func voice(for species: Species) -> SpeciesVoice {
        switch species {
        case .oak: return .oak
        case .silverBirch: return .birch
        case .yew: return .yew
        case .beech: return .beech
        case .ash: return .ash
        case .scotsPine: return .scotsPine
        case .willow: return .willow
        case .sweetChestnut: return .sweetChestnut
        case .horseChestnut: return .horseChestnut
        case .wildCherry: return .wildCherry
        case .rowan: return .rowan
        case .douglasFir: return .douglasFir
        case .norwaySpruce: return .norwaySpruce
        default: return .unknown
        }
    }
}
