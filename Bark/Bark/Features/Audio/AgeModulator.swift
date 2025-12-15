import Foundation

/// Modulates audio parameters based on tree age
struct AgeModulator {
    /// Modulates a species voice based on tree age
    func modulateVoice(_ voice: SpeciesVoice, forAge age: AgeRange) -> ModulatedVoice {
        let ageNormalized = normalizeAge(age.midpoint, maxAge: voice.species.maxAge)

        return ModulatedVoice(
            baseVoice: voice,
            // Tempo: 120 BPM for saplings → 40 BPM for ancient
            tempo: lerp(120, 40, ageNormalized),
            // Octave shift: +1 for young, -1 for old
            octaveOffset: Int(lerp(1, -1, ageNormalized).rounded()),
            // Reverb: dry for young, cathedral for ancient
            reverbMix: lerp(0.1, 0.7, ageNormalized),
            // Filter: bright for young, darker for old
            filterCutoff: lerp(8000, 1500, ageNormalized),
            // Voice count: 1 for sapling, 5 for ancient
            voiceCount: Int(lerp(1, 5, ageNormalized).rounded()),
            // Note density: sparse for both young and ancient, dense for mature
            noteDensityMultiplier: bellCurve(ageNormalized, peak: 0.5)
        )
    }

    /// Normalizes age to a 0.0-1.0 range based on species max age
    private func normalizeAge(_ age: Int, maxAge: Int) -> Double {
        return min(Double(age) / Double(maxAge), 1.0)
    }

    /// Linear interpolation between two values
    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a + (b - a) * t
    }

    /// Bell curve function centered at peak
    private func bellCurve(_ t: Double, peak: Double) -> Double {
        // Returns 0.5 at edges, 1.0 at peak
        let distance = abs(t - peak)
        return 0.5 + 0.5 * (1.0 - distance * 2)
    }
}

/// Voice with age-based modulation applied
struct ModulatedVoice {
    let baseVoice: SpeciesVoice
    let tempo: Double
    let octaveOffset: Int
    let reverbMix: Double
    let filterCutoff: Double
    let voiceCount: Int
    let noteDensityMultiplier: Double

    /// The effective octave after applying age modulation
    var effectiveOctave: Int {
        baseVoice.baseOctave + octaveOffset
    }

    /// The effective filter cutoff after applying age modulation
    var effectiveFilterCutoff: Double {
        // Blend base voice cutoff with age-modulated cutoff
        (baseVoice.filterCutoff + filterCutoff) / 2
    }

    /// The effective reverb mix after applying age modulation
    var effectiveReverbMix: Double {
        // Blend base voice reverb with age-modulated reverb
        (baseVoice.reverbMix + reverbMix) / 2
    }

    /// Returns beats per second for timing calculations
    var beatsPerSecond: Double {
        tempo / 60.0
    }

    /// Returns the interval between beats in seconds
    var beatInterval: TimeInterval {
        60.0 / tempo
    }
}

// MARK: - Age-Based Sound Descriptions

extension AgeModulator {
    /// Returns a description of how age affects the sound
    static func soundDescription(for age: AgeRange, species: Species) -> String {
        let normalized = Double(age.midpoint) / Double(species.maxAge)

        switch normalized {
        case ..<0.1:
            return "Quick, bright notes with minimal reverb - the energy of new growth"
        case 0.1..<0.3:
            return "Lively tempo with clear, defined tones - established but still growing"
        case 0.3..<0.5:
            return "Full, rich sound with balanced complexity - in the prime of life"
        case 0.5..<0.7:
            return "Deeper tones with layered voices - wisdom accumulated over decades"
        case 0.7..<0.9:
            return "Slow, resonant notes with cathedral reverb - approaching ancient status"
        default:
            return "Profound, meditative soundscape - a rare survivor from centuries past"
        }
    }
}
